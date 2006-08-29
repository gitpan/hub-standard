package Hub::Knots::Object;

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
# _access - Direct access to members
# ------------------------------------------------------------------------------

sub _access {

    my $self = shift;

    my $index = shift;

    return $self->{$index};

}#_access

# ------------------------------------------------------------------------------
# _keyname - Determine which key (public or private) to use
# ------------------------------------------------------------------------------

sub _keyname {

    my $self = shift;

    my $index = shift;

    my $datakey = defined $index &&
        $$index =~ s/^(internal|public|private):// ? $1 : ();

    $datakey ||= caller(1) eq ref($self->{'internal'}{'impl'}) ? 'private' : 'public';

    return $datakey;

}#_keyname

# ------------------------------------------------------------------------------
# TIEHASH - Tie interface method
# ------------------------------------------------------------------------------

sub TIEHASH {

    my $self = shift;

    my $impl = shift;

    my $obj = bless {
    
        'internal'  => { impl => $impl }, # neither public or private
        'public'    => {},
        'private'   => {},
        
    }, $self;

    return $obj;

}#TIEHASH

# ------------------------------------------------------------------------------
# FETCH - Tie interface method
# ------------------------------------------------------------------------------

sub FETCH {

    my $self = shift;

    my $index = shift;

    my $datakey = $self->_keyname( \$index );

    return $index ? $self->{$datakey}->{$index} : $self->{$datakey};

}#FETCH

# ------------------------------------------------------------------------------
# STORE - Tie interface method
# ------------------------------------------------------------------------------

sub STORE {

    my $self = shift;

    my $index = shift;

    my $value = shift;

    my $datakey = $self->_keyname( \$index );

    $index ? $self->{$datakey}->{$index} = $value : $self->{$datakey} = $value;

}#STORE

# ------------------------------------------------------------------------------
# DELETE - Tie interface method
# ------------------------------------------------------------------------------

sub DELETE {

    my $self = shift;

    my $index = shift;

    my $datakey = $self->_keyname( \$index );

    delete $self->{$datakey}->{$index};

}#DELETE

# ------------------------------------------------------------------------------
# CLEAR - Tie interface method
# ------------------------------------------------------------------------------

sub CLEAR {

    my $self = shift;

    my $datakey = $self->_keyname();

    my @reset = keys %{$self->{$datakey}};

    map { delete $self->{$datakey}->{$_} } keys %{$self->{$datakey}};

}#CLEAR

# ------------------------------------------------------------------------------
# EXISTS - Tie interface method
# ------------------------------------------------------------------------------

sub EXISTS {

    my $self = shift;

    my $index = shift;

    my $datakey = $self->_keyname( \$index );

    exists $self->{$datakey}->{$index};

}#EXISTS

# ------------------------------------------------------------------------------
# FIRSTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub FIRSTKEY {

    my $self = shift;

    my $datakey = $self->_keyname();

    my @reset = keys %{$self->{$datakey}};

    each %{$self->{$datakey}};

}#FIRSTKEY

# ------------------------------------------------------------------------------
# NEXTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub NEXTKEY {

    my $self = shift;

    my $lastindex = shift;

    my $datakey = $self->_keyname();

    each %{$self->{$datakey}};

}#NEXTKEY

# ------------------------------------------------------------------------------
# SCALAR - Tie interface method
# ------------------------------------------------------------------------------

sub SCALAR {

    my $self = shift;

    my $datakey = $self->_keyname();

    scalar %{$self->{$datakey}};

}#SCALAR

# ------------------------------------------------------------------------------
# UNTIE - Tie interface method
# ------------------------------------------------------------------------------

sub UNTIE {

    my $self = shift;

    my $count = shift || 0;

    my $datakey = $self->_keyname();

}#UNTIE

# ------------------------------------------------------------------------------


'???';
