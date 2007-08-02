package Hub::Apache2::Handler;
use strict;

# mod_perl.so
use APR::OS ();
use Apache2::Access ();
use Apache2::RequestRec ();

# mod_apreq2.so
#eval<<__end_eval;
#use Apache2::Request ();
#use Apache2::Cookie ();
#use Apache2::Upload ();
#__end_eval
#$ENV{'USE_MOD_APREQ2'} = !$@;

use CGI qw(:standard);
use Hub qw(:lib :webapp);

our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
  handle_apache_request
  response_handler_callback
  /;

# Format apache log messages with timestamp
$SIG{__WARN__} = \&_sigwarn;
$SIG{__DIE__} = \&_sigdie;

# ------------------------------------------------------------------------------
# handle_apache_request - Apache2 mod_perl invokation wrapper
# ------------------------------------------------------------------------------

sub handle_apache_request {
  my $handler = shift;
  my $r = shift;
  # Change to working directory
  die "Environment variable 'WORKING_DIR' not set or invalid" unless
    defined $ENV{'WORKING_DIR'} && -d $ENV{'WORKING_DIR'};
  $ENV{'WORKING_DIR'} =~ s/\/$//;
  chdir $ENV{'WORKING_DIR'};
  # Process request
  return Hub::callback(\&_handle_request, $handler, $r);
}

# ------------------------------------------------------------------------------
# _handle_request - Worker method
# ------------------------------------------------------------------------------

sub _handle_request {
  my $handler = shift;
  my $r = shift;

  # Rescan disk for files changes
  Hub::frefresh();

  # Set the request data
  if (defined $r) {
    $r->no_cache(1);
    my $table = $r->headers_in;
    if (can($table, 'FIRSTKEY')) {
      foreach my $k (keys %$table) {
        $$Hub{"/sys/request/headers/$k"} = $table->get($k);
      }
    }
  }

  # Get SID from Cookie
  my $session_id = ();
  if ($$Hub{'/sys/request/headers/Cookie'}) {
    my $pattern = Hub::COOKIE_SID . '=([0-9]+)';
    ($session_id) = $$Hub{'/sys/request/headers/Cookie'} =~ /$pattern/;
  }

  # Apache Session
  if ($$Hub{'/conf/session/enable'}) {
    $$Hub{'/session'} = mkinst('Session', $session_id);
  } else {
    $$Hub{'/session'} = {}; # Not a persistent session
  }

  # Process request
  my $result = &$handler($r);

  # Save session
  $$Hub{'/session'}->save() if can($$Hub{'/session'}, 'save');

  return $result;

}#_handle_request

# ------------------------------------------------------------------------------
# response_handler_callback - Environment wrapper for response handlers
# response_handler_callback \&subroutine, $r
# ------------------------------------------------------------------------------

sub response_handler_callback {
  my $handler = shift;
  my $r = shift;
  my $time1 = [gettimeofday];

  my $page_path = Hub::getaddr($ENV{'SCRIPT_FILENAME'});
  $$Hub{'/sys/request/page/url'} = $ENV{'SCRIPT_NAME'};
  $$Hub{'/sys/request/page/name'} = Hub::getname($page_path);
  $$Hub{'/sys/request/page/path'} = Hub::getpath($page_path);
  $$Hub{'/sys/request/page/ext'} = Hub::getext($page_path);

  # Set this beore action URL's execute (so they may change it)
  $$Hub{'/sys/response/template'} = $page_path;

  # Parse CGI parameters into '/cgi' namespace
  my %req_opts = (
    POST_MAX => 50000000,
    TEMP_DIR => '/tmp',
  );

  Hub::merge(\%req_opts, $$Hub{'/conf/request'}, -overwrite)
      if isa($$Hub{'/conf/request'}, 'HASH');
  $$Hub{'/sys/CGI'} = $$Hub{'/sys/ENV/USE_MOD_APREQ2'}
    ? Apache2::Request->new($r, %req_opts)
    : CGI->new();

  $$Hub{'/cgi'} = {};
  foreach my $key (Hub::keydepth_sort($$Hub{'/sys/CGI'}->param())) {
    next unless $key;
    my @value = $$Hub{'/sys/CGI'}->param($key);
    warn "param ", $key, "=", join("\n", @value), "\n"
        if ($$Hub{'/sys/ENV/DEBUG'});
    $$Hub{Hub::fixpath("/cgi/$key")} = @value > 1 ? \@value : pop @value;
  }

  # Execute action URL's
  if (defined $$Hub{'/cgi/action'}) {
    my $actions = $$Hub{'/cgi/action'};
    $actions = isa($actions, 'ARRAY') ? $actions : [$actions];
    foreach my $filename (@$actions) {
      unless ($$Hub{$filename}) {
        warn "Cannot find action module: $filename";
        next;
      }
      my $retval = Hub::modexec(-filename => $filename);
    }
  }

  # Create /user if authenticated
  Hub::Apache2::AuthenSHA::authenticate();

  # Callback to the response handler
  my $time2 = [gettimeofday];
  my $result = &$handler($r);

  # Dump performance statistics
  my $time3 = [gettimeofday];
  if ($$Hub{'/sys/ENV/DEBUG'}) {
    warn Hub::fw(20, Hub::getname($$Hub{'/sys/ENV/SCRIPT_NAME'})) . " "
      . " total=" . Hub::fw(8,tv_interval($time1, $time3))
      . " parse=" . Hub::fw(8,tv_interval($time2, $time3))
      . " setup=" . Hub::fw(8,tv_interval($time1, $time2))
      . " path="  . $$Hub{'/sys/ENV/SCRIPT_NAME'}
      . "\n";
  }

  return $result;
}#response_handler_callback

# ------------------------------------------------------------------------------
# _sigwarn - Warning handler
# ------------------------------------------------------------------------------

sub _sigwarn {
  my @caller = caller(0);
  my $tid = APR::OS::current_thread_id();
  print STDERR '[', Hub::datetime(-apache), "] [warning] [$$:$tid] ", @_
    if @caller && $caller[2] > 0;
  if ($ENV{'DEBUG'} && $ENV{'DEBUG'} > 1) {
    for my $i (0 .. 8) {
      my @caller = caller($i);
      last unless @caller;
      last if $caller[2] == 0;
      print STDERR Hub::fw(27), "[stack-$i] $caller[0] line $caller[2]\n";
    }
  }
}#_sigwarn

# ------------------------------------------------------------------------------
# _sigdie - Die handler (fatals to browser)
# ------------------------------------------------------------------------------

sub _sigdie {
# if ($ENV{'DEBUG'}) {
#   print STDOUT @_;
# } else {
#   print "An error occured\n";
# }
  die '[', Hub::datetime(-apache), "] [fatal] ", @_;
}#_sigdie

1;

__END__

=pod:summary Apache2 mod_perl response handler base class

=pod:synopsis

  sub handler {
  }

  sub process_request {
    my $r = shift;
    ...
    return Apach2::Const::OK;
  }

=pod:description

B<The working directory of the web site must be set.> We will change to and run
in this directory.  This is also the reflected directory which limits the
request's scope.

This base class parses the request's headers, cgi parameters, and initiales
the user's session (if it can).

=pod:Environment variables

=head2 WORKING_DIR

The working directory is just that.  Since multiple threads (hence multiple
sites) share this interpreter, a change to this directy is issued on each
request.

      PerlSetEnv WORKING_DIR "/var/www/html"

=head2 CONF_FILE

By default configuration is read from a file named C<.conf> in your working
directory.  To use a different one, specify it here.  It must reside beneath
your working directory, and this path is relative to the working directory.
For example:

      PerlSetEnv CONF_FILE "/conf/custom.conf"

would resolve to:

      $WORKING_DIR/conf/custom.conf

=head2 DEBUG

To generate debug messages (written to stderr), set this to a true value.

      # Basic debugging
      PerlSetEnv DEBUG 1

      # More debugging info (includes stack traces)
      PerlSetEnv DEBUG 2

=cut
