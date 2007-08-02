package Hub::Knots::Nest;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;
push our @ISA, qw(Tie::StdHash);

# Cache
our %CACHE = ();
sub _fetch_cached { $CACHE{$_[0]} }
sub _store_cached {
  if(defined $_[1]) {
    _delete_cached($_[0]) if ref($CACHE{$_[0]});
    $CACHE{$_[0]} = $_[1];
  } else {
    $_[1];
  }
}
sub _delete_cached { map {/^$_[0]/ and delete $CACHE{$_}} keys %CACHE; }

# Access
sub FETCH { _fetch_cached($_[1]) || _store_cached($_[1], Hub::getv(@_)); }
sub STORE { Hub::setv(@_); _store_cached($_[1], $_[2]); }
sub DELETE { Hub::delete(@_); _delete_cached($_[1]); }
1;

=pod:summary Nested data structure

=pod:synopsis

=pod:description

=cut
