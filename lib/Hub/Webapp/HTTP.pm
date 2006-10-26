package Hub::Webapp::HTTP;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;
use Hub qw/:lib/;
use Net::HTTP;
use LWP::UserAgent;

our $VERSION    = '3.01048';
our @EXPORT     = qw//;
our @EXPORT_OK  = qw/

    httpget
    http

/;

# ------------------------------------------------------------------------------
# http - HTTP Transmit and respond
# http $uri, $content, [option]
#
# options:
#
#   -cookie_jar=$cookie_jar         Implements HTTP::Cookies
#   -raw                            Return the raw HTTP::Response object
# 
#   -method=GET|POST                HTTP Method
#   -agent=$string                  User agent identifier
#   -content_type=$string           Content type
#
# ------------------------------------------------------------------------------

sub http {

    my ($opts,$uri,$content) = Hub::opts(\@_, {
        method          => 'GET',
        content_type    => 'application/x-www-form-urlencoded',
        agent           => 'Mozilla/5.0',
    } );
    my ($prot,$host,$path) = _uri_split( $uri );

    # Create agent
    my $ua = LWP::UserAgent->new;
    $ua->agent( $$opts{'agent'} );

    # Create a request
    my $req = HTTP::Request->new($$opts{'method'} => $uri);
    $req->content_type($$opts{'content_type'});
    $req->content($content);
    if( $$opts{'cookie_jar'} ) {
        $$opts{'cookie_jar'}->add_cookie_header( $req );
    }

    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);
    if( $$opts{'cookie_jar'} ) {
        $$opts{'cookie_jar'}->extract_cookies( $res );
    }

    # Return the response, or a brief hash
    return $$opts{'raw'} ? $res : {
        body    => $res->content(),
        code    => $res->code(),
        status  => $res->message(),
        headers => $res->headers(),
    };

}#http

# ------------------------------------------------------------------------------
# httpget - HTTP Get
# ------------------------------------------------------------------------------

sub httpget {

    my ($opts,$uri) = Hub::opts(\@_);
    my ($prot,$host,$get) = _uri_split( $uri );
    my %resp = ();

    my $conn = Net::HTTP->new( PeerAddr => $host,
        Proto => $prot ) || die $@;

    $conn->write_request( GET => $get, 'User-Agent' => "Mozilla/5.0" );
        ($resp{'code'}, $resp{'status'}, %{$resp{'headers'}}) =

    $conn->read_response_headers;

    while( 1 ) {
        my $buf;
        my $n = $conn->read_entity_body($buf, 1024);
        die "read failed: $!" unless defined $n;
        last unless $n;
        $resp{'body'} .= $buf;
    }#while

    return \%resp;

}#httpget

# ------------------------------------------------------------------------------
# _uri_split - Obtain pieces of URI information
# ------------------------------------------------------------------------------

sub _uri_split {
  my $prot = "http";
  my $spec = shift;
  my $host = "";
  $spec =~ '://' and ($prot,$spec) = split '://', $spec;
  my @get = split '/', $spec;
  $host = shift @get;
  my $get = '/' . join( '/', @get );
  return( $prot, $host, $get );
}#_uri_split

#-------------------------------------------------------------------------------
 1;

__END__

=pod:summary HTTP Connection Wrapper

=pod:synopsis

    use Hub qw(:standard);
    callback( &main );
    sub main {
        my $resp = httpget('http://my.server.ip');
        print $$resp{'body'};
    }

=pod:description

=cut

'???';
