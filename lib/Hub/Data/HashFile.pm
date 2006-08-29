package Hub::Data::HashFile;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use File::stat;
use File::Copy      qw/copy/;
use Hub             qw/:lib/;

our ($VERSION,$AUTOLOAD);

our @EXPORT         = qw//;
our @EXPORT_OK      = qw/hffmt hfsync/;
our $HANDLERS       = qq/getv|takev|setv|appendv/;


sub refresh ;
sub _init ;
sub new ;
sub load ;
sub include ;
sub mergein ;
sub readFromDisk ;
sub saveCopy ;
sub save ;
sub writeToDisk ;
sub print ;
sub format ;
sub hfsync ;
sub getTimestamp ;
sub clear ;
sub setOption ;
sub AUTOLOAD ;
sub DESTROY ;
sub data ;
sub data_hash ;
sub get_root ;
sub get ;
sub setRoot ;
sub set ;

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
    my $name = $Hub::Data::HashFile::AUTOLOAD;
	return if substr($name,-9) eq '::DESTROY';
    use Carp qw/croak/;
    croak "Undefined subroutine: $name" if defined &Hub::Data::HashFile::HashFile;
    $AutoLoader::AUTOLOAD = "Hub::Data::HashFile::HashFile";
    local $SIG{__WARN__} = sub {
        warn $_[0] unless $_[0] =~ "Subroutine AUTOLOAD redefined";
    };
    AutoLoader::AUTOLOAD();
    foreach my $pkg ( @Hub::Data::HashFile::ISA ) {
        my ($pkgname) = $pkg =~ /.*::(\w+)$/;
        eval("${pkg}::HashFile");
    }
    goto &$name;
}

1;

__END__
