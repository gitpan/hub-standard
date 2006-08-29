package Hub::Data::Address;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2

use Hub qw/:lib/;

our @EXPORT         = qw//;
our @EXPORT_OK      = qw/

    vartype
    varroot
    varname
    varparent
    dotaddr
    expand
    keydepth

/;

our $DELIMS         = ':/';


sub keydepth ;
sub vartype ;
sub varroot ;
sub varname ;
sub varparent ;
sub dotaddr ;
sub expand ;

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
    my $name = $Hub::Data::Address::AUTOLOAD;
	return if substr($name,-9) eq '::DESTROY';
    use Carp qw/croak/;
    croak "Undefined subroutine: $name" if defined &Hub::Data::Address::Address;
    $AutoLoader::AUTOLOAD = "Hub::Data::Address::Address";
    local $SIG{__WARN__} = sub {
        warn $_[0] unless $_[0] =~ "Subroutine AUTOLOAD redefined";
    };
    AutoLoader::AUTOLOAD();
    foreach my $pkg ( @Hub::Data::Address::ISA ) {
        my ($pkgname) = $pkg =~ /.*::(\w+)$/;
        eval("${pkg}::Address");
    }
    goto &$name;
}

1;

__END__
