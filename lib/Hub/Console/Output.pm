package Hub::Console::Output;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
  fw
  ps
  fcols
  indenttext
/;

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
#|
#|test(match)   ps( 10, "this  is really short but splits on ten chars", -keepwords );
#|
#=this  is 
#=really 
#=short but 
#=splits on 
#=ten 
##-------------------------------------------------------------------------------

sub ps {
	my $width = shift;
	my $str = shift || return;
  my $opts = {
    'indent'    => 0,
    'padding'   => ' ',
    'keepwords' => 0,
  };
  Hub::opts(\@_, $opts, '-prefix=--', '-assign=:');
  Hub::opts(\@_, $opts);
  @_ and $$opts{'indent'} = shift; # backward compatibility
  $$opts{'padding'} x= $$opts{'indent'};
  my $return_string = '';
  if( $$opts{'keepwords'} ) {
    my ($p, $beg, $end) = (0, 0, 0);
    while ($p > -1) {
      $p = Hub::indexmatch($str, '\s', $end);
      if (($p - $beg) > $width) {
        $return_string .= "\n";
        $beg = $end;
      }
      $return_string .= substr $str, $end, (($p - $end) +1);
      $end = $p + 1;
    }
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
# indenttext - Indent text
# indenttext $count, $text, [options]
#
# options:
#
#   -skip_first=1       Do not indent the first line
#   -pad=CHAR           Use this padding character for indenting
# ------------------------------------------------------------------------------
#|test(match) indenttext(4,"Hello\nWorld")
#=    Hello
#=    World
# ------------------------------------------------------------------------------

sub indenttext {
  my ($opts,$num,$str) = Hub::opts(\@_,{'pad' => ' ', 'skip_first' => 0});
  $$opts{'pad'} =~ /\n/ and die "padding cannot contain newlines";
  $$opts{'pad'} x= $num;
  my $pos = 0;
  while ($pos > -1) {
    $pos = index $str, "\n", $pos;
    my $len = length($str);
    if ($pos > -1) {
      if (($pos + 1) < $len) {
        substr ($str, $pos, 1, "\n$$opts{'pad'}");
      }
      $pos++;
    }
  }
  return $$opts{'skip_first'} ? $str : "$$opts{'pad'}$str";
}#indenttext

1;

__END__

=pod:summary Utility methods console output

=pod:synopsis

  use Hub qw(:standard);

=pod:description

=head2 Intention

=cut
