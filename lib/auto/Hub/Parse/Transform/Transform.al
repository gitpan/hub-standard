# NOTE: Changes made here will be lost when bulksplit is run again.
package Hub::Parse::Transform;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Transform
#
# Called by the framework to invoke Autoloader::AUTOLOAD, in essence loading
# this file.
# ------------------------------------------------------------------------------
sub Transform {
}#Transform

#line 39

# ------------------------------------------------------------------------------
# safestr STRING
# 
# Pack nogood characters into good ones.  Good characters are letters, numbers,
# and the underscore.
# ------------------------------------------------------------------------------
=test(match) safestr( 'Dogs (Waters, Gilmour) 17:06' );
=result Dogs_20__28_Waters_2c__20_Gilmour_29__20_17_3a_06
=cut
# ------------------------------------------------------------------------------

sub safestr {

    my $str = shift;

    $str =~ s/([^A-Za-z0-9_])/sprintf("_%2x_", unpack("C", $1))/eg;

    return $str;

}#safestr

# ------------------------------------------------------------------------------
# packcgi STRING
# 
# Pack characters into those used for passing by the cgi.
# ------------------------------------------------------------------------------

sub packcgi {

    my $str = shift;

    $str =~ s/([^A-Za-z0-9_])/sprintf("%%%x", ord($1))/eg;

    return $str

}#packcgi

# ------------------------------------------------------------------------------
# unpackcgi QUERY
# 
# Unpack cgi characters into a kv hashref
# ------------------------------------------------------------------------------

sub unpackcgi {

    my $q = shift;
    my $p = {};

    $q =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;

    $q =~ tr/+/ /;

    my @pairs = split /[&;]/, $q;

    for( my $i = 0; $i <= $#pairs; $i++ ) {

        if( $pairs[$i] =~ /(.*)=(.*)/ ) {

            my ($l,$r) = ($1,$2);

            if( $r =~ /^\((?:.*,)*.*\)$/ ) {

                my @extract = split( /\,/, substr( $r, 1, (length $r) -1 ) );

                $p->{$l} = \@extract;

            } else {

                $p->{$l} = $r;

            }#if

        }#if

    }#for

    return $p;

}#unpackcgi

# ------------------------------------------------------------------------------
# getspec PATH
# 
# Given a path to a file, return it's parts (directory, filename, extension);
# ------------------------------------------------------------------------------

sub getspec {

    my $path = shift;

    my $name    = Hub::getname( $path )  || "";
    my $ext     = Hub::getext( $path )   || "";
    my $dir     = Hub::getpath( $path )  || "";

    $name =~ s/\.$ext$//; # return the name w/o extension

    return ($dir,$name,$ext);

}#getspec

# ------------------------------------------------------------------------------
#   Exract the parent from the given filepath
#
#   for example:
#
#       getpath( "/etc/passwd" )        /etc
#       getpath( "/usr/local/bin" )     /usr/local
#
# ------------------------------------------------------------------------------
sub getpath {

    my $orig = Hub::fixpath( shift ) || '';

    my ($path) = $orig =~ /(.*)\//;

    return $path || '';

}#sub

#-------------------------------------------------------------------------------
#   getname( $path )
#
#   Note, if the given path is a full directory path, the last directory is
#   still considerred a filename.
#
#   example:
#
#       getname( "../../../users/newuser/web/data/p001/batman-small.jpg" );
#       getname( "../../../users/newuser/web/data/p001" );
#       getname( "/var/log/*.log" );
#
#   will return:
#
#       "batman-small.jpg"
#       "p001"
#       "*.log"
#
#-------------------------------------------------------------------------------
sub getname {

    ## DO NOT CALL Logger ROUTINES HERE
    ## (CAUSES INF REC WHEN LOGGING 'dbg' MESSAGES)

    my $orig = shift;

    # correct slashes
    $orig =~ s/\\/\//g;

    my $ret = $orig;

    if( $orig =~ /\// ) {

        my @parts = split '/', $orig;

        $ret = pop @parts;

    }#if

    return $ret;

}#getFilename

# ------------------------------------------------------------------------------
#   getext( $path )
#
#   example:
#
#       getext( "/foo/bar/filename.ext" )
#       getext( "filename.cgi" )
#
#   will return:
#
#       "ext"
#       "cgi"
#
# ------------------------------------------------------------------------------
sub getext {

 my $orig = shift;

    my $fn = getname( $orig );

    my $tmp = reverse( $fn );

    $tmp =~ s/\..*//;

     my $ret = reverse $tmp;

    return $ret eq $fn ? '' : $ret;

}#getExtension

#-------------------------------------------------------------------------------
# fixpath( $path )
#
# Clean up malformed paths (usually do to concatenation logic).
#-------------------------------------------------------------------------------
#|test(match)   fixpath( "../../../users/newuser/web/bin/../src/screens" );
#~              ../../../users/newuser/web/src/screens
#~
#|test(match)   fixpath( "users/newuser/web/" );
#~              users/newuser/web
#~
#|test(match)   fixpath( "users/../web/bin/../src" );
#~              web/src
#~
#|test(match)   fixpath( "users//newuser" );
#~              users/newuser
#~
#|test(match)   fixpath( "users//newuser/./files" );
#~              users/newuser/files
#~
#|test(match)   fixpath( "http://site/users//newuser" );
#~              http://site/users/newuser
#|test(match)   fixpath( '/home/hub/build/../../../out/doc/pod' );
#~              /out/doc/pod
#-------------------------------------------------------------------------------

sub fixpath {

    my $path = shift || return;

    # correct solidus
    $path =~ s/\\/\//g;

    # remove empty dirs, ie: // (unless it looks like protocol '://')
    $path =~ s/(?<!:)\/+/\//g;

    # remove pointless dirs, ie: /./
    $path =~ s/\/\.\//\//g;

    # condense relative subdirs
    while( $path =~ s/[^\/\.]+\/\.\.\/?//g ) {

        # remove empty dirs (again)
        $path =~ s/(?<!:)\/+/\//g;

    }#while

    # remove trailing /
    $path =~ s/\/\z//;

    return $path;

}#fixpath

#-------------------------------------------------------------------------------
# abspath PATH
# abspath PATH NOCHECK
#
# File must exist unless NOCHECK is specified.
#-------------------------------------------------------------------------------

sub abspath {

    my $path    = shift || return;
    my $nocheck = shift;

    # TODO incorporate Cwd's abs_path

    my $abs_path = findAbsolutePath( $path );

    unless( $nocheck ) {

        $abs_path = undef unless Hub::filetest( $abs_path );

    }#unless

    return $abs_path;

}#getAbsolutePath

# ------------------------------------------------------------------------------
# relpath - Relative path
#
# relpath PATH, FROMPATH
#
# OPTIONS:
#
#   -asdir      Specifies that FROMPATH is a directory.  Provided for times when
#               FROMPATH does not exist (and hence the -d test will fail).
#
# Return the path to PATH from FROMPATH.
# ------------------------------------------------------------------------------
#|test(match,..)    relpath( "/home/docs", "/home/docs/install", -asdir );
#|test(match,.)     relpath( "/home/docs", "/home/docs/README.txt" );
#|test(match)       relpath( "/home/src", "/home/docs/install", -asdir );
#~                  ../../src
#|test(match)       relpath( "/home/docs/README.txt", "/home/docs", -asdir );
#~                  README.txt
# ------------------------------------------------------------------------------

sub relpath {

    my $opts = Hub::opts( \@_, {} );

    my $path = Hub::fixpath(shift);
    my $from = Hub::fixpath(shift);

    $from = Hub::getpath( $from ) unless
        $$opts{'asdir'} || Hub::filetest( $from, '-d' );

    my @parts = split '/', $path;

#   print "1) $from :: ", join( '/', @parts ), "\n";

    while( @parts ) {

        my $part = shift @parts;

        unless( $from =~ s/^[\/]?$part// ) {

            unshift @parts, $part;

            last;

        }#unless

    }#while

#   print "2) $from :: ", join( '/', @parts ), "\n";

    $from =~ s/\/[^\/]+/..\//g;

    @parts and $from .= join( '/', @parts );

    $from ||= '.';

    return Hub::fixpath( $from );

}#relpath

# ------------------------------------------------------------------------------
# mkabsdir DIR
# 
# Create the directory specified.
# ------------------------------------------------------------------------------

sub mkabsdir {

    my $path    = shift || return;

    my $abs_path = findAbsolutePath( $path );

    return unless $abs_path;

    return $abs_path if Hub::filetest( $abs_path );

    my $build_path = "";

    foreach my $part ( split '/', $abs_path ) {

        $build_path .= "$part/";

        -d $build_path and next;

        unless( mkdir $build_path, oct("0775") ) {
        
            Hub::lerr( "$!: $build_path" );

            return;

        }#unless

    }#foreach

    return $abs_path;

}#makeAbsoluteDir

#-------------------------------------------------------------------------------
#
#   findAbsolutePath( "../usr/" )
#   findAbsolutePath( "/usr/local" )
#
#   File may or may not exist
#
#-------------------------------------------------------------------------------
sub findAbsolutePath {

    my $relative_path = shift || return;

    $relative_path =~ s/\\/\//g;

    return $relative_path if $relative_path =~ /^\/|^[A-Za-z]:\//;

    my $base_dir = getpath( $0 );

    $base_dir = cwd() unless $base_dir =~ /^\/|^[A-Za-z]:\//;

    $base_dir =~ s/\\/\//g;

    return fixpath( "$base_dir/$relative_path" );

}#findAbsolutePath

# ------------------------------------------------------------------------------
# siteurl
# 
# Return the target website url.
# ------------------------------------------------------------------------------

sub siteurl {

    my $siteurl = Hub::getconst( "site_url" );

    if( $Hub->target_wc ) {

        $siteurl = $Hub->target_wc->get( "site_url" );

    }#if

    if( @_ ) {

        $siteurl .= "?" . join( '&', @_ );

    }#if

    return $siteurl;

}#siteurl

# ------------------------------------------------------------------------------
#   Format a string, replacing spaces with '&nbsp;'
#
#   for example:
#
#       nbspstr( "Hello <not html tags> world!" )
#
#   would return:
#
#       "Hello&nbsp;<not html tags>&nbsp;World"
#
# ------------------------------------------------------------------------------
sub nbspstr {

    my $s = shift || return;

    if( $s =~ /<.*>/ ) {

        my $p = 0;

        while( $p >= 0 ) {

            my $lb = index $s, '<', $p;
            my $rb = index $s, '>', $p;
            my $sp = index $s, ' ', $p;

            if( $sp >= 0 ) {

                if( ( $sp < $lb ) || ( $sp > $rb ) ) {

                    substr $s, $sp, 1, "&nbsp;";

                    $p = $sp + length( "&nbsp;" );

                } else {

                    $p = $rb;

                }#if

            } else {

                $p = $sp;

            }#if

        }#while

    } else {

        $s =~ s/ /&nbsp;/g;

    }#if

    return $s;

}#nbsp

# ------------------------------------------------------------------------------
# jsstr
#
# Format as one long string for use as the rval in javascript (ie put the
# backslash continue-ator at the end of each line).
# ------------------------------------------------------------------------------

sub jsstr {

    my $original = shift || "";
    my $modified = $original;

    # append \ to line
    $modified =~ s/([^\\])$/$1 =~ '[\r\n]' ? "\\" : "$1\\"/mge;

    # fix accidental \\ (double backslashes) at end of line
    $modified =~ s/\\\\$/\\/mg;

    # escape quotes
    $modified =~ s/([^\\])(['"])/$1\\$2/g;

    # quotes in a row
    $modified =~ s/([^\\])(['"])/$1\\$2/g;

    # escape embeded forward slashes (prevent embeded /script markers from closing
    # a containing block
    $modified =~ s/([^\\])(\/)/$1\\$2/g;

    # remove the last one
    $modified =~ s/\\\z//;

    return $modified;

}#jsString

# ------------------------------------------------------------------------------
#   Format a string, replacing spaces with '&nbsp;'
#
#   for example:
#
#       html( "<Hello=world!>" )              "&lt;Hello=World&gt;"
#
# ------------------------------------------------------------------------------
sub html {

    my $s = Hub::cpref(shift,'-sdref=1') || return;

    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;

    return $s;

}#html

# ------------------------------------------------------------------------------
# datetime TIMESTAMP?, OPTION*
#
# Friendly date-time formats of seconds-since-the-epoch timestamps.
# Default is the current time formatted as: MM/DD/YYYY hh:mm:ss.
# The decimal portion of HiRest time is truncated.
# Uses `localtime` to localize.
# ------------------------------------------------------------------------------
#|test(true)                                datetime( );
#|test(match,02/21/2003 06:21:24)           datetime( 1045837284 );
#|test(match,02/21/2003 06:21)              datetime( 1045837284, -nosec );
#|test(match,02/21 06:21:24)                datetime( 1045837284, -noyear );
#|test(match,02/21/2003 06:21:24am)         datetime( 1045837284, -ampm );
#|test(match,2/21/2003 6:21:24)             datetime( 1045837284, -nozeros );
#|test(match,02/21/2003)                    datetime( 1045837284, -notime );
#|test(match,06:21:24)                      datetime( 1045837284, -nodate );
#|test(match,February 21, 2003 06:21:24)    datetime( 1045837284, -letter );
#
# Combining options
#
#|test(match)   datetime( 1045837284, -ampm, -nosec );              
#~              02/21/2003 06:21am
#
#|test(match)   datetime( 1045837284, -nosec, -nozeros, -noyear );
#~              2/21 6:21
#
# Methods of passing options via tweaks (see Parser.pm)
#
#|test(match)   datetime( 1045837284, "nosec,noyear" );
#~              02/21 06:21
# ------------------------------------------------------------------------------

sub datetime {

    my $opts = Hub::opts( \@_ );

    my @month_names    = ( "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" );
    my @month_abbrs    = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
    my @day_names      = ( "Sunday", "Monday", "Tueday", "Wednesday", "Thursday", "Friday", "Saturday" );
    my @day_abbrs      = ( "Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat" );

    my $timestamp = time;

	while( my $arg = shift ) {

        if( $arg =~ /(\d+)\.?/ ) {

            $timestamp = $1;

        } else {

            map { $opts->{$_} = 1 } split /[\s,]/, $arg;

        }#if

    }#while

    my $digit_format = $$opts{'nozeros'} ? '%d' : '%02d';

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timestamp);

    my $ampm = "";

    if( $$opts{'ampm'} ) {
    
        $ampm = $hour > 12 ? "pm" : "am";
        $hour = $hour > 12 ? $hour - 12 : $hour;

    }#if

    my $props = {

        day     => sprintf( $digit_format, $mday ),
        month   => sprintf( $digit_format, $mon+1 ),
        year    => $year + 1900,
        hour    => sprintf( $digit_format, $hour ),
        minute  => sprintf( '%02d', $min ),
        second  => sprintf( '%02d', $sec ),
        ampm    => $ampm,

    };

    my $names = {

        MONTH   => $month_names[$mon],
        MM      => $month_abbrs[$mon],
        DAY     => $day_names[$wday],
        DD      => $day_abbrs[$wday],

    };

    my $date = "<#month>/<#day>/<#year>";
    my $time = "<#hour>:<#minute>:<#second><#ampm>";

    $$opts{'nosec'}     and $time = "<#hour>:<#minute><#ampm>";
    $$opts{'noyear'}    and $date = "<#month>/<#day>";
    $$opts{'letter'}    and $date = "<#MONTH> <#day>, <#year>";

    my $format = "$date $time";

    $$opts{'notime'}    and $format = $date;
    $$opts{'nodate'}    and $format = $time;

    return Hub::populate( \$format, $props, $names );

}#dateTime

# ------------------------------------------------------------------------------
# fw - fixed-width (default padding is a space)
#
# Warning, many calls to this method is a performance hit!
#
# usage examples:
#
#   Hub::fw( 5, "Hello World" )                  "Hello"
#   Hub::fw( 5, "Hello World", '-clip=0' )       "Hello world"
#   Hub::fw( 5, "Hi" )                           "Hi   "
#   Hub::fw( 5, "Hi", '-align=r' )               "   Hi"
#   Hub::fw( 5, "Hi", '-align=l' )               "Hi   "
#   Hub::fw( 5, "Hi", '-align=c' )               "  Hi "
#   Hub::fw( 5, "Hi", '-repeat' )                "HHHHH"
#   Hub::fw( 5, "Hi", '-pad=x' )                 "Hixxx"
#   Hub::fw( 5, "Hi", '-pad=x', '-align=r' )     "xxxHi"
#
#   Depricated:
#
#   Hub::fw( 5, "Hi", "right" )                  "   Hi"
#   Hub::fw( 5, "Hi", "repeat" )                 "HHHHH"
#   Hub::fw( 5, "Hi", "padding:x" )              "Hixxx"
#   Hub::fw( 5, "Hi", "padding:x", "right" )     "xxxHi"
#
# ------------------------------------------------------------------------------
sub fw {

	my $width       = shift;
	my $the_string  = shift || '';
    my $opts        = Hub::opts( \@_ );
	my $return      = '';

    my $repeat      = Hub::bestof( $$opts{'repeat'},  0 );
    my $justify     = Hub::bestof( $$opts{'align'},   'l' );
	my $padding     = Hub::bestof( $$opts{'pad'},     ' ' );
	my $clip        = Hub::bestof( $$opts{'clip'},    1 );

	while( my $option = shift ) {

        if( $option =~ s/padding://i ) {

            $padding = $option;

		} elsif( $option =~ /repeat/i ) {

            $repeat = 1;

		} elsif( $option =~ /right|center/ ) {

            $justify = substr $option, 0, 1;

        }#if

    }#while

	my $strlen = length( $the_string );
	my $adjust = $width - $strlen;

	if( $clip && $adjust < 0 ) {

		$return = substr( $the_string, 0, $width );

	} else {

		if( $repeat ) {

			$padding = substr( $the_string, 0, 1 );

            $adjust = $width;

            $the_string = "";

		}

		$padding x= $adjust;

		if( $justify =~ /r/ ) {

			$return = $padding . $the_string;

		} elsif( $justify =~ /c/ ) {

            my $mid = length($padding) / 2;

            my $lpad = substr $padding, 0, $mid;

            my $rpad = substr $padding, $mid;

			$return = $lpad . $the_string . $rpad;

		} elsif( $justify =~ /l/ ) {

			$return = $the_string . $padding;
		}

	}
	
	return $return;

}#fw

#-------------------------------------------------------------------------------
# ps
#
# Aka: Proportional Space
#
# Split the given string up into multiple lines which will not exceed the
# specified character width.
#
# Default padding is a space.
#-------------------------------------------------------------------------------
#|test(match)   ps( 10, "this is really short but splits on ten chars" );
#|
#=this is re
#=ally short
#= but split
#=s on ten c
#=hars
#|
#|test(match)   ps( 10, "this is really short but splits on ten chars", 3 );
#|
#=this is re
#=   ally short
#=    but split
#=   s on ten c
#=   hars
#-------------------------------------------------------------------------------
sub ps {

	my $width = shift;
	my $str = shift || return;

    my $opts = {
	    'indent'    => 0,
        'padding'   => ' ',
        'keepwords' => 0,
    };

    Hub::opts( \@_, $opts, '-prefix=--', '-assign=:' );
    Hub::opts( \@_, $opts );

    @_ and $$opts{'indent'} = shift; # backward compatibility

    $$opts{'padding'} x= $$opts{'indent'};

    my $return_string = '';

    if( $$opts{'keepwords'} ) {

        my ($buf,$lastp,$lastbreak) = ();

        while( $str =~ m/\G.*?(\s+)/gs ) {

            my $w = length( $1 );

            my $p = pos($str) - $w;

            if( ($p - $lastbreak) > $width ) {

                $return_string .= "\n$$opts{'padding'}";

                $lastp += $w;

                $lastbreak = $p;

            }#if

            $buf = substr $str, $lastp, ($p - $lastp);

            $buf =~ s/\n/\n$$opts{'padding'}/g;

            $return_string .= $buf;

            $lastp = $p;

        }#while

        $buf = substr $str, $lastp, length($str);

        $buf =~ s/\n/\n$$opts{'padding'}/g;

        $return_string .= $buf;

    } else {

        $return_string .= substr( $str, 0, $width );

        $return_string =~ s/\n/\n$$opts{'padding'}/g;

        my $last_pos = $width;

        while( my $more_stuff = substr( $str, $last_pos, $width ) ) {

            if( $more_stuff =~ s/\n/\n$$opts{'padding'}/g ) {

                $return_string .= $more_stuff;

            } else {

                $return_string .= "\n$$opts{'padding'}$more_stuff";

            }#if

            $last_pos += $width;

            last if $last_pos > length($str);

        }#while

    }#if

    return $return_string;

}#ps

# ------------------------------------------------------------------------------
# fcols STRING, COLS, [OPTIONS]
# 
# Divide text into fixed-width columns.
#
# Where OPTIONS can be:
#
#   --split:REGEX                   # Split on regex REGEX (default '\s')
#   --flow:ttb|ltr                  # Top-to-bottom or Left-to-right (default 'ttb')
#   --pad:NUM                       # Spacing between columns (default 1)
#   --padwith:STR                   # Pad with STR (multiplied by --pad)
#   --width:NUM                     # Force column width (--pad becomes irrelevant)
#   --justify:left|center|right     # Justify within column
#
# Examples:
# 
#   1) print fcols( "A B C D E F G", 4, "-flow=ttb" ), "\n";
#
#       A C E G
#       B D F
#
#   2) print fcols( "a b c d e f g", 4, "-flow=ltr" ), "\n";
#
#       a b c d
#       e f g
#
# ------------------------------------------------------------------------------

sub fcols {

	my $str = shift;
    my $cols = shift || 1;
    my $buf = '';

    my ($splitter,$padding,$colwidth,$padwith,$justify,$flow)
        = ('\s',1,0,' ','left','ttb');

	while( my $opt = shift ) {

        if( $opt =~ /-([a-z]+)=?(.*)$/ ) {

            $1 eq 'split'   and $splitter = $2;
            $1 eq 'pad'     and $padding  = $2;
            $1 eq 'width'   and $colwidth = $2;
            $1 eq 'padwith' and $padwith  = $2;
            $1 eq 'justify' and $justify  = $2;
            $1 eq 'flow'    and $flow     = $2;

        }#if

    }#foreach

    my @items = split /$splitter/, $str;

    if( @items ) {

        my @grid = ();

        my @width = ();

        my ($d,$r) = Hub::intdiv( $#items, $cols );

        my $rowcount = $d ? ($d + 1) : 1;

        my ($colnum,$rownum,$maxlen) = 0;

        if( $flow eq 'ttb' ) {

            foreach my $idx ( 0 .. $#items ) {

                if( $idx && (($idx % $rowcount) == 0) ) {

                    $colnum++;

                    $rownum = $maxlen = 0;

                }#if

                $maxlen = Hub::max($maxlen,length($items[$idx]));

                $width[$colnum] = $maxlen;

                push @{$grid[$rownum++]}, $idx;

            }#foreach

        } elsif( $flow eq 'ltr' ) {

            my $lastbreak = 0;

            foreach my $idx ( 0 .. $#items ) {

                if( $idx >= ($lastbreak + $cols) ) {

                    $rownum++;

                    $colnum = $maxlen = 0;

                    $lastbreak = $idx;

                }#if

                $width[$colnum] = Hub::max($width[$colnum],length($items[$idx]));

                push @{$grid[$rownum]}, $idx;

                $colnum++;

            }#foreach

        }#if

        foreach my $row ( @grid ) {

            $colnum = 0;

            $buf and $buf .= "\n";

            foreach my $idx ( @$row ) {

                my $val = $items[$idx];

                my $w = $colwidth ? $colwidth : $width[$colnum++] + $padding;

                $buf .= fw( $w, $val, "padding:$padwith", $justify );

            }#foreach

        }#foreach

    }#if

    return $buf;

}#fcols

# ------------------------------------------------------------------------------
# indenttext TEXT, NUM, [PADINGCHAR]
# 
# Indent text
# ------------------------------------------------------------------------------

sub indenttext {

    my $num = shift;
    my $str = shift;

    my ($pad,$skipfirst) = (" ",0);

	while( my $opt = shift ) {

        if( $opt =~ /-([a-z]+)=?(.*)$/ ) {

            $1 eq 'skipfirst'   and $skipfirst = 1;

        } else {

            $pad = shift || " "; # backwards compatable

        }#if

    }#foreach

    $pad =~ /\n/ and die "padding cannot contain newlines";

    $pad x= $num;

    my $pos = 0;

    while( $pos > -1 ) {

        $pos = index $str, "\n", $pos;

        my $len = length($str);

        if( $pos > -1 ) {

            if( ($pos + 1) < $len ) {

                substr( $str, $pos, 1, "\n$pad" );

            }#if

            $pos++;

        }#if

    }#while

    return $skipfirst ? $str : "$pad$str";

}#indenttext

# ------------------------------------------------------------------------------
# Hub::dhms( $seconds, $options, $format )
#
# Format the provided number of seconds in days, hours, minutes, and seconds.
#
#   Examples:                                               Returns:
#   ------------------------------------------------------- --------------------
#   Hub::dhms( 10 )                                              00d:00h:00m:10s
#   Hub::dhms( 60 )                                              00d:00h:01m:00s
#   Hub::dhms( 3600 )                                            00d:01h:00m:00s
#   Hub::dhms( 86400 )                                           01d:00h:00m:00s
#   Hub::dhms( 11 )                                              00d:00h:00m:11s
#   Hub::dhms( 71 )                                              00d:00h:01m:11s
#   Hub::dhms( 3671 )                                            00d:01h:01m:11s
#   Hub::dhms( 90071 )                                           01d:01h:01m:11s
#   Hub::dhms( 90071, "--nozeros" )                              1d:1h:1m:11s
#   Hub::dhms( 90071, "--nozeros" )                              1d:1h:1m:11s
#   Hub::dhms( 90071, "--nozeros", "<#d>days <#h>:<#m>:<#s>" )   1days 1:1:11
#   Hub::dhms( 90071, "<#d>days <#h>:<#m>:<#s>" )                01days 01:01:11
#   
# ------------------------------------------------------------------------------
sub dhms {

    my ($seconds,$options,$format) = @_;

    return unless $seconds;

    unless( $format ) {

        $format = $options unless $options =~ /--/;

    }

    my $digit_format = "%02d";

    $options =~ /nozeros/   and $digit_format = "%d";
    $options =~ /MS/        and $format = "<#m>m:<#s>s";
    $options =~ /HMS/       and $format = "<#h>h:<#m>m:<#s>s";

    $format ||= "<#d>d:<#h>h:<#m>m:<#s>s";

    my $dhms = {
        d => 0,
        h => 0,
        m => 0,
        s => 0,
    };

    $$dhms{'d'} = sprintf( $digit_format, int($seconds/86400) );

    $seconds -= ($$dhms{'d'} * 86400);

    $$dhms{'h'} = sprintf( $digit_format, int($seconds/3600) );

    $seconds -= ($$dhms{'h'} * 3600);

    $$dhms{'m'} = sprintf( $digit_format, int($seconds/60) );

    $seconds -= ($$dhms{'m'} * 60);

    $$dhms{'s'} = sprintf( "%02d", $seconds ); # sec don't acknowledge 'nozeros'

    return Hub::populate( \$format, $dhms );

}#dhms

# ------------------------------------------------------------------------------
# populate TEXT, DEFINITIONS+
# 
# Depricated.
# Populate TEXT with DEFINITIONS.
# ------------------------------------------------------------------------------

sub populate {

    my $text = shift || return '';

    my $parser = Hub::mkinst( 'Parser', $text );

    return ${$parser->populate( @_ )};

}#populate

# ------------------------------------------------------------------------------

sub Xpopulate {

    my $text = shift || return "";

    ref($text) eq 'SCALAR' and $text = $$text;

    return $text unless @_;

    my $BEGIN = qq/REF(0x104b82c0)/;

    for( my $idx = 0; $idx <= $#_; $idx++ ) {

        if( $_[$idx] =~ /^--/ ) {

            if( $_[$idx] =~ /--begin=([\W\S\D]+)/ ) {

                $BEGIN = qq/$1/;

            }

            if( $_[$idx] =~ /--end=([\W\S\D]+)/ ) {

                $END = qq/$1/;

            }

            splice @_, $idx--, 1;

        }#if

    }#for

    my $BEGINCHAR = substr $BEGIN, 0, 1;

    my $ENDCHAR = substr $END, 0, 1;

    my $IDLE_DEPTH = $Hub->getcv( 'idle_depth' ) || 10;

    my $MIRROR_DEPTH = $Hub->getcv( 'mirror_depth' ) || 1000;

    my %watch = ();

    my %skip = ();

    my $p = 0; # main file pointer as we progress

    while( $p > -1 ) {

        #
        # find the beginning of a variable definition: '<#'
        #

        $p = index( $text, $BEGIN, $p );

        $watch{$p}++;

        if( $watch{$p} > $IDLE_DEPTH ) {

            my $hint = substr( $text, $p, 20 );

            Hub::lerr( "[Idle > $IDLE_DEPTH] Stopping population at[$p]: $hint..." );

            $p++; # move on

        }#if

        if( $p > -1 ) {

            #
            # find the end of this definition: '>'
            #

            my $p2 = $p + length($BEGIN); # start of the current search

            my $p3 = index( $text, $ENDCHAR, $p2 ); # point of closing

            while( $p3 > -1 ) {

                my $ic = 0; # inner count

                my $im = index( $text, $BEGINCHAR, $p2 ); # inner match
                
                while( ($im > -1) && ($im < $p3) ) {

                    $ic++;

                    $p2 = ($im + 1);

                    $im = index( $text, $BEGINCHAR, $p2 );

                }#while

                last unless $ic > 0;

                for( 1 .. $ic ) {

                    $p3 = index( $text, $ENDCHAR, ($p3 + 1) );

                }#for

            }#while

            if( $p3 > $p ) {

                # inside the '<#' .. '>' marks
                my $inner_str = substr( $text, ($p + length($BEGIN)), ($p3 - ($p + length($BEGIN))) );

                # include the '<#' and '>' marks
                my $outer_str = substr( $text, $p, (($p3 + length($END)) - $p) );

                if( index( $inner_str, $BEGIN ) == 0 ) {

                    # this is an embedded value which should resolve to a name
                    my $inner_val = Hub::populate( \$inner_str, @_ );

                    if( $inner_val ) {

                        # replace

                        # [A]
                        #$text =~ s/$inner_str/$inner_val/g;

                        # [B]
                        substr $text, $p + length($BEGIN), length($inner_str), $inner_val;

                        # [C]
                        #my $left = substr( $text, 0, ($p + 2) );
                        #my $right = substr( $text, ($p + 2) + length($inner_str) );
                        #$text = $left . $inner_val . $right;

                        next;

                    } else {

                        $p += length( $outer_str ); # move on

                        next;

                    }#if

                }#if

                my @params = split /[\s]+/, $inner_str;

                my $name = shift @params;

                my $scope = Hub::attrhash( @params );

                #
                # Maybe there are tweaks which we should perform
                #

                my @tweaks = split /;/, $name;

                $name = pop @tweaks;

                #
                # We have a variable ($name) which may have attributes (%$scope)
                # and we will now look for values.
                #

                my $value = undef;

                if( $skip{$name} ) {

                    $p += 2; # next

                } else {

                    foreach my $h ( @_ ) {

                        if( ref($h) eq "HASH" ) {

                            if( defined $$h{$name} ) {

                                $value = $$h{$name};

                                croak "Unexpected reference" if ref($value) eq 'REF';

                                if( %$scope ) {

                                    my $orig = $value;

                                    $value = Hub::populate( \$value, $scope );

                                    if( $orig eq $value ) {

                                        my $attrs = Hub::hashtoattrs( $scope );

                                        # If the value looks like an html tag, we insert
                                        # the scope as attributes before any other attributes

                                        $value =~ s/^(\s*<[\w]+)/$1 $attrs/;

                                    }#if

                                }#if

                                last;

                            }#if

                        }#if

                    }#foreach

                    if( defined($value) ) {

                        if( (index( $value, "$BEGIN$name$END" ) > -1) ) {

                            # TODO: Look for the NEXT occurance of $name in the @_ hashes

                            Hub::lerr( "Stopping population as value contains key: $name" )
                                unless ($value eq "$BEGIN$name$END");

                            $p += 2; # next

                        } elsif( $watch{$name} && $watch{$name} > $MIRROR_DEPTH ) {

                            Hub::lerr( "Stopping population as mirror depth ($MIRROR_DEPTH) " .
                                "has been reached for: $name" );

                            $p += 2; # next

                        } else {

                            $watch{$name}++;

                            if( @tweaks ) {
                            
                                $value = &_runTweaks( $value, \@_, $scope, @tweaks );

                            }#if

                            # [A]
                            # this cannot be done with tweaks
                            #$text =~ s/$outer_str/$value/g;

                            # [B]
                            substr $text, $p, length($outer_str), $value;

                            # [C]
                            #my $left = substr( $text, 0, $p );
                            #my $right = substr( $text, $p + length($outer_str) );
                            #$text = $left . $value . $right;



                        }#if

                    } elsif( $name =~ /\.html$/ ) {

                        my $template = Hub::mkinst( 'Template', $name );

                        $value = ${$template->populate($scope)};

                        if( defined($value) ) {

                            substr $text, $p, length($outer_str), $value;

                        } else {

                            $skip{$name} = 1;

                            $p += 2; # next

                        }#if

                    } else {

                        if( @tweaks ) {
                        
                            $value = &_runTweaks( $value, \@_, $scope, @tweaks );

                            if( defined($value) ) {

                                substr $text, $p, length($outer_str), $value;

                            } else {

                                $skip{$name} = 1;

                            }#if

                        }#if

                        $skip{$name} = 1;

                        $p += 2; # next

                    }#if

                }#if

            } else {

                # unterminated variable

                my $hint = substr( $text, $p, 20 );

                Hub::lerr( "Unterminated variable ($p3) at char[$p]: $hint..." );

                last;

            }#if
        
        }#if

    }#while

    return $text;

}#Xpopulate

# ------------------------------------------------------------------------------
# _runTweaks - Standard tweaks
#
# Tweaks allow modification to variable values without modifying the original.
#
# No spaces are allowed in the tweak!
#
# Implemented tweaks:
#
#   tr///               # transliterates search chars with replacement chars
#   lc                  # lower case
#   uc                  # upper case
#   lcfirst             # lower case first letter
#   ucfirst             # upper case first letter
#   x=                  # repeat the value so many times
#   nbspstr             # replace spaces with non-breaking ones
#   html                # replace '<' and '>' with '&lt;' and '&gt;'
#   jsstr               # escape quotes and end-of-lines with a backslash
#   num                 # number (will use zero '0' if empty)
#   dt(opts)            # datetime with options (see datetime).
#   Hub::dhms(opts)     # day/hour/min/sec with options (see dhms).
#
#   eq                  # equal
#   ne                  # not equal
#   gt                  # greater than
#   lt                  # less than
#   if                  # is greater than zero (or non-empty string)
#
#   -                   # minus
#   +                   # plus
#   *                   # multiply
#   /                   # divide
#   %                   # mod
#
#   darker(num)         # makes a color darker (default num=0xA)
#   lighter(num)        # makes a color lighter (default num=0xA)
#   rotate_base         # rotates bases (red -> green, green -> blue, blue -> red)
#   inverse             # invert color (like red becomes cyan)
#
# Examples:
#
#   <#lc;v>             # if v is 'HELLO', it becomes 'hello'
#   <#x=5;v>            # if v is '.', it becomes '.....'
#   <#eq(1,2);v>        # the value for 'v' is printed when 1 is equal to 2
#   <#ne(1,2);v>        # the value for 'v' is printed when 1 isn't equal to 2
#   <#eq(2);v>          # the value for 'v' is printed when it is equal to 2
#   <#gt({#c},1);v>     # if v is 's' and c is greater than one, 's' is printed
#
# Tweaks can be chained together, for example:
#
#   <#lc;ucfirst;v>     # if v is "HELLO", it becomes 'Hello'
#   <#gt({#c},1);uc;v>  # if v is "hello" and c is greater than 1, it becomes 'HELLO'
#
# ------------------------------------------------------------------------------

sub _runTweaks {

    my $value   = shift;
    my $data    = shift;
    my $scope   = shift;

    my $key     = join ( '|', $value, @_ );
    my $newval  = undef;

    foreach my $tweak ( @_ ) {

        $value = $newval if defined $newval; # for multiple tweaks

        my ($opr,$opr1,$opr2,$num,$opts) = ();

        if( $tweak =~ s'{#'<#'g ) {

            $tweak =~ s'}'>'g;

            $tweak = Hub::populate( \$tweak, @$data );

            $tweak =~ s/<#.+?>//g; # remove unmatched

        }#if

        if( $tweak =~ /^(lc|uc|ucfirst|lcfirst)$/ ) {

            $newval = eval( "$1( '$value' )" ) if $value;

        } elsif( $tweak =~ /x=([0-9]+)/ ) {

            $newval = $value;

            $newval x= $1;

        } elsif( $tweak =~ /^tr\/(.*?)\/(.*?)\/([a-z]*)$/ ) {

            $newval = $value;

            eval( "\$newval =~ tr/$1/$2/$3" );

        } elsif( $tweak =~ /^if\([\s"']*([^'"]*)[\s"']*\)$/ ) {

            $opr1 = $1;

            $newval = $opr1 ? $value : '';

        } elsif( $tweak =~ /^unless\([\s"']*([^'"]*)[\s"']*\)$/ ) {

            $opr1 = $1;

            $newval = $opr1 ? '': $value ;

        } elsif( $tweak =~ /^(\-|\+|\/|\*|\%)(\d+)$/ ) {

            $opr  = $1;
            $opr1 = $2;

            if( $value =~ /(\d+)/ ) {

                $num = $1;

                my $rslt = eval( "$num $opr $opr1" );

                $newval = $value;

                $newval =~ s/$num/$rslt/;

            } elsif( !$value ) {

                $num  = 0;

                $newval = eval( "$num $opr $opr1" );

            }#if

        } elsif( $tweak =~ /^(eq|ne|gt|lt)\([\s"']*([^'",]+)[\s"']*[,]?[\s"']*([^'",]*)[\s"']*\)$/ ) {

            my $cond = $1;
            $opr1 = $2;
            $opr2 = $3;

            unless( defined $opr2 ) {

                $opr2 = $opr1;
                $opr1 = $value;

            }#unless

            my $true = eval( "\$opr1 $cond \$opr2" );

            $newval = '' unless $true;

        } elsif( $tweak =~ /^(html|nbsp)$/ ) {

            $newval = eval( "&$1( \$value )" );

        } elsif( $tweak =~ /^jsString|jsstr$/ ) {

            $newval = "#JS_STRING#$value#END_JS_STRING#" if $value;

        } elsif( $tweak eq "num" ) {

            $newval = "0" unless $value;

        } elsif( $tweak =~ /^(darker|lighter|rotate_base|inverse)[\(]?(.*?)[\)]?$/ ) {

            my $meth = $1;
            my $step = $2;

            if( $value =~ /^([#])?([a-fA-F\d]{6})$/ ) {

                my $pre  = $1;
                my $srgb = $2;

                my $c = Hub::mkinst( 'Color', $srgb, $step );

                $newval = $pre . eval( "\$c->$meth()" );

            }#if

        } elsif( $tweak =~ /^dt[\(]?(.*?)[\)]?$/ ) {

            $opts = $1;

            $value =~ /^\d+$/ and $newval = datetime( $value, $opts );

        } elsif( $tweak =~ /^dhms[\(]?(.*?)[\)]?$/ ) {

            $opts = $1;

            $value =~ /^\d+$/ and $newval = Hub::dhms( $value, $opts );

        }#if

        $@ and Hub::lerr( "Tweak error ($tweak): " . chomp($@) );

    }#foreach

    return defined $newval ? $newval : $value;

}#_runTweaks

# ------------------------------------------------------------------------------

sub attrhash {

    my @params = @_;

    my $hash = {};

    if( @params ) {

        $$hash{'ARGV'} = join( ' ', @params );

        my $want = 'key';

        my $pk = ''; # the parameter key

        for( my $pp = 0; $pp <= $#params; $pp++ ) {

            my $param = $params[$pp];

            if( $want eq 'key' ) {

                if( $param =~ /=/ ) {

                    my @val = ();

                    ($pk,@val) = split /=/, $param;

                    my $val = join( '=', @val );

                    splice( @params, $pp, 1, $pk, $val );

                    $want = 'value';

                } else {

                    $pk = $param;

                    $pk =~ s/^_(.*)/'_' . lc($1)/e; # system values are all lower case (this is
                                                    # necessary for using as a hash index

                    $want = 'assign';

                }#if

            } elsif( $want eq 'assign' ) {

                if( $param eq '=' ) {

                    $want = 'value';

                } else {

                    $pk .= " $param"; # this allows spaces in keys (bad idea)

                }#if

            } elsif( $want eq 'value' ) {

                if( $$hash{$pk} && ($param =~ /=/) ) {

                    # Either this is an embedded equal sign, or the beginning of a
                    # new parameter.

                    my $count = 0;

                    while( $$hash{$pk} =~ /['"]/g ) { $count++; }
                    
                    if( ($count == 0) || (($count % 2) == 0) ) {
                        
                        # Since there are no quotes, or there are an even number of
                        # quotes, we will presume this is a new key

                        $want = 'key';

                        $pk = '';

                        # We have changed the operation, redo
                        $pp--;

                        next;

                    }#if

                }#if

                $$hash{$pk} and $$hash{$pk} .= " ";

                $$hash{$pk} .= $param;

            }#if

        }#foreach

        foreach my $k ( keys %$hash ) {

            $k eq "ARGV" and next;

            if( $$hash{$k} =~ s/^["']// ) { # trim beg quote
                $$hash{$k} =~ s/["']$//; # trim end quote
            }#if

        }#foreach

    }#if

    return $hash;

}#attrhash

# ------------------------------------------------------------------------------
# hashtoattrs
# 
# Turn the given hash into an key="value" string.
#
#   {
#       'class'     => "foodidly",
#       'name'      => "bobsmith",
#       'height'    => "5px",
#   }
#
# Becomes:
#
#   class="foodidly" name="bobsmith" height="5px"
#
# ------------------------------------------------------------------------------

sub hashtoattrs {

    my $hash    = shift;
    my $iarray  = shift;
    my @attrs   = ();
    my $ignore  = "";

    if( ref($iarray) eq 'ARRAY' ) {

        $ignore = '^' . join( '|', @$iarray ) . '$';

    }#if

    if( ref($hash) eq 'HASH' ) {

        keys %$hash; # reset internal iterator

        while( my($k,$v) = each %$hash ) {

            if( $ignore && ($k =~ $ignore) ) {

                next;

            }#if

            push( @attrs, "$k=\"$v\"" );

        }#while

    }#if

    return join( ' ', @attrs );

}#hashtoattrs

# ------------------------------------------------------------------------------
# trimhtmlstyle
# 
# Remove empty style declarations
# ------------------------------------------------------------------------------

sub trimhtmlstyle {

    my $text = shift || return;

    return Hub::replace( "style=\".*?\"", "s/[\\w\\-]+\\s*:\\s*;//g", $text );

}#trimhtmlstyle

# ------------------------------------------------------------------------------
# trimcss
# 
# Remove empty css properties
# ------------------------------------------------------------------------------

sub trimcss {

    my $text = shift;

    $text =~ s/^\s*\w\+:\s*;$//g;

    return $text;

}#trimcss

# ------------------------------------------------------------------------------
# polish - Remove undefined variables
# ------------------------------------------------------------------------------

sub polish {

    my ($opts,$text) = Hub::opts( \@_ );

    Hub::expect( SCALAR => $text );

    my $BEG = $$opts{'var_begin'} || Hub::PARSER_VAR_BEGIN();
    my $END = $$opts{'var_end'}   || Hub::PARSER_VAR_END();

    $$text =~
        s/$BEG[^$END]*$END[\r]?[\n]?//g;

    return $text;

}#polish

# ------------------------------------------------------------------------------
return 1;

1;
