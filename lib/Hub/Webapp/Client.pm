package Hub::Webapp::Client;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use CGI;
use File::stat;
use Hub qw/:lib/;

our ($AUTOLOAD);

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/

    REQHISTORYSIZE      DEFAULTHANDLER  COOKIENAME          SESSIONACTIVEDIR
    SESSIONCACHEDIR     KEYSOURCE_SHELL KEYSOURCE_COOKIE    KEYSOURCE_NEW
    CGISIG_HANDLER      CGISIG_REFERRER CGISIG_KEEPDATA     CGISIG_REQTYPE
    CGISIG_CLIENTKEY    CGISIG_IGNORE   CGISIG_DISPLAY      CGISIG_ACTION
    CGISIG_SRCPAGE      CGISIG_REQPAGE  CGISIG_REQPARAMS    REQTYPE_ACTION
    REQTYPE_DISPLAY     CGISIG_SUBREQ   CGISIG_POMRESPONSE/,

our %EXPORT_TAGS    = ( 'CONST' => [@EXPORT_OK] );

use constant {

    REQHISTORYSIZE      => 5,
    DEFAULTHANDLER      => "index",
    COOKIENAME          => "SESSION_ID",
    SESSIONACTIVEDIR    => "ACTIVE",
    SESSIONCACHEDIR     => "CACHE",
    KEYSOURCE_SHELL     => "shell access",
    KEYSOURCE_COOKIE    => "using cookie",
    KEYSOURCE_NEW       => "new client",

    CGISIG_HANDLER      => ".",
    CGISIG_REFERRER     => "..",

    CGISIG_KEEPDATA     => ".keepdata",
    CGISIG_REQTYPE      => ".purpose",
    CGISIG_CLIENTKEY    => ".clientkey",
    CGISIG_IGNORE       => ".ignore",
    CGISIG_SUBREQ       => ".subreq",
    CGISIG_PARAMETERS   => ".overrides",

    CGISIG_DISPLAY      => "_display",
    CGISIG_ACTION       => "_action",
    CGISIG_SRCPAGE      => "_src_pageid",
    CGISIG_REQPAGE      => "_req_pageid",
    CGISIG_REQPARAMS    => "_req_params",

    REQTYPE_ACTION      => "action",
    REQTYPE_DISPLAY     => "display",

    # Custom reponse from CyberSource POM.  We use this to parse out the
    # parameters which we sent to them.

    CGISIG_POMRESPONSE  => "orderPage_declineResponseURL",

};

#!BulkSplit

# ------------------------------------------------------------------------------
# newreq
# newreq CGI->new()
# newreq "_display=login&s_username=ryan"
# newreq "_display=login", "s_username=ryan"
# 
# Come to life
# ------------------------------------------------------------------------------

sub newreq {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    $self->_mkcgiinst( @_ );

    $self->_refresh( SESSIONACTIVEDIR );

    $self->_parsecgi();

    $self->_setreqkey();

    $self->_setmeta();

}#newreq

# ------------------------------------------------------------------------------
# restorereq LEVEL
# 
# Restore a request from the history.
#
# Where LEVEL can be:
#
#   0       Current request (no operation performed)
#   1       Last request
#   2       The one before the last
#   3       The one before that
#   4       The one before that
#   max     No-op, you cannot go back farther than: REQHISTORYSIZE - 1
#
# ------------------------------------------------------------------------------

sub restorereq {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $level = sprintf( "%d", shift );

    my $hist = $self->gethistory();

    return unless $level > 0;

    return if $level >= REQHISTORYSIZE;

    if( ref($hist) eq 'ARRAY' ) {

        return if $level >= $#$hist;

        $level = ($#$hist - $level);

        my $entry = $hist->[$level];

        if( ref($entry) eq 'HASH' ) {

            Hub::lmsg( "Restoring request: $entry->{'query'}", "info" );

            $self->newreq( $entry->{'query'} );

        }#if

    }#if

}#restorereq

# ------------------------------------------------------------------------------
# endreq
# 
# Ends the request (saves session to disk)
# ------------------------------------------------------------------------------

sub endreq {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    # trim request history

    my $hist = $self->gethistory();

    if( ref($hist) eq 'ARRAY' ) {
    
        while( $#$hist >= REQHISTORYSIZE ) {

            shift @$hist;

        }#while

    }#if

    # for debugging, save a copy (before data is taken away)

    $self->save( "DEBUG" ) if $$Hub{'/sys/DEBUG'};

    # keep or remove data

    if( $self->{'keepdata'} ) {

        $self->setcurrent( "saveddata", $self->takedata() );

    } else {

        $self->takecurrent( "saveddata" );

    }#if

    # remove temp variables

    $self->takedata();

    $self->takeaction();

    $self->takecompleted();

    # save session file

    $self->save();

}#endreq

# ------------------------------------------------------------------------------
# setrelay( "login" );
# setrelay( "login", "username=ryan&password=" );
# setrelay( "login", "username=ryan", "password=" );
# 
# Set relay (next handler and parameters) data
# ------------------------------------------------------------------------------

sub setrelay {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $handler = shift;

    my $params = join ';', @_;

    $self->setsignal( CGISIG_REQPAGE, $handler );

    $self->setsignal( CGISIG_REQPARAMS, $params );

}#setrelay

# ------------------------------------------------------------------------------
# load
# 
# Load a session file.  Note that this *takes over* the current request. Most
# notably, this loaded file is resaved when endreq() is called.
# ------------------------------------------------------------------------------

sub load {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $dir = shift;

    $self->_refresh( $dir );

    # instance members

    my $meta = $self->getmeta();

    map { $self->{$_} = $meta->{$_} } keys %$meta if( ref($meta) eq 'HASH' );

}#load

# ------------------------------------------------------------------------------
# logreq
# 
# Log request state information
# ------------------------------------------------------------------------------

sub logreq {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $props = {

        'pid'       => $$,
        'reqnum'    => Hub::getreqnum(),

    };

    my $msg = Hub::fmatv( "sys/reqlogentry", $props, $self->getmeta() );

    Hub::lmsg( $msg, "info" ) if $msg;

}#logreq

# ------------------------------------------------------------------------------
# has KEY
# 
# Return 1 if the specified element is defined, 0 if not.
# ------------------------------------------------------------------------------

sub has {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $key = shift;

    my $elem = $self->{'_hf'}->get( $key );

    return defined $elem;

}#has

# ------------------------------------------------------------------------------
# get KEY
# 
# Directly get by key
# ------------------------------------------------------------------------------

sub get {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my ($key,$default) = @_;

    my $val = $self->{'_hf'}->get( $key );

    return defined $val ? $val : $default;

}#get

# ------------------------------------------------------------------------------
# take KEY
# 
# Directly get by key, then delete it
# ------------------------------------------------------------------------------

sub take {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my ($key,$default) = @_;

    my $val = $self->{'_hf'}->get( $key );

    $self->{'_hf'}->set( $key, undef );

    return defined $val ? $val : $default;

}#get

# ------------------------------------------------------------------------------
# set KEY, DATA
# 
# Directly set by key
# ------------------------------------------------------------------------------

sub set {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $arg = shift;

    if( @_ ) {

        return $self->{'_hf'}->set( $arg, @_ );

    } else {

        if( ref($arg) eq 'HASH' ) {

            keys %$arg; # reset

            while( my($k,$v) = each %$arg ) {

                $self->{'_hf'}->set( $k, $v );

            }#while

        }#if

    }#if

}#set

# ------------------------------------------------------------------------------
# save
# 
# Write to disk
# ------------------------------------------------------------------------------

sub save {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    if( @_ ) {

        my $dir = shift;

        my $fn = $self->_mkfilename( $dir );

        $self->{'_hf'}->saveCopy( $fn );

    } else {

        $self->{'_hf'}->save();

    }#if

}#save

# ------------------------------------------------------------------------------
# clear
# 
# Clear all session data
# ------------------------------------------------------------------------------

sub clear {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $struct = {

        'ACTION'    => {},
        'DATA'      => {},
        'HISTORY'   => [],
        'META'      => {},
        'STATIC'    => {},

    };

    if( @_ ) {

        my $arg = shift;

        my $key = uc( $arg );

        if( defined $struct->{$key} ) {

            $self->set( $key, $struct->{$key} );

        } else {

            $self->take( $arg );

        }#if

    } else {

        $self->{'_hf'}->setRoot( $struct );

    }#if

}#clear

# ------------------------------------------------------------------------------
# clean
# 
# Clear everything but in-use data
# ------------------------------------------------------------------------------

sub clean {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $root = $self->{'_hf'}->data();

    if( ref($root) eq 'HASH' ) {

        foreach my $key ( keys %$root ) {

            next if $key =~ /^ACTION|DATA|HISTORY|META|STATIC$/;

            delete $root->{$key};

        }#foreach

    }#if

}#clean

# ------------------------------------------------------------------------------
# upload
# 
# Upload multi-part form data
# ------------------------------------------------------------------------------

sub upload {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $key = shift;

    my $IN = $self->{'_cgi'}->upload( $key );

    my $filename = $self->{'_cgi'}->param( $key );

    if( $filename ) {

        my $props = $self->{'_cgi'}->uploadInfo( $filename );

        if( ref( $props ) eq 'HASH' ) {

            # placeholder

        }#if

        my ($buf,$total_bytes) = ();

        while( my $bytes = sysread( $IN, $buf, 1024, $total_bytes ) ) {

            $total_bytes += $bytes;

        }#while

        close( $IN );

        Hub::lmsg( "Uploaded: $total_bytes bytes", "info" );

        return $buf;
    
    } else {

        Hub::lerr( "Couldn't upload: $filename" );

        return undef;

    }#if

}#upload

#-------------------------------------------------------------------------------
# mkurl CGIPARAMS, [OPTIONS]
# mkurl OPTIONS
# mkurl
#
# Create url with current context information.  Parameters encountered first
# take prescedence.
#
# Where, CGIPARAMS can be:
#
#   SCALAR          "name=George;_action=assisinate;time=yesterday"
#
#   HASHREF         {
#                       name    => "George",
#                       _action => "assasinate",
#                       time    => "yesterday",
#                   }
#
#   ARRAYREF        [
#                       "name="George",
#                       "_action="assasinate",
#                       "time="yesterday",
#                   ]
#
# And, OPTIONS can be:
#
#   --noparams      No parameters
#
#   --referrer      Create a link to the referring page
#
#   --lastreq       Link to the last request (even if it's the same handler)
#
#-------------------------------------------------------------------------------
sub mkurl {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $cgiparams   = {};
    my $provided    = ();
    my $options     = ();

    # context parameters

    $cgiparams->{+CGISIG_REFERRER} = $self->{'handler'};

    if( $self->getmeta( "keysource" ) ne KEYSOURCE_COOKIE ) {

        $cgiparams->{+CGISIG_CLIENTKEY} = $self->{'clientkey'};

    }#if

    # parse parameters

    while( @_ ) {

        my $arg = shift;

        if( !ref($arg) && $arg =~ "^--" ) {

            $options .= $arg

        } else {

            $provided = $arg;

        }#if

    }#while

    if( $options =~ "--referrer" ) {

        $cgiparams->{+CGISIG_HANDLER} = $self->getcurrent('referrer');

    } elsif( $options =~ "--lastreq" ) {

        $cgiparams->{+CGISIG_HANDLER} = $self->getmeta('referrer');

    }#if

    if( $provided ) {

        if( not ref($provided) ) {

            my @p = split /[;&]/, $provided;

            $provided = \@p;

        }#if

        if( ref($provided) eq 'HASH' ) {

            Hub::merge( $cgiparams, $provided );

        } elsif( ref($provided) eq 'ARRAY' ) {

            foreach my $slice ( @$provided ) {

                my ($k,$v) = split '=', $slice;

                $cgiparams->{$k} ||= $v;

            }#foreach

        }#if

    }#if

    # get the basic url info from the environment

    my $url = ();

    my $prefix = $self->getmeta( "url_prefix" );

    my $scrname = Hub::getname( $ENV{'SCRIPT_NAME'} );

    if( $scrname ) {

        $url = Hub::fixpath( "$prefix/$scrname" );

    } else {

        $url = $0;

    }#if

    $options =~ '--noparams' and return $url;

    $url .= "?";

    # upgrade the depricated '_display' parameter

    if( defined $cgiparams->{+CGISIG_DISPLAY} ) {

        $cgiparams->{+CGISIG_HANDLER} = $cgiparams->{+CGISIG_DISPLAY};

        delete $cgiparams->{+CGISIG_DISPLAY};

    }#if

    # links which do not specify a handler re-use the current handler

    unless( defined $cgiparams->{+CGISIG_HANDLER} ) {

        $cgiparams->{+CGISIG_HANDLER} = $self->getmeta("handler");

    }#unless

    # subrequests are not independant parameters

    if( $cgiparams->{+CGISIG_SUBREQ} ) {

        $cgiparams->{+CGISIG_HANDLER} = $self->getmeta("baseid");

        $cgiparams->{+CGISIG_HANDLER} .= ':' unless $cgiparams->{+CGISIG_SUBREQ} =~ /^:/;

        $cgiparams->{+CGISIG_HANDLER} .= $cgiparams->{+CGISIG_SUBREQ};

    }#unless

    delete $cgiparams->{+CGISIG_SUBREQ};

    # add our context (and provided) parameters

    my @params = map { "$_=$cgiparams->{$_}" } sort keys %$cgiparams;

    $url .= join ';', @params;

    return $url;

}#mkurl

# ------------------------------------------------------------------------------
# getclientcookie
# 
# Print the client key as a cookie
# ------------------------------------------------------------------------------

sub getclientcookie {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    if( $self->getmeta( "keysource" ) ne KEYSOURCE_SHELL ) {

        my $cookie = $self->{'_cgi'}->cookie(
            -name   => COOKIENAME,
            -value  => $self->getmeta('clientkey'),
            -expires=> '+1M',
            -path   => '/'
        );

        Hub::lmsg( "Set cookie: $cookie", "cgi" );

        return "Set-Cookie: $cookie";

    }#if

}#getclientcookie

# ------------------------------------------------------------------------------
# _parsecgi
# 
# Populate ourselves with new data recieved through the CGI.  Also handle
# system (.) parameters.
# ------------------------------------------------------------------------------

sub _parsecgi {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    # A parameter '.overrides' is a url string of cgi parameters which over-
    # ride submitted ones.  This allows a form to have variable arguments
    # which can be set through javascript.

    my $additional = $self->{'_cgi'}->param( CGISIG_PARAMETERS );

    # POM Response parameter

    my $pomresponse = $self->{'_cgi'}->param( CGISIG_POMRESPONSE );

    foreach my $additional ( $additional, $pomresponse ) {

        if( $additional ) {

            $additional =~ s/^.*?\?//;

            my $p = Hub::unpackcgi( $additional );

            if( ref($p) eq 'HASH' ) {

                foreach my $k ( keys %$p ) {

                    Hub::lmsg( "Override: $k", "cgi" );

                    $self->{'_cgi'}->param( -name=>$k, -value=>$p->{$k} );

                }#foreach

            }#if

        }#if

    }#foreach

    # Glean the current handler

    $self->{'referrer'} = $self->{'_cgi'}->param( CGISIG_REFERRER );

    $self->{'handler'} = $self->{'_cgi'}->param( CGISIG_HANDLER );

    # Presume propper form and defaults and compatibility

    $self->{'referrer'} ||= $self->{'_cgi'}->param( CGISIG_SRCPAGE );

    $self->{'referrer'} ||= DEFAULTHANDLER;

    $self->{'handler'}  ||= $self->{'_cgi'}->param( CGISIG_DISPLAY );

    $self->{'handler'}  ||= $self->{'referrer'};

    $self->{'handler'} =~ s/&.*//g;

    $self->{'handler'} =~ s/::+/:/g;

    $self->{'handler'} = lc( $self->{'handler'} );

    # Set 'baseid'

    my @handler = split ':', $self->{'handler'};

    $self->{'baseid'} = shift @handler;

    for( my $i = 1; my $subreq = shift @handler; $i++ ) {

        $self->{"reqid$i"} = $subreq;

    }#for

    # Glean request type

    $self->{'action'} = lc($self->{'_cgi'}->param( CGISIG_ACTION ));

    $self->{'reqtype'} = $self->{'_cgi'}->param( CGISIG_REQTYPE );

    $self->{'reqtype'} ||= $self->{'action'} ? REQTYPE_ACTION : REQTYPE_DISPLAY;

    # System handling variables

    $self->{'keepdata'} = $self->{'_cgi'}->param( CGISIG_KEEPDATA );

    # Parse parameters (sort by keydepth)

    my $ignore = $self->{'_cgi'}->param( CGISIG_IGNORE );

    foreach my $key ( sort Hub::keydepthsort $self->{'_cgi'}->param() ) {

        next unless $key;

        my @value = $self->{'_cgi'}->param( $key );

        my $value = $#value > 0 ? \@value : pop @value;

        Hub::lmsg( "$key: $value", "cgi" );

        $value =~ s/<BLANK>//g;

        for( $key ) {

            /$ignore/ and next if $ignore;

            # System parameters begin with a dot (.)

            /^\./ and next;

            # Signals begin with an underscore (_)

            /^_/ and do {

                $key eq CGISIG_HANDLER and next;

                $key =~ s/^_//g;

                $self->setsignal( $key, $value );

                last;

            };#do

            # Static parameters begin with s-underscore (s_)

            s/s_// and do {

                $key =~ s/^s_//g;

                $self->setstatic( $key, $value );

                last;

            };#do

            # Detect if a checkbox has been unchecked

            s/^ORIGCHECKBOXVAL_// and do {

                $self->setdata( $key, "" ) unless $self->getdata( $key );

                last;

            };#do

            $self->setdata( $key, $value );

        }#for

    }#foreach

    # Merge in kept data

    my $saved = $self->getcurrent( "saveddata" );

    if( ref($saved) eq 'HASH' ) {

        my $data = $self->getdata() || {};

        $data = Hub::merge( $data, $saved );

        $self->setdata( $data ); # it may not exist yet

    }#if

}#_parsecgi

# ------------------------------------------------------------------------------
# _mkcgiinst
# 
# Make CGI instance
# ------------------------------------------------------------------------------

sub _mkcgiinst {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my @params = ();

    $self->{'_cgi'} = $Hub->Cgi;

    while( @_ ) {

        my $arg = shift;

        if( ref($arg) eq 'CGI' ) {

            Hub::lmsg( "Using provided CGI", "cgi" );
        
            $self->{'_cgi'} = $arg;

        } else {

            push @params, $arg;

        }#if

    }#while

    # When a cgi script is called from another, using the 'system' perl 
    # function (or backticks), parameters don't go through the CGI mechanism.
    # Rather, they appear in ARGV.

    @ARGV and push @params, @ARGV;

    if( @params ) {

        my $params = join ';', @params;
    
        Hub::lmsg( "Creating CGI from parameters: $params", "cgi" );

        $self->{'_cgi'} = CGI->new( $params );

    }#if

    $self->{'_cgi'} ||= CGI->new();

    if( ref($self->{'_cgi'}) =~ /^CGI/ ) {

        # re-create if keywords are present. SUSPECT! not sure why this was
        # needed.

        my $keywords = $self->{'_cgi'}->param( "keywords" );

        if( $keywords ) {

            Hub::lmsg( "Recreating CGI from keywords: $keywords", "cgi" );

            $self->{'_cgi'} = CGI->new( $keywords ) if $keywords;

        }#if

    } else {

        Hub::lerr( "Cannot obtain CGI context" );

    }#if

}#_mkcgiinst

# ------------------------------------------------------------------------------
# _refresh
# 
# Called by newreq, initialize members
# ------------------------------------------------------------------------------

sub _refresh {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $dir = shift || return;

    map { delete $self->{$_} } ( grep !/^_/, keys %$self );

    $self->_setclientkey();

    $self->{'reqdate'} = time;

    $self->{'_filename'} = $self->_mkfilename( $dir );

    $self->{'_hf'} = Hub::mkinst( 'HashFile', $self->{'_filename'} );

    $self->{'reqkey'} = "";

    $self->_validate();

}#_refresh

# ------------------------------------------------------------------------------
# _validate
# 
# Check for timeout and misconfigurations
# ------------------------------------------------------------------------------

sub _validate {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    if( -f $self->{'_filename'} ) {

        # Expire if the timeout has been reached

        my $stats = stat $self->{'_filename'};

        $self->{'lastaccess'} = $stats ? $stats->mtime() : 0;

        my $timeout = $$Hub{'/sys/timeout/session'};

        if( $timeout ) {

            my $duration = $self->{'reqdate'} - $self->{'lastaccess'};

            if( $duration > $timeout ) {

                Hub::lmsg( "Session timeout: $duration/$timeout", "info" );

                $self->clear();

                $self->save();

            }#if

        }#if

    } else {

        $self->clear();

    }#if

}#_validate

# ------------------------------------------------------------------------------
# _mkfilename SUBDIR
# 
# Make the path to the session file
# ------------------------------------------------------------------------------

sub _mkfilename {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $subdir      = shift || return;

    my $ckey        = $self->{'clientkey'};

    my $dir         = $self->{'_clientpath'};

    my $path        = Hub::mkabsdir( "$dir/$subdir" );

    return "$path/$ckey";

}#_mkfilename

# ------------------------------------------------------------------------------
# _setclientkey
# 
# 1) Use the client key specified in a cookie
# 2) Or, use the .clientkey CGI parameter
# 3) Or, generate a new key
# ------------------------------------------------------------------------------

sub _setclientkey {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    if( $ENV{'MIMIC'} ) {

        $self->{'clientkey'} = $ENV{'MIMIC'};

        $self->{'keysource'} = KEYSOURCE_SHELL;

    } elsif( not $ENV{'SERVER_NAME'} ) {

        my $shellkey = $ENV{'USERNAME'} || "GLOBALUSER";

        $self->{'clientkey'} = Hub::checksum( $shellkey );

        $self->{'keysource'} = KEYSOURCE_SHELL;

    } elsif( $self->{'_cgi'}->cookie( COOKIENAME ) ) {

        $self->{'clientkey'} = $self->{'_cgi'}->cookie( COOKIENAME );

        $self->{'keysource'} = KEYSOURCE_COOKIE;

    } elsif( $self->{'_cgi'}->param( CGISIG_CLIENTKEY ) ) {

        $self->{'clientkey'} = $self->{'_cgi'}->param( CGISIG_CLIENTKEY );

    } else {

        my $seed = sprintf("%d%03d", time(), int(rand() * 1000));

        $self->{'clientkey'} = Hub::checksum( $seed );

        $self->{'keysource'} = KEYSOURCE_NEW;

    }#if

}#_setclientkey

# ------------------------------------------------------------------------------
# _setreqkey
# 
# Generate unique request key
# ------------------------------------------------------------------------------

sub _setreqkey {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    my $criteria = {
        'QUERY_STRING'  => $self->{'_cgi'}->query_string(),
        'DATA'          => $self->getdata(),
    };

    my $text = Hub::hffmt( $criteria );

    $self->{'reqkey'} = Hub::checksum( $text );

    if( $$Hub{'/sys/DEBUG'} ) {

        my $fn = $self->_mkfilename( SESSIONACTIVEDIR ) . '.crit';

        Hub::writefile( $fn, $text )

    }#if

}#_setreqkey

# ------------------------------------------------------------------------------
# _setmeta
# 
# Set metadata members
# ------------------------------------------------------------------------------

sub _setmeta {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    #
    # www context information (set as constants)
    #

    my ($proto,$junk) = split /:/, $ENV{'SCRIPT_URI'};

    ($proto,$junk) = split /\//, $ENV{'SERVER_PROTOCOL'} unless $proto;

    $proto = lc( $proto );

    my $http_host   = $ENV{'HTTP_HOST'};

    my $request_uri = Hub::fixpath( $ENV{'REQUEST_URI'} );

    $request_uri =~ s/\?.*//g;

    my $url_prefix = "$proto://$http_host";

    $self->{'server_root_url'} = $url_prefix;

    my $common_full_url = $url_prefix;

    my $working_uri = Hub::getpath( $request_uri );

    $working_uri ne "." and $url_prefix .= $working_uri;

    $self->{'url_prefix'} = $url_prefix;

    foreach my $path_key ( keys %{$$Hub{'/sys/path'}} ) {

        $$Hub{'/sys/uri/'.$path_key} =
            Hub::fixpath("$url_prefix/".$$Hub{"/sys/path/$path_key"});

    }#foreach

    $common_full_url .= $$Hub{'/sys/uri/common'};

    $self->{'common_full_url'} = $common_full_url;

    #
    # instance members
    #

    my $meta = {};

    foreach my $k ( keys %$self ) {

        next if $k =~ /^_/;

        $meta->{$k} = $self->{$k};

    }#foreach

    $self->setmeta( $meta );

    $$Hub{'/usr'} = $meta;

    #
    # Store request history
    #

    my $hist = $self->gethistory();

    push @$hist, {
        'query'     => $self->{'_cgi'}->query_string(),
        'meta'      => $meta,
    };

    # A hander's referrer cannot be itself

    unless( $self->{'referrer'} eq $self->{'handler'} ) {

        $self->setcurrent( 'referrer', $self->{'referrer'} );

    }#unless

    #
    # Special variables
    #

    $$Hub{'/usr/BACKPAGE'}     = $self->mkurl('--referrer');
    $$Hub{'/usr/REQPAGE'}      = $self->mkurl('--referrer');
    $$Hub{'/usr/ACTION'}       = $self->mkurl('--noparams');
    $$Hub{'/usr/LASTPAGEID'}   = $self->getmeta('referrer');
    $$Hub{'/usr/REQPAGEID'}    = $self->getmeta('referrer');
    $$Hub{'/usr/CLIENTKEY'}    = $self->getmeta('clientkey');
    $$Hub{'/usr/BIN'}          = $self->getmeta('url_prefix');

}#_setmeta

# ------------------------------------------------------------------------------
# new
# new CLIENTDIR
# 
# Constructor.
# ------------------------------------------------------------------------------

sub new {

    my $self        = shift;
    my $classname   = ref( $self ) || $self;

    $self = { };

    my $obj = bless $self, $classname;

    $obj->_init( @_ );

    return $obj;

}#new

# ------------------------------------------------------------------------------
# _init
# _init CLIENTDIR
# 
# Called by new, initialze members.
# ------------------------------------------------------------------------------

sub _init {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";
    
    my $path        = shift || "";
    my $clientpath  = $$Hub{'/sys/path/client'} || './';

    $self->{'_clientpath'}  = -d $path ? $path : $clientpath;
    $self->{'_filename'}    = "";
    $self->{'_cgi'}         = ();

}#_init

# ------------------------------------------------------------------------------
# AUTOLOAD
# 
# Autoload get/set/take/has calls and translate them into correct instance 
# method calls.
#
# The method name is translated as:
#
#   $class->aaabbb( ... )
#
#   aaa     Is the method part, and can be:
#
#               get|set|take|has
#
#   bbb     Is the root identifier part.  I can be anything, but these 
#           special ones are re-routed:
#
#               current|signal|base
#
# If the aaa part is not one of the four, an error is logged.
#
# If the bbb part is not of the two special ones, then it is considerred to be
# the id of the root hash whithin which we will handle data.
#
# A bbb part of 'current' sets the bbb part to the current handler.
#
# A bbb part of 'signal' is the same as 'current' in display context, but if we
# are inside an action request, 'signal' is re-routed to the action hash (where
# the action signals are stored.)
#
# Given that were invoked by a request of:
#
#   .=p001;..=index;_id=42;name=joe
#
# Then                              Becomes                             Returns
#
#   getsignal( "id" )               get->( "p001:id" )                  42
#   setcurrent( "id", 1002 )        set->( "p001:id", 43 )
#
# and subsequently invoked with a request of:
#
#   .=p001;..=index;_action=print;_id=1001;name=jimmy
#
# Then                              Becomes                             Returns
#
#   getsignal( "id" )               get->( "ACTION:id" )                1001
#   setcurrent( "id", 1002 )        set->( "p001:id", 1002 )
#   getcurrent( "name" )            get->( "p001:name" )                joe
#   getsignal( "name" )             get->( "ACTION:name" )              jimmy
#   getaction( "name" )             get->( "ACTION:name" )              jimmy
#
# And for any other bbb part:
#
# This                              Becomes
#
#   getfoo( "id" )                  get->( "FOO:id" )
#   setFoo( "id", 1004 )            error!
#   set_Foo( "id", 1004 )           error!
#   set_foo( "id", 1004 )           error!
#   setfoo( "user:name", "joe" )    set->( "FOO:user:name", "joe" )
#   hasjunk( "mail" )               has->( "JUNK:mail" )
#   takeunk( "mail" )               has->( "JUNK:mail" )
#
# SUBREQUESTS
#
# A bbb part of 'base' sets the bbb part to the base handler hash.  This is
# use to share data in subrequests. Here are three requests, where the second
# two are subrequests:
#
#   1) .=p001;_view=ltr
#   2) .=p001:summary;_sort=date
#   3) .=p001:summary:print;_orientation=landscape
#
# In the third request, the following happens:
#
#   getbase( "view" )               ltr
#   getsignal( "orientation" )      landscape
#   getsignal( "sort" )
#   getmeta( "handler" )            p001:summary:print
#   getmeta( "baseid" )             p001
#   getmeta( "reqid1" )             summary
#   getmeta( "reqid2" )             print
#
# NOTE: The data hash for the above is:
# 
#   %p001{
#       sort == 1
#       %summary{
#           %print{
#               orientation == landscape
#           }
#           sort == date
#       }
#       view == ltr
#   }
#
# The subrequest 'summary' is stored under the base request 'p001', which means
# that you would cause problems where you to:
#
#   .=p001;_summary=on
#
#   -or-
#
#   setbase( "summary", "on" )
#
# as you would be overwriting the nested data.
# 
# ------------------------------------------------------------------------------

sub AUTOLOAD {

    my $self        = shift; # IMPORTANT that this is shifted
    my $name        = $AUTOLOAD;

    if( $name =~ s/.*::// ) {

        if( $name =~ /^(get|set|take|has)([a-z]+)/ ) {

            my ($method,$key) = ($1,uc($2));

            if( $key eq 'CURRENT' ) {

                $key = $self->{'handler'};

            } elsif( $key eq 'SIGNAL' ) {

                if( $self->{'reqtype'} eq REQTYPE_ACTION ) {

                    $key = 'ACTION';

                } else {

                    $key = $self->{'handler'};

                }#if

            } elsif( $key eq 'BASE' ) {

                $key = $self->{'baseid'};

            }#if

            my $requiredargs = $method =~ /^get|take|has$/ ? 0 : 1;

            if( $#_ >= $requiredargs ) {

                my $arg = shift;

                if( ref($arg) ) {

                    unshift @_, $arg;

                } else {

                    $key .= ":$arg";

                }#if

            }#if

            my $eval = "\$self->$method( \"$key\", \@_ )";

#           Hub::lmsg( "EVAL: $eval" );

            return eval $eval;

        }#if
        
    }#if

    Hub::lerr( "No such method: $name" );

}#AUTOLOAD

sub DESTROY {

    # Defining this function prevents it from being searched in AUTOLOAD

}#DESTROY

#-------------------------------------------------------------------------------

'???';
