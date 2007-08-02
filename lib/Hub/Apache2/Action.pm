package Hub::Apache2::Action;
use strict;

# mod_perl.so
use APR::OS ();
use Apache2::Access ();
use Apache2::RequestRec ();
use Apache2::Const qw(REDIRECT HTTP_MOVED_TEMPORARILY OK);

use CGI qw(:standard);
use Hub qw(:lib :webapp);

our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

# ------------------------------------------------------------------------------
# handler - Apache2 mode_perl invocation method
# ------------------------------------------------------------------------------

sub handler {
  return Hub::handle_apache_request(\&process_request, @_);
}#handler

# ------------------------------------------------------------------------------
# process_request - Apache2 mod_perl processor
# ------------------------------------------------------------------------------

sub process_request {
  return Hub::response_handler_callback(\&perform, @_);
}#process_request

# ------------------------------------------------------------------------------
# perform - Worker method for actions.
# ------------------------------------------------------------------------------

sub perform {
  my $r = shift;
  my $action = $$Hub{'/sys/request/page/name'};
  my $next = $$Hub{'/sys/ENV/HTTP_REFERER'};

  # Login
  if ($action eq 'Action-Login') {
    Hub::Apache2::AuthenSHA::login($r, $$Hub{'/cgi/username'},
      $$Hub{'/cgi/password'});
    if ($$Hub{'/user'}) {
      $next = Hub::bestof($$Hub{'/cgi/href'}, $next);
    } else {
      $next = Hub::bestof($$Hub{'/cgi/onfail'}, $next);
    }

  }

  # Logout
  if ($action eq 'Action-Logout') {
    Hub::Apache2::AuthenSHA::logout($r);
    $next = Hub::bestof($$Hub{'/cgi/href'}, $next);
  }

  # If the next page is simply a parameter string, such as '?failure=1', Set
  # the location to the referer plust those parameters.
  $next ||= $$Hub{'/sys/request/page/path'};
  if ($next =~ /^\?/) {
    if ($$Hub{'/sys/ENV/HTTP_REFERER'} =~ /\?/) {
      $next =~ s/^\?/&/;
    }
    $next = $$Hub{'/sys/ENV/HTTP_REFERER'} . $next;
  }

  # Redirect
  $r->headers_out->set(Location => $next);
  $r->status(HTTP_MOVED_TEMPORARILY);
  return HTTP_MOVED_TEMPORARILY;
}#perform

1;

__END__

=pod:summary Apache2 mod_perl action handler

=pod:synopsis

=pod:description

=cut
