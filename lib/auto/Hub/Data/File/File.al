# NOTE: Changes made here will be lost when bulksplit is run again.
package Hub::Data::File;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# File
#
# Called by the framework to invoke Autoloader::AUTOLOAD, in essence loading
# this file.
# ------------------------------------------------------------------------------
sub File {
}#File

#line 38

eval( "use Win32::FileSecurity" );

my $HASWIN32 = $@ ? 0 : 1;

#
# Translations for Win32::FileSecurity::MakeMask
#

our $MODE_TO_MASK = {

    '7' => {
        'FILE'  => ["FULL"],
        'DIR'   => ["FULL", "GENERIC_ALL"],
    },

    '6' => {
        'FILE'  => ["CHANGE"],
        'DIR'   => ["ADD", "CHANGE", "GENERIC_WRITE", "GENERIC_READ", "GENERIC_EXECUTE"],
    },

    '5' => {
        'FILE'  => ["READ", "STANDARD_RIGHTS_EXECUTE"],
        'DIR'   => ["GENERIC_READ", "GENERIC_EXECUTE"],
    },

    '4' => {
        'FILE'  => ["READ"],
        'DIR'   => ["GENERIC_READ", "GENERIC_EXECUTE"],
    },

    '3' => {
        'FILE'  => ["STANDARD_RIGHTS_WRITE", "STANDARD_RIGHTS_EXECUTE"],
        'DIR'   => ["GENERIC_READ", "GENERIC_EXECUTE"],
    },

    '2' => {
        'FILE'  => ["STANDARD_RIGHTS_WRITE"],
        'DIR'   => ["GENERIC_READ", "GENERIC_EXECUTE"],
    },

    '1' => {
        'FILE'  => ["STANDARD_RIGHTS_EXECUTE"],
        'DIR'   => ["GENERIC_EXECUTE"],
    },

    '0' => {
        'FILE'  => [""],
        'DIR'   => [""],
    },

};

our %RECOGNIZED     = (); # list of existing files on the system

# ------------------------------------------------------------------------------
# filetest PATH
# filetest PATH TEST
#
# Returns 1 if PATH is an element which we recognize as existing on disk.  The
# idea behind this logic is that it is faster to build a list of existing files
# once then check the list as the program progresses, than it is to make the -e,
# -f and -d perl calls.  The frequency with which the list of known files is
# updated is left to user configuration. (see filescan)
# ------------------------------------------------------------------------------

sub filetest {

    my $fn      = shift || return 0;
    my $test    = shift || '-e';

    my $absfn = Hub::abspath($fn,'NOCHECK');

    if( %RECOGNIZED ) {

        if( $RECOGNIZED{$absfn}
            && defined $RECOGNIZED{$absfn}{$test} ) {

            return $RECOGNIZED{$absfn}{$test};

        }#if

    }#if

    my $result = eval "$test \$fn"; # we do NOT want to test the absolute path

    if( $result ) {

        # we DO want to remember the file by its absolute path

        $RECOGNIZED{$absfn}{$test} = $result;

    }#if

    return $result;

}#filetest

# ------------------------------------------------------------------------------
# filescan PATH, [PATH] ...
# 
# Clear the list of recognized files, then find all nodes in the specified 
# path(s) and mark them as existing.
# ------------------------------------------------------------------------------

sub filescan {

    undef %RECOGNIZED; # clear the hash

    foreach my $path ( @_ ) {

        my @files = Hub::find( Hub::abspath( $path ) );

        foreach my $file ( @files ) {

            $RECOGNIZED{$file} = { '-e' => 1, };

        }#foreach

    }#foreach

}#filescan

#-------------------------------------------------------------------------------
# fileopen FILENAME [PARAMS]
#
# For platforms which don't flock, create a lockfile for a specified
# filename.  Waits for #winlock_timeout seconds if a lockfile exists (unless
# READONLY is specified).
#-------------------------------------------------------------------------------

sub fileopen {

    my $filename = shift || return;

    my $readonly = $filename !~ /^>/;

    my $handle = IO::File->new( $filename );

    croak "$!: $filename" unless defined $handle;

    my $flockopr = $readonly ? LOCK_SH : LOCK_EX;

    my $flocked = flock($handle,$flockopr);

    if( $@ or not $flocked ) {

        my $path = Hub::getpath( $filename );

        my $name = Hub::getname( $filename );

        my $lock_filename = "$path/.lock-$name";

        my $timeout = $Hub->config->getConst( 'winlock_timeout' ) || 10;

        $timeout *= 2; # because we sleep for 1/2 second

        for( 0 .. $timeout ) {

            last unless -e $lock_filename;

            last if $readonly;

            Hub::lwarn( "Waiting for lock on $filename" );

            sleep .5;

        }#for

        if( open( LOCKFILE, ">$lock_filename" ) ) {

            print LOCKFILE "Windows lock file";

            close LOCKFILE;

        } else {

            Hub::lerr( "$!: $lock_filename" ) unless $readonly;

        }#if

    }#if

    return $handle;

}#fileopen

#-------------------------------------------------------------------------------
# fileclose HANDLE, [FILENAME]
#
# Unlock and close the file.
# Always remove the lockfile for a specified filename.
#-------------------------------------------------------------------------------

sub fileclose {

    my $handle = shift;

    my $filename = shift;

    if( defined $handle ) {

        flock($handle,LOCK_UN);

        close $handle;

    }#if

    if( $filename ) {

        my $path = Hub::getpath( $filename );

        my $name = Hub::getname( $filename );

        my $lock_filename = "$path/.lock-$name";

        unlink $lock_filename if -e $lock_filename;

    }#if

}#fileclose

# ------------------------------------------------------------------------------
# filetime - Return file's timestamp
#
# filetime LIST, [OPTIONS]
#
# Where:
#
#   LIST                A list of valid path names or file handles
#   OPTIONS -mtime      Return last-modified time (default)
#           -atime       last-accessed time
#           -ctime       creation time
#   OPTIONS -max        Return greatest value (default)
#           -min         least value
# ------------------------------------------------------------------------------

sub filetime {

    my $opts = Hub::opts( \@_, { mtime => 1, max => 1 } );

    my $result = -1;

    foreach my $file ( @_ ) {

        my $time = -1;

        my $fh = new IO::File;

        if( $fh->open( $file ) ) {

            my $stats = stat( $fh );

            $$opts{'mtime'} and $time = $stats->mtime();

            $$opts{'atime'} and $time = $stats->mtime();

            $$opts{'ctime'} and $time = $stats->mtime();

        }#if

        $result = $$opts{'max'} ? Hub::max( $result, $time ) :
            Hub::min( $result, $time );

    }#foreach

    return $result;

}#filetime

# ------------------------------------------------------------------------------
# find DIRECTORY, OPTIONS
#
# DIRECTORY     SCALAR, Can be an absolute or relative path.
#
# OPTIONS       HASH {
#                   ignore_path  => [ "CVS", ],
#                   ignore       => [ ".cvsignore$" ],
#                   include      => [ "pl$", "pm$" ],
#                   filesonly    => 0,
#               }
#
# RETURNS       ARRAY
#
# NOTES         . and .. are always ignored.
# ------------------------------------------------------------------------------

sub find {

    my $opts = Hub::opts( \@_ );
    my $dir = shift || die "Provide a directory";
    my $opth = shift;

    defined $opth and Hub::merge( $opts, $opth );

    # Defaults

    $opts->{'ignore'}  ||= [ "\\/\\.", ];        # hidden items

    $opts->{'include'} ||= [ ".*", ];            # all items

    $dir = Hub::fixpath( $dir );

    my @list = ();

    my $fh  = IO::File->new();

    if( opendir $fh, $dir ) {

        my @subdirs = ();

        my @all = grep ! /^\.+$/, readdir $fh;

        closedir $fh;

        foreach my $name ( @all ) {

            my $i   = "$dir/$name";
            my $ok  = 0;

            foreach my $x ( @{$opts->{'include'}} ) {

                if( $i =~ $x ) {
                
                    $ok = 1;

                    last;

                }#if

            }#foreach

            foreach my $x ( @{$opts->{'ignore'}}, @{$opts->{'ignore_path'}} ) {

                if( $i =~ $x ) {
                
                    $ok = 0;

                    last;

                }#if

            }#foreach

            if( -d $i ) {

                my $recurse = 1;

                foreach my $x ( @{$opts->{'ignore_path'}} ) {

                    if( $i =~ $x ) {
                    
                        $recurse = 0;

                        last;

                    }#if

                }#foreach

                if( $recurse ) {

                    push @subdirs, $i;

                }#if

                $ok = 0 if $opts->{'filesonly'};

            } else {

                $ok = 0 if $opts->{'dirsonly'};

            }#if

            if( $ok ) {

                push @list, $i;

            }#if

        }#foreach

        foreach my $subdir ( @subdirs ) {

            push @list, Hub::find( $subdir, $opts );

        }#foreach

    } else {

        Hub::lerr( "$!: $dir (in " . cwd() . ")" );

    }#if

    return @list;

}#find

# ------------------------------------------------------------------------------
# cpdir SOURCE_DIR, TARGET_DIR, [OPTIONS]
# 
# Copy a directory.  Files are only copied when the source file's modified time
# is newer (unless the 'force' option is set).
#
# SOURCE_DIR    SCALAR, Source directory
#
# TARGET_DIR    SCALAR, Destination *parent* directory
#
# OPTIONS       HASHREF, Options:
#
#               {
#                   include => [ ".*" ],
#                   ignore  => [ "CVS", "\.cvsignore", "README" ],
#                   force   => 1,
#
#                   uid     => Hub::getuid( "username" ),    # user id
#                   gid     => Hub::getgid( "username" ),    # group id
#
#                   dmode   => 0775,
#                   fmode   => {            # fmode can ref a hash of extensions
#                       '*'     => 0644,    # '*' is used for unmatched
#                       'cgi'   => 0755,    # specific cgi file extension
#                       'dll'   => "SKIP",  # do not update dll files
#                   }
#                   fmode   => 0655,        # or, fmode can be used for all files
#
#               }
#
# ------------------------------------------------------------------------------

sub cpdir {

    my $source_dir  = Hub::fixpath( shift );
    my $target_dir  = Hub::fixpath( shift );
    my $options     = shift || {};

    return Hub::lerr( "Bad source: $source_dir" ) unless -d $source_dir;
    return Hub::lerr( "Bad target: $target_dir" ) unless -d Hub::getpath( $target_dir );

    my @items = Hub::find( $source_dir, $options );

    foreach my $item ( @items ) {

        my $target = $item;

        $target =~ s/^$source_dir/$target_dir/;

        if( -d $item ) {

            if( (! -d $target) || $options->{'force'} ) {

                mkdir $target;

                chperm( $target, $options );

            }#if

        } else {

            Hub::cpfile( $item, $target, $options );

        }#if

    }#foreach

    return $#items + 1;

}#cpdir

# ------------------------------------------------------------------------------
# cpfile SOURCE TAREGET [PERMISSIONS]
# 
# 
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# cpfile - Copy a file and apply permissions and mode
#
# cpfile $SOURCE, $TARGET, [\%PERMISSIONS], [OPTIONS]
#
# Where:
#
#   $SOURCE         File to be copied
#   $TARGET         Target path (file or directory)
#   \%PERMISSIONS   Permission hash (see Hub::chperm)
#   OPTIONS         -newer      Only copy when the source is newer (mtime) than 
#                               the target
#
# See also: L<chperm>
# ------------------------------------------------------------------------------

sub cpfile {

    my $source  = shift;
    my $target  = shift;

    my $opts    = Hub::opts( \@_ );

    my $perms = shift;

    return unless -f $source;

    if( Hub::filetest( $target, '-d' ) ) {

        my $fn = Hub::getname( $source );

        $target .= "/$fn";

    }#if

    my $copy = $$opts{'force'};

    if( !$copy ) {

        my $source_stats = stat( $source );

        my $target_stats = stat( $target );

        if( !$target_stats || $source_stats->mtime() > $target_stats->mtime() ) {

            $copy = 1;

        }#if

    }#if

    if( $copy ) {

        my $fpath = Hub::getpath( $target );

        Hub::mkabsdir( $fpath );

        if( copy( $source, $target ) ) {

            Hub::chperm( $target, $perms );
        
        } else {
        
            Hub::lerr( "$!: $target" );

        }#if

    }#if

    return $target;

}#cpfile

# ------------------------------------------------------------------------------
# rmfile
#
# We rely on server security and file permissions to prevent tamperring.
# ------------------------------------------------------------------------------

sub rmfile {

    my $count = unlink @_;

    if( $count ) {
    
        $Hub->setiv( 'tainted', 1 );

        map { delete $RECOGNIZED{$_} } @_;

    }#if

    return $count;

}#rmfile

# ------------------------------------------------------------------------------
# mvfile
# 
# Move (rename) a file
# ------------------------------------------------------------------------------

sub mvfile {

    my ($f1,$f2) = @_;

    rename $f1, $f2;

    delete $RECOGNIZED{$f1};

    Hub::touch( $f2 );

}#mvfile

# ------------------------------------------------------------------------------
# rmdirrec TARGET_DIR
# 
# Recursively remove a directory.
# ------------------------------------------------------------------------------

sub rmdirrec {

    my $dir = shift || die "Provide a directory";
    my $fh  = IO::File->new();

    $dir = Hub::abspath( $dir );

    return unless -d $dir;

    my @list = ();

    if( opendir $fh, $dir ) {

        my @subdirs = ();

        my @all = grep ! /^\.+$/, readdir $fh;

        closedir $fh;

        foreach my $name ( @all ) {

            my $i = "$dir/$name";

            if( -f $i ) {
            
                Hub::rmfile( $i );

            } elsif( -d $i ) {

                Hub::rmdirrec( $i );

            }#if

        }#foreach

        rmdir $dir;

        delete $RECOGNIZED{$dir};

    }#if

}#rmdirrec

# ------------------------------------------------------------------------------
# chperm PATH OPTIONS
# 
# Change permissions of a file or directory
#
# OPTIONS
#
#
#   {
#       # see find and cpdir
#       
#       'recperms'   => 1,       # will recurse if PATH is a directory
#
#   }
#
# ------------------------------------------------------------------------------

sub chperm {

    my $path        = Hub::fixpath( shift );
    my $options     = shift || {};

    my @items = $options->{'recperms'} ? Hub::find( $path, $options ) : $path;

    foreach my $target ( @items ) {

        if( -d $target ) {

            my $mode = $options->{'dmode'} || 0775;

            _chperm( $options->{'uid'}, $options->{'gid'}, $mode, $target );

        } else {

            if( $options->{'fmode'} ) {

                my $mode = 0664;

                if( ref($options->{'fmode'}) eq 'HASH' ) {
                
                    my $ext = Hub::getext( $target );

                    if( $options->{'fmode'}->{$ext} ) {
                        
                        $mode = $options->{'fmode'}->{$ext};

                    } else {
                        
                        $mode = $options->{'fmode'}->{'*'}
                            if $options->{'fmode'}->{'*'};

                    }#if

                } else {

                    $mode = $options->{'fmode'};

                }#if

                _chperm( $options->{'uid'}, $options->{'gid'}, $mode, $target );

            }#if

        }#if

    }#foreach

}#chperm

sub _chperm {

    my $owner   = shift;
    my $group   = shift;
    my $mode    = shift;

    foreach my $target ( @_ ) {

        if( $HASWIN32 && ($mode ne "SKIP") ) {

            #
            # We still don't "really" change the owner (Anybody know how?)
            #

            $target = Hub::abspath( $target );

            my $mode_str = sprintf( "%o", $mode );

            my $other = $Hub->getcv( "win32/other_name", "Everyone" );

            $group ||= $Hub->getcv( "win32/group_name", Win32::LoginName );

            $owner ||= $Hub->getcv( "win32/owner_name" );

            unless( $owner ) { $owner = $other; $other = ""; }

            my $owner_flag = substr( $mode_str, 0, 1 );
            my $group_flag = substr( $mode_str, 1, 1 );
            my $other_flag = substr( $mode_str, 2, 1 );

            my $passed = 1;

            $owner and $passed &= _chperm_win32( $owner, $owner_flag, $target, "WRITE_OWNER", "WRITE_DAC" );
            $group and $passed &= _chperm_win32( $group, $group_flag, $target );
            $other and $passed &= _chperm_win32( $other, $other_flag, $target );

            _chperm_normal( $owner, $group, $mode, $target )
                unless $passed;

        } else {

            _chperm_normal( $owner, $group, $mode, $target );

        }#if

    }#foreach

}

sub _chperm_normal {

    my $owner   = shift;
    my $group   = shift;
    my $mode    = shift;
    my $target  = shift;

    # Change owner first
    defined $owner and chown $owner, $group, $target;

    # Convert string of octal digits
    $mode = length(sprintf('%o',$mode)) > 3 ? oct($mode) : $mode;

    chmod $mode, $target unless $mode eq "SKIP";

}

sub _chperm_win32 {

    my $user    = shift;
    my $flag    = shift;
    my $target  = shift;

    my $index   = -d $target ? "DIR" : "FILE";
    my $mmargs  = $MODE_TO_MASK->{$flag}->{$index};
    my $retval  = 0;

    my @mmargs  = @_;

    push @mmargs, @$mmargs if ref($mmargs) eq 'ARRAY';

    if( @mmargs ) {

        $retval = 1;

        my $mask = Win32::FileSecurity::MakeMask( @mmargs );

        my $privHash = {};

        #
        # If there isn't an ACL, we receive: Error handling error: 3, GetFileSecurity
        #

        eval( "Win32::FileSecurity::Get( \$target, \$privHash )" );

        $@ and do { chomp $@; Hub::lerr( "$target: $@" ); $retval = 0; };

        return $retval unless $retval;

        if( $flag ) {

            $privHash->{$user} = $mask;

        } else {

            delete $privHash->{$user};

        }#if

        eval( "Win32::FileSecurity::Set( \$target, \$privHash )" );

        $@ and do { chomp $@; Hub::lerr( "$target: $@" ); $retval = 0; };

    }#if

    return $retval;

}

# ------------------------------------------------------------------------------
# listfiles
#
# List files in a directory.
# ------------------------------------------------------------------------------

sub listfiles {

    my @return  = ();
    my @paths   = ();
    my $ignore  = "";

    for( my $i=0; $i <= $#_; $i++ ) {

        if( $_[$i] =~ /^--/ ) {

            $_[$i] =~ /^--ignore=(.*)/ and $ignore = $1;

        } else {

            push @paths, $_[$i];

        }#if

    }#for

    foreach my $path ( @paths ) {

        opendir DIR, $path;

        my @files = readdir DIR;

        closedir DIR;

        foreach my $file ( @files ) {

            $file =~ /Thumbs.db/ and next;

            $file =~ /^__/ and next;

            $ignore and $file =~ /$ignore/ and next;

            -f "$path/$file" and push @return, $file;

        }#foreach

    }#foreach

    return @return;

}#listfiles

# ------------------------------------------------------------------------------
# Hub::find_files( $directory )
#
# $directory can be absolute or relative.  Trim the trailing slash before
# calling this method.
#
# Example:
#
#   Hub::find_files( '/var' );
#
# Returns and array of:
#
#   /var/log/lastlog
#   /var/log/setup.log
#   /var/log/setup.log.full
#   /var/log/sshd.log
#   /var/log/wtmp
#   /var/run/sshd.pid
#   /var/run/utmp
# ------------------------------------------------------------------------------

sub find_files {

    my @path = @_;

    my $dir  = "";

    if( $#path ) {

        map { m/\/$/ and chop } @path;

        $dir  = join "/", @path;

    }#if

    my @list = ();

    if( opendir FIND_DIR, $dir ) {

        my @f = ();
        my @d = ();

        my @a = grep ! /^\./, readdir FIND_DIR;

        closedir FIND_DIR;

        foreach my $i ( @a ) {

            if( -d "$dir/$i" ) {

                push @d, $i;

            } else {

                push @f, $i;

            }#if

        }#foreach

        push @list, map { "$dir/$_" } @f;

        foreach my $sub_dir ( @d ) {

            push @list, find_files( @path, $sub_dir );

        }#foreach

    }#if

    return @list;

}#find_files

# ------------------------------------------------------------------------------
# mkdiras
# 
# Make a directy with specified permissions
# ------------------------------------------------------------------------------

sub mkdiras {

    my $path    = shift || return;
    my $perms   = shift || {};

    if( mkdir $path ) {

        Hub::chperm( $path, $perms ) if %$perms;

    } else {

        Hub::lerr( "$!: $path" );

    }#if

}#mkdiras

# ------------------------------------------------------------------------------
# getcrown
# 
# Return the first line of a file
# ------------------------------------------------------------------------------

sub getcrown {

    my $filepath    = shift || die "Provide a file path";
    my $crown       = "";

    if( open FILE, $filepath ) {

        $crown = <FILE>;

        close FILE;

    }#if

    return $crown;

}#getcrown

# ------------------------------------------------------------------------------
# readfile PATH
# 
# Read and return the contents of a file.
# ------------------------------------------------------------------------------

sub readfile {

    my $path = shift || return;

    my $opts = Hub::opts(\@_) if @_;

    $path = Hub::spath( $path );

    local $_;

    my @contents = ();

    my $fh = Hub::fileopen( $path );

    if( $fh ) {

        @contents = <$fh>;

        Hub::fileclose( $fh, $path );

    }#if

    defined $$opts{'asa'} and return @contents;

    my $contents = '';

    map { $contents .= $_ } @contents;

    return $contents;

}#readfile

# ------------------------------------------------------------------------------
# writefile FILEPATH, CONTENTS, [FLAGS]
#
# Write CONTENTS to FILEPATH which is openned with FLAGS.  Default FLAGS is '>'.
# Sets the correct file permissions.
# ------------------------------------------------------------------------------

sub writefile {

    my ($filepath,$contents,$flags) = ('','','');

    ($filepath,$contents,$flags) = @_;

    return unless $filepath;

    croak "Undefined contents" unless defined $contents;

    my $perms = ();

    if( defined $flags && $flags =~ /^\d+$/ ) {

        $perms = { fmode => $flags };

        $flags = ">";

    }#if

    $flags ||= ">";

    my $ret = 0;

    my $fh = Hub::fileopen( "$flags$filepath" );

    if( $fh ) {

        print $fh ref($contents) eq 'SCALAR' ? $$contents : $contents;

        Hub::fileclose( $fh, $filepath );

        if( defined($perms) ) {

            Hub::chperm( $filepath, $perms );

        }#if

        $ret = 1;

    }#if

    return $ret;
      
}#writefile

# ------------------------------------------------------------------------------
# parsefile FILENAME, [DATA], [OPTIONS]
#
# FILENAME:     File to parse as a template.
#
# [DATA]:       Hashref of name/value pairs.
#
# [OPTIONS]:
#
#   -sdref      Return a scalar copy (not a reference)
#   -alone      Do not include configuration and instance values
#   -inline     Update the template on disk!
# 
# Populate a file with runtime data.
# ------------------------------------------------------------------------------

sub parsefile {

    my $opts = Hub::opts( \@_ );
    my $file = shift;
    my $data = shift || {};

    my @values = ( $data );
    
    push @values, $Hub->getcv( '/' ), $Hub->getiv( '/' )
        unless $$opts{'alone'};

    my $contents = Hub::readfile( $file );

    my $parser = Hub::mkinst( 'Parser', -template => \$contents );

    my $results = $parser->populate( @values );

    $$opts{'polish'} and Hub::polish( $results, -opts => $opts );

    Hub::expect( SCALAR => $results );

    $$opts{'inline'} and Hub::writefile( $file, $results );

    return $$opts{'sdref'} ? $$results : $results;
    
}#parsefile

# ------------------------------------------------------------------------------
# safefn EXPR
#
# Create a name which is safe for using as a filename.
#
# ------------------------------------------------------------------------------
#|test(match)   safefn( 'alsk/lsdkfj' );
#~              alsk_2f_lsdkfj
# ------------------------------------------------------------------------------
sub safefn {

    return Hub::safestr( @_ );

}#safefn

# ------------------------------------------------------------------------------

1;
