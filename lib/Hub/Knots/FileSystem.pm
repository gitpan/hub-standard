package Hub::Knots::FileSystem;
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

# Infinite recursion will occur unless 'sys' is initialized.
sub TIEHASH  { bless {'sys'=>{}}, $_[0] }

# Access
sub FETCH { _fetch_cached($_[1]) || _store_cached($_[1], Hub::fetch(@_)); }
sub STORE { Hub::store(@_); _store_cached($_[1], $_[2]); }
sub DELETE { Hub::delete(@_); _delete_cached($_[1]); }
1;

=pod:summary Nested data structure which reflects the filesystem

=pod:synopsis

=pod:description

=cut
