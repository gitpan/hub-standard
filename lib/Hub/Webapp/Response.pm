package Hub::Webapp::Response;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
    respond
/;

# ------------------------------------------------------------------------------
# respond - Print response to STDOUT
# ------------------------------------------------------------------------------

sub respond {

  # Validate response template
  my $response_template =
    Hub::bestof(Hub::srcpath($$Hub{'/sys/response/template'}), '');
  unless($response_template) {
    warn "Response template not found: $$Hub{'/sys/response/template'}";
    my $ext = Hub::getext($$Hub{'/sys/response/template'}) || '';
    $response_template = Hub::bestof(
      $$Hub{"/conf/not_found/$ext"},
      $$Hub{"/conf/not_found/other"}
    );
    unless (-e $response_template) {
      warn "Cannot locate not_found document";
      return;
    }
  }

  # Merge templates with values
  my $contents = Hub::readfile($response_template);
  my $parser = Hub::mkinst('HtmlParser', -template => \$contents);
  my $output = $parser->populate($Hub);

  # Print headers
  my $headers = $$Hub{'/sys/response/headers'} || [];
  unless (substr($$output, 0, 500) =~ /Content-Type:/i) {
    my ($encoding,$type,$header) =
      _get_headers(Hub::getext($response_template));
    push @$headers, "Content-type: $type\n\n";
  }
  map { $_ and print $_ =~ /\n$/ ? $_ : "$_\n" } @$headers;

  # Send output
  print $$output if defined $output;

}

# ------------------------------------------------------------------------------
# _get_headers - Standard HTTP headers by file extension
# _get_headers $ext
# Return an array of headers ($content_encoding, $content_type, [other..])
# ------------------------------------------------------------------------------

sub _get_headers {
  my $ext = lc(shift) || '';
  # Create the map
  $$Hub{"/conf/content_types"} ||= {
    htm => {
      type => 'text/html',
    },
    js => {
      type => 'text/javascript',
    },
    css => {
      type => 'text/css',
    },
    html => {
      type => 'text/html',
    },
  };
  # Lookup by file extension
  my $content_types = $$Hub{"/conf/content_types/$ext"} || {};
  my $e = $content_types->{'encoding'} || "";
  my $t = $content_types->{'type'} || "text/html";
  my $h = $content_types->{'header'} || "";
  return ($e,$t,$h);
}

#-------------------------------------------------------------------------------
 1;

__END__

=pod:summary Response functions

=pod:synopsis

  use Hub qw(:standard :webapp);
  callback(&main);
  sub main {
    respond("index.html");
  }

=pod:description

This class provides one method 'respond' which populates the response template
with values from the registry.

=cut
