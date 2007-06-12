package Hub::Apache2::Render;
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

our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw/@REQUEST_HEADERS/;

our @REQUEST_HEADERS = (
  'Accept',               # Lists acceptable media types for the server to 
                          # present in response
  'Accept-Charset',       # Lists character sets the client will accept
  'Accept-Encoding',      # Lists encodings the client will accept
  'Accept-Language',      # Lists languages the client is most interested in
  'Authorization',        # A series of authorization fields
  'Cache-Control',        # Behavior intended to prevent caches from adversely 
                          # interfering with the request or response
  'Cookie',               # Decribes a client cookie
  'Host',                 # Name of the requested host server
  'If-Match',             # The entity tag of the client's cached version of 
                          # the requested resource
  'If-Modified-Since',    # An HTTP-formatted date for the server to use in 
                          # resource comparisons
  'If-None-Match',        # A list of entity tags representing the client's 
                          # possible cached resources
  'If-Unmodified-Since',  # An HTTP-formatted date for the server to use in 
                          # resource comparisons
  'Referer',              # An absolute or partial URI of the resource from 
                          # which the current request was obtained
  'User-Agent',           # A string identifying the client software
);

# Format apache log messages with timestamp
$SIG{__WARN__} = \&_sigwarn;
$SIG{__DIE__} = \&_sigdie;

# ------------------------------------------------------------------------------
# handler - Apache2 mod_perl invokation method
# ------------------------------------------------------------------------------

sub handler {
  my $reqrec = shift;
  # Change to working directory
  die "Environment variable 'WORKING_DIR' not set or invalid" unless
    defined $ENV{'WORKING_DIR'} && -d $ENV{'WORKING_DIR'};
  $ENV{'WORKING_DIR'} =~ s/\W$//;
  chdir $ENV{'WORKING_DIR'};
  # Process request
  return Hub::callback(\&process_request, $reqrec);
}

# ------------------------------------------------------------------------------
# process_request - Worker method
# ------------------------------------------------------------------------------

sub process_request {
  my $reqrec = shift;
  my $time1 = [gettimeofday];

  # Set the request data
  if (defined $reqrec) {
    my $table = $reqrec->headers_in;
    if (can($table, 'FIRSTKEY')) {
      foreach my $k (keys %$table) {
        $$Hub{"/sys/request/headers/$k"} = $table->get($k);
      }
    }
  }
  $$Hub{'/sys/request/page/url'} = $ENV{'SCRIPT_NAME'};
  $$Hub{'/sys/request/page/name'} = Hub::getname($ENV{'SCRIPT_NAME'});
  $$Hub{'/sys/request/page/path'} = Hub::getpath($ENV{'SCRIPT_NAME'});
  $$Hub{'/sys/request/page/ext'} = Hub::getext($ENV{'SCRIPT_NAME'});

  # Rescan disk for files changes
  Hub::frefresh();

  # Parse CGI parameters into '/cgi' namespace
  my %req_opts = (
    POST_MAX => 50000000,
    TEMP_DIR => '/tmp',
  );
  Hub::merge(\%req_opts, $$Hub{'/conf/request'}, -overwrite)
      if isa($$Hub{'/conf/request'}, 'HASH');
  $$Hub{'/sys/CGI'} = $$Hub{'/sys/ENV/USE_MOD_APREQ2'}
    ? Apache2::Request->new($reqrec, %req_opts)
    : CGI->new();
  $$Hub{'/cgi'} = {};
  foreach my $key ($$Hub{'/sys/CGI'}->param()) {
    next unless $key;
    my @value = $$Hub{'/sys/CGI'}->param($key);
    warn "param ", $key, "=", join("\n", @value), "\n"
        if ($$Hub{'/sys/ENV/DEBUG'});
    $$Hub{Hub::fixpath("/cgi/$key")} = @value > 1 ? \@value : pop @value;
  }

  # Set this beore action URL's execute (so they may change it)
  $$Hub{'/sys/response/template'} = $ENV{'SCRIPT_FILENAME'};

  # Execute action URL's
  if (defined $$Hub{'/cgi/action'}) {
    # TODO if two action= parameters are passed in, /cgi/action will 
    # be an array.  we should execute each action
    my $filename = $$Hub{'/cgi/action'};
    die "Cannot find parser: $filename", unless $$Hub{$filename};
    my $retval = Hub::modexec(-filename => $filename);
  }

  # Parse and print the requested file
  my $time2 = [gettimeofday];
  Hub::respond();

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

  return $Apache2::Const::OK;

}#process_request

# ------------------------------------------------------------------------------
# mimic - For invoking this handler from the command-line
# mimic $script, $cgi_parameters
# mimic $script
# For debugging, you may mimic a web request by:
#
#   cd $WORKING_DIR
#   perl -MHub -e "Hub::Apache2::Render::mimic()" index.html
# ------------------------------------------------------------------------------

sub mimic {
  croak "Provide a script" unless @ARGV;
  $ENV{'WORKING_DIR'} ||= cwd();
  $ENV{'SCRIPT_NAME'} ||= Hub::fixpath('/' . shift @ARGV);
  $ENV{'SCRIPT_FILENAME'} ||= $ENV{'WORKING_DIR'} . $ENV{'SCRIPT_NAME'};
  $ENV{'GLOBAL_EXCLUDE'} ||= '.svn';
  # When invoked as an Apache2 handler, mod_apreq2 is loaded with a LoadModule
  # directive.  But the install does not place this mode in the perl source
  # tree, meaning that I get a symbol lookup error when trying to mimic a request
  # from the command-line.
  $ENV{'USE_MOD_APREQ2'} = 0;
  return handler();
}#mimic

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
  print STDOUT "Content-Type: text/plain\n\n";
  if ($ENV{'DEBUG'}) {
    print STDOUT @_;
  } else {
    print "An error occured\n";
  }
  die '[', Hub::datetime(-apache), "] [fatal] ", @_;
}#_sigdie

1;

__END__

=pod:summary Apache2 mod_perl response handler for HTML pages

=pod:synopsis

  <LocationMatch "/sample.*\.(html?|css|js)$">
    <IfModule mod_perl.c>
      Options +ExecCGI
      SetHandler perl-script
      PerlOptions +ParseHeaders
      PerlResponseHandler Hub::Apache2::Render
      PerlSetEnv WORKING_DIR "/var/www/html"
  #   PerlSetEnv DEBUG "1"
  #   PerlSetEnv CONF_FILE "custom.conf"
    </IfModule>
  </LocationMatch>

=pod:description

B<The working directory of the web site must be set.> We will change to and run
in this directory.  This is also the reflected directory which limits the
request's scope.

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

      PerlSetEnv DEBUG "1"

=cut
