package Hub::Webapp::Response;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
    respond
/;

# ------------------------------------------------------------------------------
# respond - Print response to STDOUT
# ------------------------------------------------------------------------------

sub respond {

  # Request object
  my $reqrec = shift;

  # Munge /cgi data to protect from XSS attacks
  foreach my $k (keys %{$$Hub{'/cgi'}}) {
  }

  # Merge templates with values
  my $contents = '';
  my $response_template = Hub::getaddr($$Hub{'/sys/response/template'});
  return unless defined $response_template;
  my $file = $$Hub{$response_template};
  if (can($file, 'get_content')) {
    $contents = $file->get_content();
  }
  my $parser = Hub::mkinst('HtmlParser', -template => \$contents);
  my $output = $parser->populate($Hub) || '';

  # Glean headers from registry
  my $headers = {};
  my $rh = $$Hub{'/sys/response/headers'};
  if (isa($rh, 'ARRAY')) {
    for (@$rh) {
      my ($k, $v) = /([^:]+)\s*:\s*(.*)/;
      $headers->{lc($k)} = $v;
    }
  }

  # Parse headers from output
  my $crown = substr($$output, 0, 500);
  my $crop = 0;
  for (split /[\r\n]+/, $crown) {
    my @fields = /^([a-z\-_]+)\s*:\s*(.*)/i;
    if (@fields) {
      $headers->{lc($fields[0])} = $fields[1];
      $crop = Hub::indexmatch($crown, '[\r\n]+', $crop, -after);
      $crop = length($crown) if $crop < 0;
    } else {
      last;
    }
  }

  # Oputput headers
  unless ($$headers{'content-type'}) {
    my ($encoding,$type,$header) =
      _get_content_headers(Hub::getext($response_template));
    $headers->{'content-type'} = $type;
  }
  my $output_headers = '';
  for (keys %$headers) {
    /content-type/ and next;
    $output_headers .= ucfirst($_) . ": $$headers{$_}\n"
  }
  $output_headers .= "Content-Type: $$headers{'content-type'}\n\n";

  # Send output
  if (can($reqrec, 'print')) {
    $output_headers and $reqrec->print($output_headers);
    $reqrec->print($crop > 0 ? substr($$output, $crop) : $$output);
  } else {
    $output_headers and print STDOUT $output_headers;
    print STDOUT $crop > 0 ? substr($$output, $crop) : $$output;
  }

#
# # Echo the response to file (debugging headers)
# if ($$Hub{'/sys/ENV/DEBUG'}) {
#   if (defined $$Hub{'/session'}) {
#     my $dir = $$Hub{'/session/directory'};
#     if (-d $dir) {
#       my $fn = $dir . '/' . Hub::getname($response_template);
#       Hub::writefile($fn, $output_headers . $$output);
#     }
#   }
# }
#

}

# ------------------------------------------------------------------------------
# _get_content_headers - Standard HTTP headers by file extension
# _get_content_headers $ext
# Return an array of headers ($content_encoding, $content_type, [other..])
# ------------------------------------------------------------------------------

sub _get_content_headers {
  my $ext = lc(shift) || '';
  # Create the map
  $$Hub{"/conf/content_types"} ||= {
    htm => {
      type => 'text/html',
    },
    html => {
      type => 'text/html',
    },
    js => {
      type => 'text/javascript',
    },
    css => {
      type => 'text/css',
    },
    txt => {
      type => 'text/plain',
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
