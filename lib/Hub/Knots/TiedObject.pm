package Hub::Knots::TiedObject;

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

# ------------------------------------------------------------------------------
# _key - Determine which key (public or private) to use
# ------------------------------------------------------------------------------

sub _key {

    my $index = shift;

    local $1;

    return $index =~ /^\*(.*)/ ? ('private',$1) : ('public',$index);

}#_key

# ------------------------------------------------------------------------------
# TIEHASH - Tie interface method
#
# TIEHASH 'Hub::Knots::TiedObject', $PACKAGE
# ------------------------------------------------------------------------------

sub TIEHASH {

    my $self = shift;

    my $pkg_name = shift;

    my %data = ();

    my $obj = bless {
    
        'public'    => \%data,
        'private'   => {
            'tied'  => tie( %data, $pkg_name ),
        },
        
    }, $self;

    return $obj;

}#TIEHASH

# ------------------------------------------------------------------------------
# FETCH - Tie interface method
# ------------------------------------------------------------------------------

sub FETCH {

    my $self = shift;

    my $index = shift;

    my ($namespace,$key) = _key( $index );

    return $self->{$namespace}->{$key};

}#FETCH

# ------------------------------------------------------------------------------
# STORE - Tie interface method
# ------------------------------------------------------------------------------

sub STORE {

    my $self = shift;

    my $index = shift;

    my $value = shift;

    my ($namespace,$key) = _key( $index );

    $self->{$namespace}->{$key} = $value;

}#STORE

# ------------------------------------------------------------------------------
# DELETE - Tie interface method
# ------------------------------------------------------------------------------

sub DELETE {

    my $self = shift;

    my $index = shift;

    my ($namespace,$key) = _key( $index );

    delete $self->{$namespace}->{$key};

}#DELETE

# ------------------------------------------------------------------------------
# CLEAR - Tie interface method
# ------------------------------------------------------------------------------

sub CLEAR {

    my $self = shift;

    my @reset = keys %{$self->{'public'}};

    map { delete $self->{'public'}->{$_} } keys %{$self->{'public'}};

}#CLEAR

# ------------------------------------------------------------------------------
# EXISTS - Tie interface method
# ------------------------------------------------------------------------------

sub EXISTS {

    my $self = shift;

    my $index = shift;

    my ($namespace,$key) = _key( $index );

    exists $self->{$namespace}->{$key};

}#EXISTS

# ------------------------------------------------------------------------------
# FIRSTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub FIRSTKEY {

    my $self = shift;

    my @reset = keys %{$self->{'public'}};

    each %{$self->{'public'}};

}#FIRSTKEY

# ------------------------------------------------------------------------------
# NEXTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub NEXTKEY {

    my $self = shift;

    my $lastindex = shift;

    each %{$self->{'public'}};

}#NEXTKEY

# ------------------------------------------------------------------------------
# SCALAR - Tie interface method
# ------------------------------------------------------------------------------

sub SCALAR {

    my $self = shift;

    scalar %{$self->{'public'}};

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
