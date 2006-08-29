package Hub::Parse::Transform;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our @EXPORT     = qw//;
our @EXPORT_OK  = qw/

    fw
    populate
    fixpath
    getpath
    getname
    abspath
    relpath
    datetime
    attrhash
    getext
    jsstr
    mkabsdir
    dhms
    hashtoattrs
    getspec
    safestr
    nbspstr
    packcgi
    siteurl
    trimcss
    polish
    trimhtmlstyle
    ps
    unpackcgi
    indenttext
    fcols

/;


sub safestr ;
sub packcgi ;
sub unpackcgi ;
sub getspec ;
sub getpath ;
sub getname ;
sub getext ;
sub fixpath ;
sub abspath ;
sub relpath ;
sub mkabsdir ;
sub findAbsolutePath ;
sub siteurl ;
sub nbspstr ;
sub jsstr ;
sub html ;
sub datetime ;
sub fw ;
sub ps ;
sub fcols ;
sub indenttext ;
sub dhms ;
sub populate ;
sub Xpopulate ;
sub _runTweaks ;
sub attrhash ;
sub hashtoattrs ;
sub trimhtmlstyle ;
sub trimcss ;
sub polish ;

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
    my $name = $Hub::Parse::Transform::AUTOLOAD;
	return if substr($name,-9) eq '::DESTROY';
    use Carp qw/croak/;
    croak "Undefined subroutine: $name" if defined &Hub::Parse::Transform::Transform;
    $AutoLoader::AUTOLOAD = "Hub::Parse::Transform::Transform";
    local $SIG{__WARN__} = sub {
        warn $_[0] unless $_[0] =~ "Subroutine AUTOLOAD redefined";
    };
    AutoLoader::AUTOLOAD();
    foreach my $pkg ( @Hub::Parse::Transform::ISA ) {
        my ($pkgname) = $pkg =~ /.*::(\w+)$/;
        eval("${pkg}::Transform");
    }
    goto &$name;
}

1;

__END__
