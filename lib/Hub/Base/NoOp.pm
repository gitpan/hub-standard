package Hub::Base::NoOp;

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

sub new {

	my $self = shift;
	my $class = ref( $self ) || $self;
    my $objkey = shift;

	return bless { objkey => $objkey }, $class;

}#new

sub AUTOLOAD {

    my $self = shift;
    my ($pkg,$func) = ($AUTOLOAD =~ /(.*)::([^:]+)$/);

    unless( $self->{'objkey'} eq 'logger' ) {
        my $msg = "Call to undefined object ($self->{'objkey'})->$func";
        Hub::lwarn( $msg );
        confess $msg;
    }#unless

    undef;
    
}#AUTOLOAD

sub DESTROY {

    # Defining this function prevents it from being searched in AUTOLOAD

}#DESTROY



'???';
