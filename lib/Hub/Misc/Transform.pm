package Hub::Misc::Transform;
use strict;
use Hub qw/:lib/;
our $VERSION        = '4.00012';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/
    populate
    jsstr
    hashtoattrs
    safestr
    nbspstr
    packcgi
    unpackcgi
/;

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
# packcgi $string|\$string
# 
# Pack characters into those used for passing by the cgi.
# ------------------------------------------------------------------------------

sub packcgi {
  my $str = shift;
  my $ptr = ref($str) eq 'SCALAR' ? $str : \$str;
  $$ptr =~ s/([^A-Za-z0-9_])/sprintf("%%%X", ord($1))/eg;
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
      }
    }
  }
  return $p;
}#unpackcgi

# ------------------------------------------------------------------------------
# nbspstr - Format a string, replacing spaces with '&nbsp;'
# nbspstr - $text
#
# For example:
#
#   nbspstr( "Hello <not html tags> world!" )
#
# would return:
#
#   "Hello&nbsp;<not html tags>&nbsp;World"
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
# populate - Populate template text with values
# populate $text|\$text, \%values [,\%values...] [option]
#
# options:
#
#   -as_ref=1               Return a reference
# ------------------------------------------------------------------------------
#|test(match,mushroom)  populate('mu[#foo]m', { foo => 'shroo' });
#|test(match,SCALAR)    ref(populate('a[#b]c', { b => 'bee' }, '-as_ref=1'));
# ------------------------------------------------------------------------------

sub populate {
  my $opts = Hub::opts(\@_, {'as_ref' => 0});
  my $text = shift or croak( "No template provided" );
  my $parser = Hub::mkinst( 'StandardParser', $text, -opts => $opts );
  my $result = $parser->populate( @_ );
  return $$opts{'as_ref'} ? $result : $$result;
}#populate

# ------------------------------------------------------------------------------
# hashtoattrs - Turn the given hash into an key="value" string.
# hashtoattrs \%hash, [\@ignore_keys]
#
# When C<ignore_keys> is provided, matching hash keys will not be converted.
#
# ------------------------------------------------------------------------------
#|test(match)
#|  my $hash = {
#|    'class'   => "foodidly",
#|    'name'    => "bobsmith",
#|    'height'  => "5px",
#|    'junk'    => "ignore me",
#|  };
#|  hashtoattrs($hash, ['junk']);
#~
#~  class=\"foodidly\" height=\"5px\" name=\"bobsmith\"
# ------------------------------------------------------------------------------

sub hashtoattrs {

  my $hash    = shift;
  my $iarray  = shift;
  my @attrs   = ();
  my $ignore  = '';

  if( ref($iarray) eq 'ARRAY' ) {
    $ignore = '^' . join( '|', @$iarray ) . '$';
  }#if

  if( ref($hash) eq 'HASH' ) {
    keys %$hash; # reset internal iterator
    while( my($k,$v) = each %$hash ) {
      if($ignore && ($k =~ $ignore)) {
        next;
      }#if
      push(@attrs, "$k=\"$v\"") if defined $v;
    }#while
  }#if

  return join( ' ', sort @attrs );

}#hashtoattrs

# ------------------------------------------------------------------------------
return 1;

__END__

=pod:summary Utility methods for transforming data

=pod:synopsis

  use Hub qw(:standard);

=pod:description

=head2 Intention

=cut
