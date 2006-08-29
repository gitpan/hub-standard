# NOTE: Changes made here will be lost when bulksplit is run again.
package Hub::Data::HashFile;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# HashFile
#
# Called by the framework to invoke Autoloader::AUTOLOAD, in essence loading
# this file.
# ------------------------------------------------------------------------------
sub HashFile {
}#HashFile

#line 15

our $NAMESPACE = Hub::regns( 'hashfile' );

#-------------------------------------------------------------------------------

my $FORMAT_ID       = "HashFile 2.0";                   # what we read/write
my $WS              = "\\s*";                           # whitespace
my $VAR_PATTERN     = "[\\S]";                          # valid variable chars
my $VAR_NAME        = "($VAR_PATTERN+)";                # valid variable name
my $DATA_NAME       = "${WS}(${VAR_PATTERN}*)${WS}";    # identifies structures
my $INDENT          = "    ";                           # used when writing
my $FORMAT_MASK     = "\\\#\$\%\=\@\{\}\>";             # protect these chars

my $FORMAT_IN = {
    INCLUDE         => qr/^${WS}!INCLUDE${DATA_NAME}/,
    INLINE_ASSIGN   => qr/^${WS}${VAR_NAME}${WS}=[=\>]${WS}(.*)/o,
    SCALAR_OPEN     => qr/^${WS}\$${DATA_NAME}\{/o,
    ARRAY_OPEN      => qr/^${WS}\@${DATA_NAME}\{/o,
    HASH_OPEN       => qr/^${WS}\%${DATA_NAME}\{/o,
    CLOSE           => qr/^${WS}}$/o,
    COMMENT         => qr/^${WS}#/o,
    COMMENT_OPEN    => qr/^${WS}#\{/o,
    COMMENT_CLOSE   => qr/^${WS}#\}/o,
    BLANKLINE       => qr/^${WS}$/o,
};

my $FORMAT_OUT = {
    INLINE_ASSIGN   => "%s => %s\n",
    SCALAR_OPEN     => "\$%s{\n",
    ARRAY_OPEN      => "\@%s{\n",
    HASH_OPEN       => "%%%s{\n",
    CLOSE           => "}\n",
    COMMENT         => "%s\n",
    BLANKLINE       => "\n",
    UNKNOWN_OPEN    => "%%%s{\n",
};

my $DEBUG_READ      = 0;                                # print status to stdout
my $DEBUG_WRITE     = 0;                                # print status to stdout

#-------------------------------------------------------------------------------
# Default options.  New instances will use these values, allowing you to set 
# these as the defaults for all your newly created hashfile.
#
our $write_behind        = 0;
our $preserve_comments   = 0;
our $preserve_order      = 0;
our $backup              = 0;

#-------------------------------------------------------------------------------
# Static methods
#
sub hffmt { return &format( @_ ); }

# ------------------------------------------------------------------------------
# refresh
# 
# Sync disk data into ourselves
# Hub object method
# ------------------------------------------------------------------------------

sub refresh {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    $self->load();

}#refresh

#-------------------------------------------------------------------------------
sub _init {

    my $self = shift || return;

    $self->{'_filename'}    = '';               # path to file
    $self->{'_file_id'}     = '';               # unique to each file
    $self->{'_last_sync'}   = 0;                # last time self==file-on-disk
    $self->{'_data'}        = {};               # contents
    $self->{'_comments'}    = {};               # file comments
    $self->{'_order'}       = {};               # variable order in file
    $self->{'_dirty'}       = 0;                # files needs to be saved
    $self->{'_included'}    = [];               # included files
    $self->{'_ignoreempty'} = 0;                # write empty files

    $self->{'_options'}     = {

        # write comments out
        preserve_comments   => $preserve_comments,

        # backup on each save
        backup              => $backup,

        # use hfsync() to write files
        write_behind        => $write_behind,
    };

}#_init

#-------------------------------------------------------------------------------
sub new {

	my $self = shift;
	my $class = ref( $self ) || $self;

	$self = {
    };

    &_init( $self );

	my $obj = bless $self, $class;

    if( @_ ) {
    
        my $fn  = shift;
        my $ops = shift;

        if( $ops && (ref($ops) eq 'HASH') ) {

            my $new_ops = Hub::cpref( $ops );

            Hub::merge( $new_ops, $self->{'_options'} );

            $self->{'_options'} = $new_ops;

        }#if
        
        $obj = $obj->load( $fn );

    }#if

    return $obj;

}#new

#-------------------------------------------------------------------------------
# Read and parse the file from disk.
#
# This is a singleton per filename.
#
sub load {

	my ($self, $filename) = @_; # do NOT shift
	my $type = ref($self) || die "$self is not an object!";

    $filename = Hub::fixpath($filename) || $self->{'_filename'};

    return $self unless $filename;

    my $stats = stat $filename;

    my $file_id = Hub::abspath( $filename, "nocheck" );

    unless( $file_id ) {

        Hub::lerr( "Cannot create file_id! $filename" );

        return $self;

    }#unless

    my $mtime = $stats ? $stats->mtime() : -1;

    if( $self->{'_file_id'} && ($self->{'_file_id'} ne $file_id) ) {

        #
        # We already represent a file, go get your own
        #

        return Hub::mkinst( 'HashFile', $filename );

    }#if

    #
    # Get the representing instance if it exists
    #
    my @reset_itr = keys %$NAMESPACE; # reset the iterator!

    while( my($k,$v) = each %$NAMESPACE ) {

        unless( $v->{'_file_id'} ) {

            Hub::lerr( "!! Cache contains an invalid file_id: $v->{'_filename'}" );

            delete $NAMESPACE->{$k};

            next;

        }#unless

        if( $v->{'_file_id'} eq $file_id ) {

            $_[0] = $v; # update $self (singleton)

            if( $mtime == -1 ) {

                $v->clear();

            } elsif( $mtime > $v->{'_last_sync'} ) {

                $v->clear();

                $v->readFromDisk( $filename );

            } else {
                
            }#if

            return $v;

        }#if

    }#while

    if( ! ($self->{'_file_id'}) && ! $file_id ) {

        #
        # This is a new hashfile which doesn't exist on disk yet
        #

        if( $filename ) {

            $self->{'_filename'} = $filename;

            $self->{'_file_id'} = Hub::abspath( $filename );

            Hub::lerr( "Missing file_id: $filename" ) unless $self->{'_file_id'};

            $NAMESPACE->{$self} = $self;

        }#if

        return $self;

    }#if

    #
    # This is a new representing instance, load the file from disk.
    #

    $self->{'_filename'} = $filename;

    # If the cache is cleared, yet this instance exists, we need to resync

    $self->{'_dirty'} and $self->writeToDisk();

    $self->clear();

    $self->{'_file_id'} = $file_id;

    $self->readFromDisk( $filename );

    return $self;

}#load

#-------------------------------------------------------------------------------
sub include {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $filename = Hub::fixpath(shift);
    my $options  = shift;
    my $newinc   = 1;

    if( @{$self->{'_included'}} ) {

        foreach my $inc_hf ( @{$self->{'_included'}} ) {

            if( $inc_hf->{'_filename'} eq $filename ) {

                my $newinc = 0;

                my $last_sync = $inc_hf->{'_last_sync'};

                my $reread = Hub::mkinst( 'HashFile', $filename );

                if( $reread->{'_last_sync'} > $last_sync ) {

                    Hub::merge( $self->{'_data'}, $reread->{'_data'}, $options );

                }#if

                last;

            }#if

        }#foreach

    }#if
    
    if( $newinc ) {

        my $inc_hf = Hub::mkinst( 'HashFile', $filename );

        if( $inc_hf->{'_last_sync'} ) { # it exists

            Hub::merge( $self->{'_data'}, $inc_hf->{'_data'}, $options );

            push @{$self->{'_included'}}, $inc_hf;

        }#if

    }#if

    return $self;

}#include

#-------------------------------------------------------------------------------
sub mergein {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    Hub::merge( $self->{'_data'}, @_ );

}#mergein

#-------------------------------------------------------------------------------
sub readFromDisk {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $filename = shift;

    unless( Hub::filetest( $filename ) ) {

        return;

    }#if

    my $line_num        = 0;
    my $ptr             = {
        _type   => 1,                   #   HASH        = 1
                                        #   ARRAY       = 2
                                        #   INLINE      = 3
                                        #   MULTILINE   = 4
        _data   => $self->{'_data'},
        _parent => 0,
    };
    my @blank_lines     = ();
    my @address         = ();
    my @comment_buffer  = ();
    my $inside_comment  = 0;

    my $stats = stat $filename;

    my $handle = Hub::fileopen( $filename );

    if( $handle ) {

        $DEBUG_READ and print "\n$filename\n";

        Hub::lerr( "Missing file_id: $self->{'_filename'}" ) unless $self->{'_file_id'};

        $NAMESPACE->{$self} = $self;

        seek($handle,0,0);

        while( <$handle> ) {

            $line_num++;

            chomp;
            
            s/\r$//;

            if( $inside_comment ) {

                if( $self->{'_options'}->{'preserve_comments'} )
                {
                    push @comment_buffer, "$_\n" unless
                        /$FORMAT_ID/;
                }

            } elsif( $_ =~ /$$FORMAT_IN{'INCLUDE'}/ ) {

                $self->include( $1 );

            } elsif( $_ =~ /$$FORMAT_IN{'COMMENT_CLOSE'}/ ) {

                $inside_comment = 0;

            } elsif( $_ =~ /$$FORMAT_IN{'COMMENT_OPEN'}/ ) {

                $inside_comment = 1;

            } elsif( $_ =~ /$$FORMAT_IN{'COMMENT'}/ ) {

                if( $self->{'_options'}->{'preserve_comments'} )
                {
                    push @comment_buffer, "$_\n" unless
                        /$FORMAT_ID/;
                }

            } elsif( $_ =~ /$$FORMAT_IN{'BLANKLINE'}/ ) {

                #
                # A blank line is part of a comment unless it is part of
                # a scalar value.
                #
                # We don't know if it is part of a scalar value until we 
                # determine the value continues on the next line.  Hence
                # we buffer the blank lines.
                # 

                if( $ptr->{'_type'} >= 3 ) {
                    
                    push @blank_lines, "\n";

                } elsif( $self->{'_options'}->{'preserve_comments'} ) {

                    push @comment_buffer, "\n";

                }#if

            } else {

                if( $_ =~ /$$FORMAT_IN{'INLINE_ASSIGN'}/ ) {

                    #
                    # An inline assignment is a scalar value.  If an inline
                    # assignment is made inside an array container, we append
                    # a small name/value hash.
                    #
                    my $name = $1;
                    my $value = $2;

                    push @comment_buffer, @blank_lines;
                    undef @blank_lines;

                    if( $ptr->{'_type'} eq 3 ) {

                        $ptr = $ptr->{'_parent'};

                        pop @address;

                    }#if

                    if( $ptr->{'_type'} eq 1 ) {

                        $ptr->{'_data'}->{$name} = $value;

                        $ptr->{'_data'}->{$name} =~ s/\\([$FORMAT_MASK])/$1/g;

                        push @address, $name;

                        $ptr = {
                            _type   => 3,
                            _data   => \$ptr->{'_data'}->{$name},
                            _parent => $ptr,
                        };

                    } elsif( $ptr->{'_type'} eq 2 ) {

                        my $new = {
                            'name'  => $name,
                            'value' => $value,
                        };

                        push @{$ptr->{'_data'}}, $new;

                    }#if

                } elsif( $_ =~ /$$FORMAT_IN{'SCALAR_OPEN'}/ ) {

                    #
                    # This is a multi-line scalar which works for the most part
                    # just the same as an INLINE_ASSIGN, execpt that it is allowed
                    # in arrays.
                    #

                    push @comment_buffer, @blank_lines;
                    undef @blank_lines;

                    if( $ptr->{'_type'} eq 3 ) {

                        $ptr = $ptr->{'_parent'};

                        pop @address;

                    }#if

                    my $new = ();

                    my $name = $1;

                    $name = "ANON($line_num)" unless $name;

                    if( $ptr->{'_type'} eq 1 ) {

                        $ptr->{'_data'}->{$name} = $new;

                        push @address, $name;

                        $ptr = {
                            _type   => 4,
                            _data   => \$ptr->{'_data'}->{$name},
                            _parent => $ptr,
                        };

                    } elsif( $ptr->{'_type'} eq 2 ) {

                        push @{$ptr->{'_data'}}, $new; # $name is lost

                        push @address, $name;

                        my $pos = $#{$ptr->{'_data'}};

                        $ptr = {
                            _type   => 4,
                            _data   => \($ptr->{'_data'}[$pos]),
                            _parent => $ptr,
                        };

                    }#if

                } elsif( $_ =~ /$$FORMAT_IN{'ARRAY_OPEN'}/ ) {

                    #
                    # An array can be a hash member, or an element of another 
                    # array.
                    #

                    if( $ptr->{'_type'} eq 3 ) {

                        $ptr = $ptr->{'_parent'};

                        pop @address;

                    }#if

                    my $new = [];

                    my $name = $1;

                    $name = "ANON($line_num)" unless $name;

                    if( $ptr->{'_type'} eq 1 ) {

                        if( defined $ptr->{'_data'}->{$name} &&
                            ref($ptr->{'_data'}->{$name}) eq 'ARRAY' ) {

                            # re-use existing member of the same type (for include)
                            $new = $ptr->{'_data'}->{$name};

                        } else {

                            $ptr->{'_data'}->{$name} = $new;

                        }#if

                        push @address, $name;

                        $ptr = {
                            _type   => 2,
                            _data   => $new,
                            _parent => $ptr,
                        };

                    } elsif( $ptr->{'_type'} eq 2 ) {

                        push @{$ptr->{'_data'}}, $new; # $name is lost

                        push @address, $name;

                        my $pos = $#{$ptr->{'_data'}};

                        $ptr = {
                            _type   => 2,
                            _data   => $new,
                            _parent => $ptr,
                        };

                    }#if

                } elsif( $_ =~ /$$FORMAT_IN{'HASH_OPEN'}/ ) {

                    #
                    # A hash can be a hash member or an element in an array.
                    #

                    if( $ptr->{'_type'} eq 3 ) {

                        $ptr = $ptr->{'_parent'};

                        pop @address;

                    }#if

                    my $new = {};

                    my $name = $1;

                    $name = "ANON($line_num)" unless $name;

                    if( $ptr->{'_type'} eq 1 ) {

                        if( defined $ptr->{'_data'}->{$name} &&
                            ref($ptr->{'_data'}->{$name}) eq 'HASH' ) {

                            # re-use existing member of the same type (for include)
                            $new = $ptr->{'_data'}->{$name};

                        } else {

                            $ptr->{'_data'}->{$name} = $new;

                        }#if

                        push @address, $name;

                        $ptr = {
                            _type   => 1,
                            _data   => $new,
                            _parent => $ptr,
                        };

                    } elsif( $ptr->{'_type'} eq 2 ) {

                        push @{$ptr->{'_data'}}, $new;

                        push @address, $name;

                        my $pos = $#{$ptr->{'_data'}};

                        $ptr = {
                            _type   => 1,
                            _data   => $new,
                            _parent => $ptr,
                        };

                    }#if

                } elsif( $_ =~ /$$FORMAT_IN{'CLOSE'}/ ) {

                    #
                    # Closing brackets imply that we should close the current
                    # thing we're working on.
                    #

                    if( $ptr->{'_type'} eq 3 ) {

                        # Implicitly close the inline scalar
                        $ptr = $ptr->{'_parent'};

                        pop @address;

                    }#if

                    $ptr->{'_parent'} and $ptr = $ptr->{'_parent'};

                    pop @address;

                } else {

                    #
                    # This is data.  It can either be part of a scalar value
                    # or an array element.
                    #
                    $_ =~ s/\\([$FORMAT_MASK])/$1/g;
                
                    if( $ptr->{'_type'} >= 3 ) {

                        ${$ptr->{'_data'}} and ${$ptr->{'_data'}} .= "\n";

                        @blank_lines and ${$ptr->{'_data'}} .= join '', @blank_lines;

                        undef @blank_lines;

                        ${$ptr->{'_data'}} .= $_;

                    } elsif( $ptr->{'_type'} eq 2 ) {

                        my $item = $_;

                        $item =~ s/^$WS//;

                        push @{$ptr->{'_data'}}, $item;

                    }#if

                }#if

                my $addr = join( ':', @address );

                $self->{'_options'}->{'preserve_order'} and
                    $self->{'_order'}->{$addr} = $line_num;

                if( $self->{'_options'}->{'preserve_comments'} &&
                    @comment_buffer ) {

                    $self->{'_comments'}->{$addr} = 
                        join( "", @comment_buffer );

                    @comment_buffer = ();

                }#if

            }#if

            if( $DEBUG_READ ) {

                my $addr = join( ':', @address );
                print Hub::fw( 6, $line_num );
                print "| ";
                print Hub::fw( 50, $addr );
                print "| $_\n";

            }#if

        }#while

        Hub::fileclose( $handle, $filename );

        $self->{'_last_sync'} = $stats->mtime();

    } else {

        Hub::lerr( "$!: $filename" );

    }#if

    return $self;

}#readFromDisk

#-------------------------------------------------------------------------------
sub saveCopy {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $real_filename = $self->{'_filename'};

    my $new_filename = shift || return;

    unless( $new_filename =~ /\// ) {

        my $real_path = Hub::getpath( $real_filename );

        $new_filename = Hub::fixpath( "$real_path/$new_filename" );

    }#unless

    my $copy = Hub::mkinst( 'HashFile', $new_filename );

    $copy->clear();

    Hub::merge( $copy->{'_data'},        $self->{'_data'} );
    Hub::merge( $copy->{'_comments'},    $self->{'_comments'} );
    Hub::merge( $copy->{'_order'},       $self->{'_order'} );

    $copy->writeToDisk();

}#saveCopy

#-------------------------------------------------------------------------------
sub save {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";
    my $options = shift;

    $self->{'_ignoreempty'} = 1 if $options =~ /--ignore-empty/;

    #
    # write_behind marks this instance as dirty, and waits for the caller
    # to call hfsync() to actually write the files to disk.
    #

    if( $self->{'_options'}->{'write_behind'} && $$NAMESPACE{$self} ) {

        $self->{'_dirty'} = 1;

    } else {

        $self->writeToDisk();

    }#if

}#save

#-------------------------------------------------------------------------------
sub writeToDisk {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $filename = $self->{'_filename'};

    return unless $filename;

    #
    # Backup (optional)
    #
    my $backup_level = $self->{'_options'}->{'backup'};

    if( $backup_level && ($filename !~ ".hf_meta.hf") ) {

        Hub::lmsg( "Using HashFile Backups: $backup_level", "info" );

        my $name = Hub::getname( $filename );

        my $path = Hub::getpath( $filename );

        my $meta = Hub::mkinst( 'Meta', "$path/.hf_meta.hf" );

        my $bak_num_format = '%04d';

        my $bak_num = $meta->create_id( "backup_$name", $bak_num_format, 0 );

        my $bak_rolloff = $bak_num - $backup_level;

        my $rolloff_filename = sprintf "$path/.%04d-$name", $bak_rolloff;

        unlink $rolloff_filename; # keep only $backup_level number of backups

        my $bak_filename = "$path/.$bak_num-$name";

        # use 'copy', b/c 'rename' means this instance gets a new dev/inode (which
        # messes with our cache.

        Hub::filetest( $filename ) and copy( $filename, $bak_filename );

        $meta->{'_file'}->writeToDisk();

    }#if

    # If the file has been modified, merge in our changes first

    my $stats = stat $filename;

    if( $stats && ($self->{'_last_sync'} < $stats->mtime()) ) {

        Hub::lwarn( "Merging into modified file: $filename" );

        my $local_data = Hub::cpref( $self->{'_data'} );

        $self->readFromDisk();

        Hub::merge( $self->{'_data'}, $local_data, "--overwrite" );

    }#if

    #
    # Compose the data in flat format
    #

    $self->{'_new_order'} = {};

    # Print contents
    my $contents = $self->print( $self->{'_data'} );

    #
    # Check for empty files
    #

    unless( $contents || $self->{'_ignoreempty'} ) {

        Hub::lerr( "Empty file content: $filename" );

        # Sorry, this is not the way to delete a file.  We are assuming empty contents
        # is an error in the processing, and we return here to protect the file.

        $self->{'_last_sync'} = 0; # Force a reload

        $self->{'_dirty'} = 0;

        return;

    }#unless

    #
    # Write
    #

    # Open and close the file as quickly as possible.  Even with the locking mechanisms
    # in place, there is still danger.

    Hub::lmsg( "Writing: $filename", "save" );

    my $handle = Hub::fileopen( ">$filename" );

    if( $handle ) {

        seek($handle,0,0);

        # We always give the file a version number
        print $handle "# $FORMAT_ID\n$contents";

        Hub::fileclose( $handle, $filename );

        #
        # Update state information
        #

        $self->{'_dirty'} = 0;

        my $stats = stat $filename;

        $self->{'_last_sync'} = $stats->mtime();

        $self->{'_options'}->{'preserve_order'} and
            $self->{'_order'} = Hub::cpref( $self->{'_new_order'} );

        delete $self->{'_new_order'};

        #
        # Set _file_id (remember we may have been the ones to create this file)
        #

        my $file_id = Hub::abspath( $filename );

        $self->{'_file_id'} = $file_id;

        #
        # if we created this file, we now represent it
        #

        Hub::lerr( "Missing file_id: $self->{'_filename'}" ) unless $self->{'_file_id'};

        $NAMESPACE->{$self} = $self;

    }#if

}#writeToDisk

#-------------------------------------------------------------------------------
sub print {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $ptr  = shift || return;

    return &format( $ptr, {
        '_order'     => $self->{'_order'},
        '_new_order' => $self->{'_new_order'},
        '_comments'  => $self->{'_comments'},
    } );

}#print

#-------------------------------------------------------------------------------
sub format {

    my $ptr     = shift || return;
    my $meta    = shift;
    my $indent  = shift || 0;
    my $address = shift || [];
    my $order   = shift || 0;

    $meta ||= {
        '_order'        => {},
        '_new_order'    => {},
        '_comments'     => {},
    };

    my $buf = "";

    if( ref($ptr) =~ /(HASH|::)/ ) {

        my $prefix = join( ':', @$address );

        $prefix and $prefix .= ':';

        my @sorted_keylist = ();
        
        if( ! %{$meta->{'_order'}} ) {

            @sorted_keylist = sort keys %$ptr;

        } else {

            @sorted_keylist = sort{ $meta->{'_order'}->{"$prefix$a"} <=>
                                    $meta->{'_order'}->{"$prefix$b"} } keys %$ptr;

        }#if

        foreach my $k ( @sorted_keylist ) {

            my $v = $$ptr{$k};

            my $key_type = ref($v);

            push @$address, $k;

            my $addr = join(':',@$address);

            $meta->{'_new_order'}->{$addr} = ++$order;

            if( $meta->{'_comments'}->{join(':',@$address)} ) {

                $buf .= $meta->{'_comments'}->{join(':',@$address)};

            }#if

            $k =~ s/ANON\(\d+\)//;

            if( $key_type ) {

                my $padding = $INDENT;

                $padding x= $indent;

                $buf .= $padding;
                
                if( $$FORMAT_OUT{"${key_type}_OPEN"} ) {

                    $buf .= sprintf $$FORMAT_OUT{"${key_type}_OPEN"}, $k;

                } else {

                    $buf .= sprintf $$FORMAT_OUT{"UNKNOWN_OPEN"}, $k;

                }#if

                $buf .= &format( $v, $meta, ++$indent, $address, $order );

                $padding = $INDENT;

                $padding x= --$indent;

                $buf .= $padding;

                $buf .= sprintf $$FORMAT_OUT{'CLOSE'}, $k;

            } else {

                my $padding = $INDENT;

                $padding x= $indent;

                $buf .= $padding;

                my $text = $v; # don't teak orig

                $text =~ s/([^\\]?)([$FORMAT_MASK])/$1\\$2/g;

                if( !$k || $v =~ /\n/ ) {

                    $buf .= sprintf $$FORMAT_OUT{'SCALAR_OPEN'}, $k;

                    $buf .= "$text\n";

                    $buf .= $padding;

                    $buf .= sprintf $$FORMAT_OUT{'CLOSE'}, $k;

                } else {

                    $buf .= sprintf $$FORMAT_OUT{'INLINE_ASSIGN'}, $k, $text;

                }#if

            }#if

            pop @$address;

        }#foreach

    } elsif( ref($ptr) eq 'ARRAY' ) {

        foreach my $v ( @$ptr ) {

            my $val_type = ref( $v );

            push @$address, "unknown";

            my $addr = join(':',@$address);

            $meta->{'_new_order'}->{$addr} = ++$order;

            if( $meta->{'_comments'}->{$addr} ) {

                $buf .= $meta->{'_comments'}->{$addr};

            }#if

            if( $val_type ) {

                my $padding = $INDENT;

                $padding x= $indent;

                $buf .= $padding;

                

                if( $$FORMAT_OUT{"${val_type}_OPEN"} ) {

                    $buf .= sprintf $$FORMAT_OUT{"${val_type}_OPEN"}, '';

                } else {

                    $buf .= sprintf $$FORMAT_OUT{"UNKNOWN_OPEN"}, '';

                }#if




                $buf .= &format( $v, $meta, ++$indent, $address, $order );

                $padding = $INDENT;

                $padding x= --$indent;

                $buf .= $padding;

                $buf .= sprintf $$FORMAT_OUT{'CLOSE'}, $v;

            } else {

                my $padding = $INDENT;

                $padding x= $indent;

                $buf .= $padding;

                my $text = $v; # don't tweak orig

                $text =~ s/([^\\])([$FORMAT_MASK])/$1\\$2/g;

                if( $text =~ /\n/ ) {

                    $buf .= sprintf $$FORMAT_OUT{'SCALAR_OPEN'}, '';

                    $buf .= "$text\n";

                    $buf .= $padding;

                    $buf .= sprintf $$FORMAT_OUT{'CLOSE'}, $v;

                } else {

                    $buf .= sprintf "$text\n";

                }#if

            }#if

            pop @$address;

        }#foreach

    }#if

    return $buf;

}#format

#-------------------------------------------------------------------------------
# Sync all modified instances to disk
#
sub hfsync {

    keys %$NAMESPACE; # reset the iterator!

    while( my($k,$v) = each %$NAMESPACE ) {

        $v->writeToDisk() if $v->{'_dirty'};

    }#while

}#hfsync

#-------------------------------------------------------------------------------
sub getTimestamp {

	my $self = shift;
	my $class = ref( $self ) || $self;

    return 0 unless $self->{'_filename'};

    my $stats = stat $self->{'_filename'};

    return defined $stats ? $stats->mtime() : 0;

}#getTimestamp

#-------------------------------------------------------------------------------
sub clear {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    $self->{'_last_sync'}   = 0;
    $self->{'_data'}        = {};
    $self->{'_comments'}    = {};
    $self->{'_order'}       = {};
    $self->{'_dirty'}       = 0;
    $self->{'_included'}    = [];

}#clear

#-------------------------------------------------------------------------------
# setOption KEY VALUE
#
# Sets an option for this instance.
#
# KEY can be:
#
#   preserve_comments           0 or 1, We will write out comments
#
#   backup                      Set the number of backups you want to keep
#
#   write_behind                0 or 1, Do not write to disk on save() but mark
#                               it as dirty, and defer to the hfsync() method.
#
#-------------------------------------------------------------------------------

sub setOption {

	my $self = shift;
	my $classname = ref($self) || die "$self is not an object!";

    my($k,$v) = @_;

    $k and $self->{'_options'}->{$k} = $v;

}#setOption

# ------------------------------------------------------------------------------
# AUTOLOAD
# 
# Data handlers: getv takev setv appendv
# ------------------------------------------------------------------------------

sub AUTOLOAD {

    my $self = shift;
    my $name = $AUTOLOAD;

    croak "Illegal call to instance method" unless ref($self);

    if( $name =~ /::($HANDLERS)$/ ) {

        my $action = 'Hub::h' . $1 ;

        unshift @_, $self->{'_data'};

        goto &$action;

    } else {

        croak "Unknown instance call: $name";

    }#if

}#AUTOLOAD

# ------------------------------------------------------------------------------
# DESTROY
# 
# Defining this function prevents it from being searched in AUTOLOAD
# ------------------------------------------------------------------------------

sub DESTROY {

}#DESTROY

#===============================================================================
#-------------------------------------------------------------------------------
#                            D E P R I C A T E D  
#-------------------------------------------------------------------------------
#===============================================================================

#-------------------------------------------------------------------------------
sub data {

    my $self = shift;
	my $self_ref = ref($self) || die "$self is not an object!";

    return $self->{'_data'};

}#data

#-------------------------------------------------------------------------------
# depricated, please use method data()
sub data_hash {

    my $self = shift;
	my $self_ref = ref($self) || die "$self is not an object!";
    my %empty = ();

    my $copy = Hub::cpref( $self->{'_data'} );

    return defined $copy ? %$copy : %empty;

}#data_hash

#-------------------------------------------------------------------------------
# depricated, please use method data()
sub get_root {
    
    my $self = shift;
	my $self_ref = ref($self) || die "$self is not an object!";

    wantarray and return values %{$self->{'_data'}};

    return $self->{'_data'};

}#get_root

#-------------------------------------------------------------------------------
sub get {

    my $self = shift;
	my $self_ref = ref($self) || die "$self is not an object!";

    my $fully_qualified_id      = shift || '';

    my $fully_qualified_types   = shift || '';

    my @parts = split /:/, $fully_qualified_id;

    my @type = split /:/, $fully_qualified_types;

    $fully_qualified_id and push @parts, $fully_qualified_id unless @parts;

    my $ptr = $self->{'_data'};

    my $ret = undef;

    my ($parent, $child, $parent_part) = undef;

    my $level = 0;

    return undef unless @parts;

    foreach my $part ( @parts ) {

        $part eq "" and next;

        if( ref($ptr) eq "ARRAY" ) {

            $ret = undef;
            $parent = undef;

            foreach my $item ( @{$ptr} ) {

                if( ref($item) eq "HASH" ) {

                    if( ($$item{'_id'} eq $part) || ($$item{'name'} eq $part) ) {

                        $parent = $ptr;
                        $ret = $item;
                        $ptr = $item;

                        last;

                    }#if
                    
                }#if

            }#foreach

        } else {

            if( ref($ptr) ne "HASH" ) {

                if( $#type >= 0 ) {

                    $ptr = {};

                    $parent->{$parent_part} = $ptr;
                    
                } else {

                    return undef;

                }#if

            }#if

            if( ! defined $ptr->{$part} && $#type >= 0 ) {

                if( $type[$level] eq "HASH" ) {

                    $ptr->{$part} = {};

                } elsif( $type[$level] eq "ARRAY" ) {

                    $ptr->{$part} = [];

                } else {

                    $ptr->{$part} = {};

                }#if

            }#if

            $parent = $ptr;
            $parent_part = $part;

            $ret = $ptr->{$part};
            $ptr = $ptr->{$part};

        }#if

        $child = $part;

        $level++;

    }#foreach

    return $ret;

}#get

# ------------------------------------------------------------------------------
sub setRoot {

    my $self        = shift;
	my $classname   = ref($self) || die "$self is not an object!";

    my $data        = shift;

    if( ref($data) eq 'HASH' ) {

        $self->{'_data'} = $data;

    }#if

}#setRoot

# ------------------------------------------------------------------------------
sub set {

    my $self    = shift;
	my $self_ref = ref($self) || die "$self is not an object!";

    my $address = shift;
    my $value   = shift;
    my $options = shift;

    my @parts   = split /:/, $address;

    $address and push @parts, $address unless @parts;

    my $key     = pop @parts;

    my $ptr     = $self->{'_data'};
    my $ret     = $ptr;

    foreach my $part ( @parts ) {

        $part eq "" and next;

        if( ref($ptr) eq "ARRAY" ) {

            my $top = $ptr;

            foreach my $item ( @{$ptr} ) {

                if( ref($item) eq "HASH" ) {

                    if( $$item{'_id'} eq $part ) {

                        $ptr = $item;

                        last;

                    }#if
                    
                }#if

            }#foreach

            if( $ptr eq $top ) { # not found

                my $new = { _id => $part };

                push @$ptr, $new;

                $ptr = $new;

            }#if

        } else {

            if( (! defined $ptr->{$part}) || ! ref($ptr->{$part}) ) {

                $ptr->{$part} = {};

                if( ref($ptr) eq 'ARRAY' ) {

                    $ptr->{$part}->{'_id'} = $part;

                }#if

            }#if

            $ptr = $ptr->{$part};

        }#if

    }#foreach

    if( (!@parts) && ($key) ) {

        if( defined $value ) {

            if( !ref($ptr->{$key}) && $options =~ "--append" ) {

                $ptr->{$key} .= $value;

            } else {

                $ptr->{$key} = $value;

            }#if

        } else {

            delete $ptr->{$key};

        }#if

    } elsif( (defined $ptr) && ($ptr != $self->{'_data'}) ) {

        if( ref( $ptr ) eq "ARRAY" ) {

            if( $value eq undef ) {

                #
                # Setting an undefined value is the same as deleting it
                #

                my $idx = 0;

                my $remove_at = undef;

                foreach my $i ( @$ptr ) {

                    if( ref($i) eq "HASH" ) {

                        if( $i->{'_id'} eq $key ) {

                            $remove_at = $idx;

                            last;

                        }#if

                    } elsif( !ref($i) ) {

                        if( $i eq $key ) {

                            $remove_at = $idx;

                            last;

                        }#if

                    }#if

                    $idx++;

                }#foreach

                if( defined $remove_at ) {

                    splice( @$ptr, $remove_at, 1 );

                }#if

            } else {

                if( ref($value) eq "HASH" ) {

                    unless( $$value{'_id'} || $$value{'name'} ) {

                        $$value{'_id'} = $key;

                    }#unless

                } elsif( !(ref($value) && $key) ) {

                    $value = {
                        '_id'   => $key,
                        'value' => $value,
                    };

                }#if

                foreach my $item ( @{$ptr} ) {

                    if( ref($item) eq "HASH" ) {

                        if( $$item{'_id'} eq $key ) {

                            $ptr = $item;

                            last;

                        }#if
                        
                    }#if

                }#foreach

                if( ref($ptr) eq 'ARRAY' ) {

                    push @$ptr, $value;

                } elsif( ref($ptr) eq 'HASH' ) {

                    if( ref($value) eq 'HASH' ) {

                        Hub::merge( $ptr, $value, "--overwrite --prune" );

                    }#if

                }#if

            }#if

        } elsif( ref( $ptr ) eq "HASH" ) {

            if( defined $value ) {

                if( !ref($ptr->{$key}) && $options =~ "--append" ) {

                    $ptr->{$key} .= $value;

                } else {

                    $ptr->{$key} = $value;

                }#if

            } else {

                delete $ptr->{$key};

            }#if

        } else {

            Hub::lerr( "Could not set: $key" );

        }#if

    }#if

}#set

#-------------------------------------------------------------------------------
return 1;

=pod:summary Flat file data which supports nested perl structures.

=pod:synopsis

    use Hub;
    my $hf = Hub::mkinst('HashFile','myfile.hf');

    $hf->set( "eye_color", "green" );   # set a simple property
    $hf->save();                        # saves the file to disk

=pod:description

HashFiles are used for property files and small databases.

There will be one and only one HashFile instance for each file.  If a second
HashFile instance is created and is asked to load a file which is already 
represented, this second instance is replaced with a reference to the first.

=cut

1;
