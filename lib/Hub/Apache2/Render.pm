package Hub::Apache2::Render;
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
  return Hub::handle_apache_request(\&process_request, @_);
}#handler

# ------------------------------------------------------------------------------
# process_request - Apache2 mod_perl processor
# ------------------------------------------------------------------------------

sub process_request {
  return Hub::response_handler_callback(\&render, @_);
}#process_request

# ------------------------------------------------------------------------------
# render - Worker method
# ------------------------------------------------------------------------------

sub render {
  my $r = shift;
  $$Hub{'/sys/response/template'} =
      Hub::srcpath($$Hub{'/sys/response/template'});
  Hub::respond($r);
  return $Apache2::Const::OK;
}#render

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

=head2 Notes

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

=cut
