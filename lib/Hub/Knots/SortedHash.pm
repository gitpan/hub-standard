package Hub::Knots::SortedHash;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;
push our @ISA, qw(Tie::StdHash);

# KEYS - Private hash member which holds the sorted list of keys
use constant KEYS => '.keys';

# ITR - Private hash member which holds the index while iterating
use constant ITR  => '.iterator';

sub clear_sort_keys {
  $_[0]->{KEYS} = [];
  $_[0]->{ITR} = 0;
}

sub set_sort_keys {
  my $self = shift;
  $self->{KEYS} = [@_];
  $self->{ITR} = 0;
}

# ------------------------------------------------------------------------------
# TIEHASH - Initialize private hash members
# ------------------------------------------------------------------------------

sub TIEHASH {
  bless {+KEYS => [], +ITR => 0}, $_[0];
}

# ------------------------------------------------------------------------------
# STORE - Add the key to the sorted list
# ------------------------------------------------------------------------------

sub STORE {
#warn " +store: $_[1] = $_[2]\n";
  $_[0]->{$_[1]} = $_[2];
  my $k = $_[1];
  push @{$_[0]->{KEYS}}, $_[1] unless grep { $k eq $_ } @{$_[0]->{KEYS}};
}

sub FETCH {
#warn " +fetch: $_[1] is $_[0]->{$_[1]}\n";
  $_[0]->{$_[1]};
}

# ------------------------------------------------------------------------------
# FIRSTKEY - Set iterator to zero and return the first key in the sorted list
# ------------------------------------------------------------------------------

sub FIRSTKEY {
  $_[0]->{ITR} = 0;
  $_[0]->{KEYS}[0];
}

# ------------------------------------------------------------------------------
# NEXTKEY - Increment the iterator return the key at that index
# ------------------------------------------------------------------------------

sub NEXTKEY {
  $_[0]->{ITR}++;
  my $k = $_[0]->{KEYS}[$_[0]->{ITR}];
  $k;
}

# ------------------------------------------------------------------------------
# DELETE - Remove the key from the sorted list
# ------------------------------------------------------------------------------

sub DELETE {
  delete $_[0]->{$_[1]};
  unless($_[1] eq KEYS) {
    my $p = 0;
    my $k = $_[1];
    for (@{$_[0]->{KEYS}}) {
      $_ eq $k and last;
      $p++;
    }
    splice @{$_[0]->{KEYS}}, $p, 1;
  }
}

1;

__END__

=pod:summary Sorted Hash

=pod:synopsis

=test(match,Apple;Banana;Pear)

  my %h = ();
  tie %h, 'Hub::Knots::SortedHash';
  $h{'first'} = "Apple";
  $h{'second'} = "Banana";
  $h{'third'} = "Pear";
  join ';', values %h;

=pod:description

The functions C<keys>, C<values>, and C<each> will return the hash entries
in the order they were created.

=cut
