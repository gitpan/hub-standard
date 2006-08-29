package Hub::Base::Package;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our ($VERSION,$AUTOLOAD);

our @EXPORT         = qw//;
our @EXPORT_OK      = qw/modexec/;


sub modexec ;
sub new ;
sub call ;
sub AUTOLOAD ;
sub DESTROY ;
sub parsefile ;

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
    my $name = $Hub::Base::Package::AUTOLOAD;
	return if substr($name,-9) eq '::DESTROY';
    use Carp qw/croak/;
    croak "Undefined subroutine: $name" if defined &Hub::Base::Package::Package;
    $AutoLoader::AUTOLOAD = "Hub::Base::Package::Package";
    local $SIG{__WARN__} = sub {
        warn $_[0] unless $_[0] =~ "Subroutine AUTOLOAD redefined";
    };
    AutoLoader::AUTOLOAD();
    foreach my $pkg ( @Hub::Base::Package::ISA ) {
        my ($pkgname) = $pkg =~ /.*::(\w+)$/;
        eval("${pkg}::Package");
    }
    goto &$name;
}

1;

__END__
