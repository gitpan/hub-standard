package Hub::Data::HashData;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our ($VERSION,$AUTOLOAD);

# ------------------------------------------------------------------------------
# new
# new HASH
# 
# Constructor
# ------------------------------------------------------------------------------

sub new {

	my $self        = shift;
    my $data        = shift || {};

	my $classname   = ref( $self ) || $self;

    croak "Unexpected data: $data" unless ref($data) eq 'HASH';

	return bless $data, $classname;

}#new

# ------------------------------------------------------------------------------
# AUTOLOAD
# 
# Method handler
# ------------------------------------------------------------------------------

sub AUTOLOAD {

    my ($name) = $AUTOLOAD =~ /::([a-z]+)$/;

    if( $name =~ /^(has|query|get|take|init|set|append|merge|offer|dup)$/ ) {

        my $method = 'Hub::h' . $1 . 'v';

        my $self = shift;

        unshift @_, $self;

        goto &$method;

    } else {

        croak "Method does not exist: $name";

    }#if

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
