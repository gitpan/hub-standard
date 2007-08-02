package Hub::Apache2::Config;
use strict;

# mod_perl.so
use APR::OS ();
use Apache2::Access ();
use Apache2::RequestRec ();

use CGI qw(:standard);
use Hub qw(:lib :webapp);

our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

# ------------------------------------------------------------------------------
# handler - Apache2 mode_perl invocation method
# ------------------------------------------------------------------------------

sub handler {
  my ($self, $params, $args) = @_;
}#handler

1;

__END__

=pod:summary Apache2 mod_perl config handler

=pod:synopsis

  <Perl handler="Hub::Apache2::Config >
  </Perl>

=pod:description

=pod:Environment variables

=head2 Notes

=cut
