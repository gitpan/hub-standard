package Hub::Webapp::CGI;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2

use CGI qw/:standard/;
use Hub qw/:lib/;

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/process_request process_fcgi_request/;

$CGI::POST_MAX=1024 * 50000; # 50MB
#$CGI::DISABLE_UPLOADS = 1;

#-------------------------------------------------------------------------------
sub _wrapcallback {

    my $sub = shift;

    Hub::filescan(); # Rescan disk for missing/added files

    Hub::frefresh(); # Rescan disk for modified files

    $Hub->mkobj( 'session', 'Client' );

    $Hub->session->newreq();

    unless( defined &$sub ) {

        Hub::lflush();

        croak "$0: Callback subroutine ($sub) not defined";

    }#unless

    my $ret = &$sub( @_ );

    croak $@ if $@;

    $Hub->session->endreq();

}#_wrapcallback

#-------------------------------------------------------------------------------
sub process_request {

    my $sub = shift;

    Hub::callback( \&_wrapcallback, $sub );

}#process_request

#-------------------------------------------------------------------------------
sub process_fcgi_request {

    my $sub = shift;

    require CGI::Fast;

    while( my $fcgi = $Hub->mkobj( 'Cgi', 'CGI::Fast' ) ) {

        process_request( $sub );

        $Hub->rmobj('Cgi'); # Reset (FCGI logic)

        # Autorestart script if modified
        exit if -M $ENV{'SCRIPT_FILENAME'} < 0;

    }#while

}#process_fcgi_request

#-------------------------------------------------------------------------------
return 1;

'???';
