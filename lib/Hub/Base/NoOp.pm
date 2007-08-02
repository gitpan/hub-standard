package Hub::Base::NoOp;
use strict;
use Hub qw/:lib/;
our ($AUTOLOAD);
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

# ------------------------------------------------------------------------------
# new - Constructor
# ------------------------------------------------------------------------------

sub new {
	my $self = shift;
	my $class = ref( $self ) || $self;
  my $objkey = shift;
	return bless { objkey => $objkey }, $class;
}#new

# ------------------------------------------------------------------------------
# AUTOLOAD - Dump error message
# ------------------------------------------------------------------------------

sub AUTOLOAD {
  my $self = shift;
  my ($pkg,$func) = ($AUTOLOAD =~ /(.*)::([^:]+)$/);
  unless( $self->{'objkey'} eq 'logger' ) {
    my $msg = "Call to undefined object ($self->{'objkey'})->$func";
    confess $msg;
  }#unless
  undef;
}#AUTOLOAD

# ------------------------------------------------------------------------------
# DESTROY - Defining this function prevents it from being searched in AUTOLOAD
# ------------------------------------------------------------------------------

sub DESTROY {
}#DESTROY

1;
