package Hub::Data::Nest;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our $AUTOLOAD   = '';
our $VERSION    = '3.01048';
our @EXPORT     = qw//;
our @EXPORT_OK  = qw//;

# ------------------------------------------------------------------------------
# new - Constructor.
# ------------------------------------------------------------------------------

sub new {
    my $self = shift;
    my $class = ref( $self ) || $self;
    my $obj = bless {}, $class;
    tie %$obj, 'Hub::Knots::TiedObject', 'Hub::Knots::Addressable';
    Hub::merge( $$obj{'/'}, $_ ) for @_;
    return $obj;
}#new

# ------------------------------------------------------------------------------
# AUTOLOAD - Proxy for data handler methods
#
#   get         # fetch
#   set         # store
#   append      # special store
#   take        # delete
# ------------------------------------------------------------------------------

sub AUTOLOAD {
    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";
    my ($method) = $AUTOLOAD =~ /::([a-z]+)$/;
    my $action = 'Hub::h' . $method . 'v';
    unshift @_, $self->{'*tied'};
    goto &$action;
}#AUTOLOAD

# ------------------------------------------------------------------------------
# DESTROY
# 
# Defining this function prevents it from being searched in AUTOLOAD
# ------------------------------------------------------------------------------

sub DESTROY {
}#DESTROY

# ------------------------------------------------------------------------------

'???';
