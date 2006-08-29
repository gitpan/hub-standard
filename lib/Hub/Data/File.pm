package Hub::Data::File;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use IO::File;
use File::stat;
use Fcntl           qw/:flock/;
use File::Copy      qw/copy/;
use Hub             qw/:lib/;

our @EXPORT         = qw//;
our @EXPORT_OK      = qw/

    filescan
    filetest
    fileopen
    fileclose
    filetime
    find
    cpdir
    cpfile
    rmdirrec
    rmfile
    chperm
    listfiles
    find_files
    mkdiras
    getcrown
    readfile
    writefile
    parsefile
    safefn

    $MODE_TO_MASK

/;


sub filetest ;
sub filescan ;
sub fileopen ;
sub fileclose ;
sub filetime ;
sub find ;
sub cpdir ;
sub cpfile ;
sub rmfile ;
sub mvfile ;
sub rmdirrec ;
sub chperm ;
sub _chperm ;
sub _chperm_normal ;
sub _chperm_win32 ;
sub listfiles ;
sub find_files ;
sub mkdiras ;
sub getcrown ;
sub readfile ;
sub writefile ;
sub parsefile ;
sub safefn ;

# ------------------------------------------------------------------------------
# AUTOLOAD
#
# We intend to attempt AUTOLOADing the module just once.
#
# This has been inserted as part of the BulkSplit structure.  We use AutoLoader
# to load the module body.
#
# When the module defines it's own AUTOLOAD, it will become redefined, and this 
# method will not be hit again.
# ------------------------------------------------------------------------------
sub AUTOLOAD {
    use AutoLoader qw//;
    my $name = $Hub::Data::File::AUTOLOAD;
	return if substr($name,-9) eq '::DESTROY';
    use Carp qw/croak/;
    croak "Undefined subroutine: $name" if defined &Hub::Data::File::File;
    $AutoLoader::AUTOLOAD = "Hub::Data::File::File";
    local $SIG{__WARN__} = sub {
        warn $_[0] unless $_[0] =~ "Subroutine AUTOLOAD redefined";
    };
    AutoLoader::AUTOLOAD();
    foreach my $pkg ( @Hub::Data::File::ISA ) {
        my ($pkgname) = $pkg =~ /.*::(\w+)$/;
        eval("${pkg}::File");
    }
    goto &$name;
}

1;

__END__
