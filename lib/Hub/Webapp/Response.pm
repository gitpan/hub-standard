package Hub::Webapp::Response;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/

    respond

/;

# ------------------------------------------------------------------------------
# respond - Print response to STDOUT
# ------------------------------------------------------------------------------

sub respond {

    my $opts = {};

    Hub::opts( \@_, $opts );

    #
    # Validate response template
    #

    my $response_template = Hub::spath( $$Hub{'/sys/response/template'} );

    unless( $response_template ) {

        Hub::lerr( "Response template not found: " . $$Hub{'/sys/response/template'} );

        $response_template = Hub::spath('index.html');

    }#unless

    #
    # Print headers
    #

    my ($encoding,$type,$header) = _get_headers( Hub::getext( $response_template ) );

    my $headers = $$Hub{'/sys/response/headers'} || [];

    unshift @$headers, $Hub->session->getclientcookie();

    push @$headers, "Content-type: $type\n\n";

    map { $_ and print $_ =~ /\n$/ ? $_ : "$_\n" } @$headers;

    #
    # Merge templates with values
    #

    my $contents = Hub::readfile( $response_template );

    my $parser = Hub::mkinst( 'Parser', -template => \$contents );

    my $output = $parser->populate( $$Hub{'/'} );

    _set_script( $output );

    Hub::polish( $output );

    #
    # Send output
    #

    Hub::lmsg( "Printing (length=" . length($$output) . ")", "info" );

    print $$output;

}#respond

# ------------------------------------------------------------------------------
# _get_headers EXT
#
# Return an array where $_[0] = encoding and $_[1] = type
# ------------------------------------------------------------------------------

sub _get_headers {

    my $ext = lc( shift );

    my $content_types = $$Hub{"/sys/content_types/$ext"} || {};

    my $e = $content_types->{'encoding'}    || "";
    my $t = $content_types->{'type'}        || "";
    my $h = $content_types->{'header'}      || "";

    return ($e,$t,$h);

}#_get_headers

#-------------------------------------------------------------------------------
# _set_script - Replace all of the <#SCRIPT> placeholders
#
# Replace all of the <#SCRIPT> placeholders with the url to this script.
# It is important that each link to the server contains the _display=
# parameter so that those requests know what page/module they are on.
#-------------------------------------------------------------------------------
sub _set_script {

    my $response = shift;

    while( $$response =~ /<#SCRIPT([^>]*)>\??([^'"]*)/ ) {

        my $subreq  = Hub::CGISIG_SUBREQ() . "=" . $1;

        my $params  = $2;

        my $url     = $Hub->session->mkurl( "$subreq;$params" );

        $$response =~ s/<#SCRIPT[^>]*>[^'"]*/$url/;

    }#while

}#_set_script

#-------------------------------------------------------------------------------
 1;

__END__

=pod:summary Response functions

=pod:synopsis

    use Hub qw(:standard);
    callback( &main );
    sub main {
        respond();
    }

=pod:description

This class provides one method 'respond' which gleans all its information for
the runtime symbol table $Hub.

=cut

'???';
