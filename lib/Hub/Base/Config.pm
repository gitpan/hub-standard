package Hub::Base::Config;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw//;

#!BulkSplit

#-------------------------------------------------------------------------------
sub new {

	my $self    = shift;
	my $class   = ref( $self ) || $self;

	$self = {
        _valid_conf => 0,
        props => {},
        sourcePaths => [],
        targetSourcePaths => [],
        path_cache => {},
        working_paths => [],
        swapped_working_paths => [],
	};

	my $obj = bless $self, $class;

    $obj->init();

	return $obj;

}#new

#-------------------------------------------------------------------------------
sub init {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $serverFileName = ".conf";

    unless( Hub::filetest( $serverFileName ) ) {

        $serverFileName = "server.conf";

    }#unless

    unless( Hub::filetest( $serverFileName ) ) {

        Hub::lwarn( "Cannot find: .conf or $serverFileName!" );

        $self->{'_valid_conf'} = 0;

    }#unless

    $self->{'_valid_conf'} = $self->loadConfigFile( $serverFileName );

    #
    # The correct website configuration is this:
    #
    #   a) there is a file named .conf which has the low-level configuration
    #      settings which are managed by sitemgr.sh
    #
    #   b) there is key in the file named by server_conf which specifies the
    #      filename of the site's configuration file (where the user sets
    #      server settings)
    #
    #   c) server_conf should point to "server.conf"
    #

    $self->{'props'}->{'server_conf'} and
        $self->loadConfigFile( $self->{'props'}->{'server_conf'} );

    #
    # Setup the logger options
    #

    Hub::lshow( split /,\s*/, $self->{'props'}->{'log_level'} );

    Hub::lopt( 'show_stack', $self->{'props'}->{'log_stack_depth'} );

    defined $self->{'props'}->{'log_max_size'} and
        Hub::lopt( 'max_size', $self->{'props'}->{'log_max_size'} );

    defined $self->{'props'}->{'log_show_source'} and
        Hub::lopt( 'show_source', $self->{'props'}->{'log_show_source'} );

    defined $self->{'props'}->{'tee_msgs'} and
        Hub::lopt( 'tee', $self->{'props'}->{'tee_msgs'} );

    $self->{'props'}->{'log_disable'} and Hub::lopt( 'oppressed', 1 );

    #
    # Setup source paths
    #

    my $common_path = $self->{'props'}->{'common_path'} || "";
    my $source_path = $self->{'props'}->{'src_path'} || "";

    # FIRST
    push @{$self->{'sourcePaths'}}, $source_path if $source_path;

    # SECOND
    push @{$self->{'sourcePaths'}}, $common_path if $common_path;

    $self->loadConfigDir( "$common_path/conf" );

    $self->loadConfigDir( $self->{'props'}->{'conf_path'} );

}#init

#-------------------------------------------------------------------------------
# refresh()
#
# Throughout the life of a request, many things get shoved in here.  Like
# screen values and user preferences.  Hence, this method to re-init is
# called at the beginning of each request.  Which is good, since it also
# re-reads the *.conf files from disk if they have been modified.
#
#-------------------------------------------------------------------------------

sub refresh {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    $self->{'_valid_conf'} = 0;
    $self->{'props'} = {};
    $self->{'sourcePaths'} = [];
    $self->{'targetSourcePaths'} = [];
    $self->{'path_cache'} = {};
    $self->{'working_paths'} = [],
    $self->{'swapped_working_paths'} = [],
    $self->init();

}#refresh

#-------------------------------------------------------------------------------
sub loadConfigDir {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $dir = shift || return;

    if( opendir DIR, $dir ) {

        my @webconst = grep /\.conf$/, readdir DIR;

        closedir DIR;

        foreach my $file ( @webconst ) {

            $self->loadConfigFile("$dir/$file");

        }#foreach

    }#if

}#loadConfigDir

#-------------------------------------------------------------------------------
sub loadConfigFile {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $file = shift;

    unless( Hub::filetest( $file ) ) {

        return 0;

    }#unless

    my $wchf = Hub::mkinst( 'HashFile', $file );

    my %hash = $wchf->data_hash();

    foreach my $key ( keys %hash ) {

        if( ref($self->{'props'}->{$key}) eq "HASH" ) {

            if( ref($hash{$key}) eq "HASH" ) {

                my $subhash = $hash{$key};

                foreach my $subkey ( keys %$subhash ) {

                    $self->{'props'}->{$key}->{$subkey} = $$subhash{$subkey};

                }#foreach

            }#if

        } else {

            $self->{'props'}->{$key} = $hash{$key};

        }#if

    }#foreach

    return 1;

}#loadConfigFile

#-------------------------------------------------------------------------------
# getProps
#
# return the properties hash reference
#-------------------------------------------------------------------------------

sub getProps {

	my $self      = shift;
	my $classname = ref($self) || die "$self is not an object!";

    return $self->{props};

}#getProps

#-------------------------------------------------------------------------------
#   Retreive a runtime constant
#
#   $class->get( "key:subkey:subsubkey" );
#   $class->get( "key", "default" );
#
#-------------------------------------------------------------------------------
sub get {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $key = shift || return;
    my $default = shift || undef;
    
    my $value = Hub::getbyname( $key, $self->{'props'} );

    return defined $value ? $value : $default;

}#get

#-------------------------------------------------------------------------------
#   Retreive a runtime constant
#
#   $class->getConst( key )
#   $class->getConst( key, default )
#
#-------------------------------------------------------------------------------
sub getConst {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $key = shift || return;
    my $default = shift || undef;
    
    my $value =
        defined $self->{'props'}->{$key} ? $self->{'props'}->{$key} : $default;

    return $value;

}#getConst

#-------------------------------------------------------------------------------
#   Retreive a runtime constant
#
#   $class->setConst( key, value )
#
#-------------------------------------------------------------------------------
sub setConst {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $key   = shift || return;
    my $value = shift;

    if( ref($key) eq 'HASH' ) {

        Hub::merge( $self->{'props'}, $key, "--overwrite" );

    } else {
    
        $self->{'props'}->{$key} = $value;

    }#if

}#setConst

# ------------------------------------------------------------------------------
#   Add a path to the list of source paths.  Call's to the getSourcePath()
#   will get files from these added paths.
#
#   Paths are added to the beginning of the list, thus having precedence to
#   existing paths.
#
#   $class->addSourcePath( path )
# ------------------------------------------------------------------------------

sub addSourcePath {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $path = shift || return;

    unshift @{$self->{'sourcePaths'}}, $path;

}#addSourcePath

# ------------------------------------------------------------------------------
# Remove a source path
#
sub rmSourcePath {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $path = shift || return;

    Hub::rmval( $self->{'sourcePaths'}, $path );

}#rmSourcePath

# ------------------------------------------------------------------------------
# addTargetPath( $path )
#
# Add a path to the list of target paths.  Call's to the getSourcePath()
# will get files from these added paths.
#
# Paths are added to the beginning of the list, thus having precedence to
# existing paths.
# ------------------------------------------------------------------------------

sub addTargetSourcePath {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $path = shift || return;

    unshift @{$self->{'targetSourcePaths'}}, $path;

}#addTargetSourcePath

# ------------------------------------------------------------------------------
# Remove a target source path
#
sub rmTargetSourcePath {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $path = shift || return;

    Hub::rmval( $self->{'targetSourcePaths'}, $path );

}#rmTargetSourcePath

# ------------------------------------------------------------------------------
# get a path to an existing image.  first try the website path, then the common
# one.
sub getImagePath {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $img_id    = shift || return;
    my $img_name  = shift || return;
    my $reskey    = shift;

    $img_id = Hub::varname( $img_id );
    $reskey = 'image_path' unless $reskey;

    my @paths     = (
        $self->{'props'}->{$reskey},
        $self->{'props'}->{'common_path'} . "/images" );

    my @fields = split /-/, $img_id;
    pop @fields;
    push @fields, $img_name;
    my $relative_path = join( "/", @fields );

    foreach my $path_root ( @paths ) {

        if( Hub::filetest( "$path_root/$relative_path" ) ) {

            return Hub::fixpath( "$path_root/$relative_path" );

        }#if

    }#foreach

    return "";

}#getImagePath

# ------------------------------------------------------------------------------
sub getCommonImagePath {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $filePath  = $self->{'props'}->{'common_path'};

    return unless $filePath;

    my @fields = split /-/, shift;

    $filePath .= "/images";

    my $name = pop @fields;

    foreach my $subDir ( @fields ) {

        if( -d $filePath . "/$subDir" ) {

            $filePath .= "/$subDir";

        } else {

            return "";

        }#if

    }#foreach

    return Hub::fixpath($filePath);

}#getCommonImagePath

# ------------------------------------------------------------------------------
# getResource( $type, $name, $filename )
#
# Find the relative path to the specified resource.
#
#   $type       Can be 'sound', 'image', 'video', or 'data'
#   $name       Is the source name such as: 'img-logo-main'
#   $filename   Is the filename of the resource.
#
# If $name is empty, we will look in the base directory of all locations.
# If $filename is empty, we will return the first matching directory.
# ------------------------------------------------------------------------------
sub getResource {

	my $self      = shift;
	my $self_ref  = ref($self) || die "$self is not an object!";

    my ($type,$name,$filename) = @_;

    return unless $type; #required

    $name = Hub::varname( $name ); # when an 'id' was passed

    #
    # 1st) Check the current working paths
    #

    my $resource_path = $self->getSourcePath( $filename );

    $resource_path =~ /$filename$/ and return $resource_path;

    #
    # 2nd) Check if it exists in the user-upload area.
    #

    my $target_res_path = $self->getConst( "target_${type}_path" );

    my $local_res_path = $self->getConst( "${type}_path" );

    my $common_res_path = $self->getConst( 'common_path' ) . 
        $self->getConst( "common_${type}_path" );

    my @paths = ();

    $target_res_path and push @paths, $target_res_path;
    $local_res_path and push @paths, $local_res_path;
    $common_res_path and push @paths, $common_res_path;

    my @fields = split /-/, $name;

    pop @fields;

    push @fields, $filename;

    my $relative_path = join( "/", @fields );

    foreach my $path_root ( @paths ) {

        if( Hub::filetest( "$path_root/$relative_path" ) ) {

            return Hub::fixpath( "$path_root/$relative_path" );

        }#if

    }#foreach

    #
    # 3rd) Check the common/system directory.
    #

    if( $common_res_path ) {

        if( Hub::filetest( "$common_res_path/sys/$filename" ) ) {

            return Hub::fixpath( "$common_res_path/sys/$filename" );

        }#if

    }#if

    return "";

}#getResource

# ------------------------------------------------------------------------------
sub getResourcePath {

	my $self      = shift;
	my $type      = ref($self) || die "$self is not an object!";

    my $dirProperty = shift || return;

    my $filePath = $self->{'props'}->{$dirProperty};

    unless( $filePath ) {

        if( $dirProperty =~ /target_([a-z]+_path)/ ) {

            $filePath = $self->{'props'}->{$1};

        }#if

    }#unless

    if( $dirProperty =~ /^common_/ ) {

        if( $dirProperty ne "common_path" ) {

            my $commonpath = $self->getConst( 'common_path' );

            $filePath = $commonpath . $filePath;

        }#if

    }#if

    return unless( $filePath );

    my $origname = shift;

    my $name = Hub::varname( $origname ); # when an 'id' was passed

    my @fields = split /-/, $name;

    pop @fields; # remove the name

    foreach my $subDir ( @fields ) {

        if( -d $filePath . "/$subDir" ) {

            $filePath .= "/$subDir";

        } elsif( mkdir $filePath . "/$subDir", oct("0775") ) {

            $filePath .= "/$subDir";

            chmod $filePath, oct("0775");

        } else {

            Hub::lerr( "$!: $filePath" );

        }#if

    }#foreach

    my $finalPath = Hub::fixpath($filePath);

    return $finalPath;

}#getResourcePath

# ------------------------------------------------------------------------------
sub pushWorkingDir {
	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";
    my $dir  = shift || "./";
    unshift @INC, $dir;
    unshift @{$self->{'working_paths'}}, $dir;
}

# ------------------------------------------------------------------------------
sub popWorkingDir {
	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";
    shift @INC;
    return shift @{$self->{'working_paths'}};
}

# ------------------------------------------------------------------------------
sub getWorkingDirs {
	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";
    return Hub::cpref( $self->{'working_paths'} );
}

# ------------------------------------------------------------------------------
sub swapWorkingDirs {
	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";
    my $dirs = shift;
    if( ref($dirs) eq 'ARRAY' ) {
        $self->{'swapped_working_paths'} = $self->getWorkingDirs();
    } else {
        $dirs = $self->{'swapped_working_paths'};
    }#if
    $self->{'working_paths'} = $dirs;
}

# ------------------------------------------------------------------------------
sub getSourcePath {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $criteria    = shift;
    my $cwd         = ${$self->{'working_paths'}}[0];
    my $id          = "$cwd:$criteria";
    my $result      = undef;

    if( $self->{'path_cache'}->{$id} ) {

    } elsif( Hub::filetest( $criteria ) ) {

        $self->{'path_cache'}->{$id} = $criteria;

    } else {

        foreach my $path (
            @{$self->{'working_paths'}},
            @{$self->{'targetSourcePaths'}},
            @{$self->{'sourcePaths'}}
        ) {

            my $candidate = Hub::fixpath("$path/$criteria");

            if( Hub::filetest( $candidate ) ) {

                if( -d $candidate ) {

                    $candidate .= '/' unless $candidate =~ /\/$/;

                }#if

                $self->{'path_cache'}->{$id} = $candidate;

                last;

            }#if

        }#foreach

    }#if
    
    if( $self->{'path_cache'}->{$id} eq 'not found' ) {

        return undef;

    } else {

        return $self->{'path_cache'}->{$id};

    }#if

}

#-------------------------------------------------------------------------------
return 1;

'???';
