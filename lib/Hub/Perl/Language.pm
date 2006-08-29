package Hub::Perl::Language;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Compress::Zlib;
#use Fcntl ':mode';
#use IO::File;
use Hub qw/:lib/;

use constant DEFAULTSORTKEY     => '_sort';
use constant EXPR_NUMERIC       => '\A[+-]?[\d\.Ee_]+\Z';
use constant EXPR_BLESSED       => '=HASH\(0x[0-9a-f]+\)\Z';

our @EXPORT         = qw//;
our @EXPORT_OK      = qw/

    asa
    ash
    check
    expect
    fear
    abort
    opts
    objopts
    cmdopts
    bestof
    subst
    getuid
    getgid
    sortkbyv
    subfield
    max
    min
    flip
    rmval
    rmsubhash
    cpref
    uniq
    subhash
    checksum
    getbyname
    merge
    asarray
    flatten
    hashget
    replace
    digout
    diff
    touch
    intdiv
    dice

/;

our ($a,$b,$SORT_KEY) = (); # sorting


sub asa ;
sub check ;
sub opts ;
sub objopts ;
sub cmdopts ;
sub _assignopt ;
sub subst ;
sub getuid ;
sub getgid ;
sub touch ;
sub expect ;
sub fear ;
sub abort ;
sub hash ;
sub array ;
sub scalar ;
sub bestof ;
sub min ;
sub max ;
sub intdiv ;
sub flip ;
sub rmval ;
sub rmsubhash ;
sub hashget ;
sub uniq ;
sub sortkbyv ;
sub subhash ;
sub cpref ;
sub checksum ;
sub getbyname ;
sub merge ;
sub _mergeHash ;
sub _mergeArray ;
sub _getId ;
sub _mergeElement ;
sub asarray ;
sub _prioritysort ;
sub _compscalar ;
sub flatten ;
sub subfield ;
sub replace ;
sub digout ;
sub diff ;
sub _diff_hashes ;
sub _diff_arrays ;
sub dice ;

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
    my $name = $Hub::Perl::Language::AUTOLOAD;
	return if substr($name,-9) eq '::DESTROY';
    use Carp qw/croak/;
    croak "Undefined subroutine: $name" if defined &Hub::Perl::Language::Language;
    $AutoLoader::AUTOLOAD = "Hub::Perl::Language::Language";
    local $SIG{__WARN__} = sub {
        warn $_[0] unless $_[0] =~ "Subroutine AUTOLOAD redefined";
    };
    AutoLoader::AUTOLOAD();
    foreach my $pkg ( @Hub::Perl::Language::ISA ) {
        my ($pkgname) = $pkg =~ /.*::(\w+)$/;
        eval("${pkg}::Language");
    }
    goto &$name;
}

1;

__END__
