package Hub::Apache2::AuthenSHA;
use strict;
use Apache2::Access ();
use Apache2::RequestRec ();
use Digest::SHA1;
use Hub qw(:lib);

our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

use Apache2::Const qw(OK DECLINED HTTP_UNAUTHORIZED);

sub handler {
  return Hub::handle_apache_request(\&process_request, @_);
}

sub process_request {
  my $r = shift;
  my ($status, $password) = $r->get_basic_auth_pw;
  $status = validate_session(-reset_tstamp);
  if ($status == OK) {
    if (defined $password && !$$Hub{'/session/credentials/username'}) {
      $$Hub{'/session/credentials/username'} = $r->user;
      $$Hub{'/session/credentials/password'} = Digest::SHA1::sha1_hex($password);
    }
    authenticate();
  }
  if ($$Hub{'/user'}) {
    return OK
  } else {
    $r->note_auth_failure;
    return HTTP_UNAUTHORIZED;
  }
}

sub validate_session {
  my ($opts, @params) = Hub::opts(\@_);
  if ($$Hub{'/session/credentials/auth_tstamp'}) {
    my $timeout = $$Hub{'/conf/authorization/timeout'};
    $timeout = 0 unless defined $timeout;
    my $delta = $timeout - (time - $$Hub{'/session/credentials/auth_tstamp'});
    if ($delta < 0) {
      if ($$opts{'reset_tstamp'}) {
        $$Hub{'/session/credentials/auth_tstamp'} = time;
      }
      delete $$Hub{'/session/credentials/password'};
      delete $$Hub{'/session/credentials/username'};
      return HTTP_UNAUTHORIZED;
    }
  }
  return OK
}

sub authenticate {
  delete $$Hub{'/user'};
  validate_session();
  my $users_key = $$Hub{'/conf/authorization/users'} || '/users';
  my $password_key = $$Hub{'/conf/authorization/password_key'} || 'password.sha1';
  if ($users_key && $$Hub{'/session/credentials/username'}) {
    my $username = $$Hub{'/session/credentials/username'};
    my $account = $$Hub{"$users_key/$username"};
#warn "credentials:\n" . Hub::hprint($$Hub{'/session/credentials'});
#warn "key: " . "$users_key/$username/$password_key\n";
#warn "stored pw: " . Hub::resolve($$Hub{"$users_key/$username/$password_key"}), "\n";
    if ($account &&
        ($$Hub{'/session/credentials/password'} eq
          Hub::resolve($$Hub{"$users_key/$username/$password_key"}))) {
      $$Hub{'/user'} = $account;
      $$Hub{'/session/credentials/auth_tstamp'} = time;
    } else {
      warn "Authentication failed, credentials were:\n"
        . Hub::hprint($$Hub{'/session/credentials'});
      delete $$Hub{'/session/credentials/password'};
      delete $$Hub{'/session/credentials/username'};
    }
  }
#warn "Saving Session (auth)\n" . Hub::hprint($$Hub{'/session'});
  $$Hub{'/session'}->save() if can($$Hub{'/session'}, 'save');
}

sub login {
  my $r = shift;
  $r->set_basic_credentials(@_);
  $$Hub{'/session/credentials/auth_tstamp'} = time;
  $$Hub{'/session/credentials/username'} = $_[0];
  $$Hub{'/session/credentials/password'} = Digest::SHA1::sha1_hex($_[1]);
  authenticate();
}

sub logout {
  my $r = shift;
  if ($r->auth_type()) {
    $r->set_basic_credentials('', '');
    $r->note_auth_failure;
  }
  $$Hub{'/session/credentials/auth_tstamp'} = -1;
  delete $$Hub{'/session/credentials/password'};
  delete $$Hub{'/session/credentials/username'};
  delete $$Hub{'/user'};
}

1;

__END__

=pod:summary Apache2 mod_perl SHA authorization

=pod:synopsis

  PerlSetEnv WORKING_DIR "/var/www/html/sample"
  PerlAuthenHandler Hub::Apache2::AuthenSHA
  AuthType Basic
  AuthName "The Gate"
  Require valid-user

=pod:description

=pod:Environment variables

=cut
