package Hub::Base::Instance;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our ($VERSION,$AUTOLOAD);

our @EXPORT         = qw//;
our @EXPORT_OK      = qw//;

our $HANDLERS       = qq/get|take|set|append/;

our %NSMAP = (
    'i', 'temp',            # Instance (reset at end of callback)
    'c', 'config',          # Configuration
    'p', 'persistent',      # Persistent instance (not reset)
    'o', 'objects',         # Persistent objects (->refresh supported)
);


sub new ;
sub run ;
sub comptv ;
sub compdv ;
sub AUTOLOAD ;
sub DESTROY ;
sub mkobj ;
sub rmobj ;
sub obj ;
sub prepare ;
sub finish ;
sub _loadconf ;

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
    my $name = $Hub::Base::Instance::AUTOLOAD;
	return if substr($name,-9) eq '::DESTROY';
    use Carp qw/croak/;
    croak "Undefined subroutine: $name" if defined &Hub::Base::Instance::Instance;
    $AutoLoader::AUTOLOAD = "Hub::Base::Instance::Instance";
    local $SIG{__WARN__} = sub {
        warn $_[0] unless $_[0] =~ "Subroutine AUTOLOAD redefined";
    };
    AutoLoader::AUTOLOAD();
    foreach my $pkg ( @Hub::Base::Instance::ISA ) {
        my ($pkgname) = $pkg =~ /.*::(\w+)$/;
        eval("${pkg}::Instance");
    }
    goto &$name;
}

1;

__END__
