package Hub::Knots::Addressable;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our @EXPORT     = qw//;
our @EXPORT_OK  = qw//;

# ------------------------------------------------------------------------------
# TIEHASH - Tie interface method
# ------------------------------------------------------------------------------

sub TIEHASH {

    my $self = shift;

    my $impl = shift;

    my $obj = bless {}, $self;

    return $obj;

}#TIEHASH

# ------------------------------------------------------------------------------
# FETCH - Tie interface method
# ------------------------------------------------------------------------------

sub FETCH {

    my $self = shift;

    my $index = shift;

    Hub::hgetv( $self, $index );

}#FETCH

# ------------------------------------------------------------------------------
# STORE - Tie interface method
# ------------------------------------------------------------------------------

sub STORE {

    my $self = shift;

    my $index = shift;

    my $value = shift;

    Hub::hsetv( $self, $index, $value );

}#STORE

# ------------------------------------------------------------------------------
# DELETE - Tie interface method
# ------------------------------------------------------------------------------

sub DELETE {

    my $self = shift;

    my $index = shift;

    Hub::hsetv( $self, $index, undef );

}#DELETE

# ------------------------------------------------------------------------------
# CLEAR - Tie interface method
# ------------------------------------------------------------------------------

sub CLEAR {

    my $self = shift;

    my @reset = keys %$self;

    map { delete $self->{$_} } keys %$self;

}#CLEAR

# ------------------------------------------------------------------------------
# EXISTS - Tie interface method
# ------------------------------------------------------------------------------

sub EXISTS {

    my $self = shift;

    my $index = shift;

    defined Hub::hgetv( $self, $index );

}#EXISTS

# ------------------------------------------------------------------------------
# FIRSTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub FIRSTKEY {

    my $self = shift;

    my @reset = keys %$self;

    each %$self;

}#FIRSTKEY

# ------------------------------------------------------------------------------
# NEXTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub NEXTKEY {

    my $self = shift;

    my $lastindex = shift;

    each %$self;

}#NEXTKEY

# ------------------------------------------------------------------------------
# SCALAR - Tie interface method
# ------------------------------------------------------------------------------

sub SCALAR {

    my $self = shift;

    scalar %$self;

}#SCALAR

# ------------------------------------------------------------------------------
# UNTIE - Tie interface method
# ------------------------------------------------------------------------------

sub UNTIE {

    my $self = shift;

    my $count = shift || 0;

}#UNTIE

# ------------------------------------------------------------------------------


'???';
