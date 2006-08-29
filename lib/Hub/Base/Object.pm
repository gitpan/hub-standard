package Hub::Base::Object;

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
# new - Constructor.
#
# new LIST
#
# Parameters are passed to the standard initialization method L<refresh>.
# ------------------------------------------------------------------------------

sub new {

    my $self = shift;

    my $class = ref( $self ) || $self;

    my $obj = bless {}, $self;

    my $tied = tie %$obj, 'Hub::Knots::Object', $obj;

    $obj->{'internal:tied'} = $tied;

    $obj->refresh( @_ );

    return $obj;

}#new

# ------------------------------------------------------------------------------
# daccess - Direct access to member hashes
#
# daccess KEYNAME
#
# KEYNAME:
#
#   'public'        Public hash
#   'private'       Private hash
#   'internal'      Internal hash (used to tie things together)
# ------------------------------------------------------------------------------

sub daccess {

    my ($self,$opts) = Hub::objopts( \@_ );

    $self->{'internal:tied'}->_access( @_ );

}#daccess

# ------------------------------------------------------------------------------
# refresh - Return instance to initial state.
#
# refresh LIST
#
# Interface method, override in your derived class.  Nothing is done in this
# base class.
#
# Called implictly by L<new>, and when persistent interpreters (such as
# mod_perl) would have called L<new>.
# ------------------------------------------------------------------------------

sub refresh {

    my ($self,$opts) = Hub::objopts( \@_ );

}#refresh

# ------------------------------------------------------------------------------


'???';
