package Hub::Perl::Compare;
use strict;
use warnings;
use Hub qw(:lib);
our $VERSION = '4.00012';
our @EXPORT = qw();
our @EXPORT_OK = qw(
  compare
  sort_compare
  is_bipolar
);

# ------------------------------------------------------------------------------
# %COMPARISIONS - Comparison routines
# ------------------------------------------------------------------------------

our %COMPARISONS    = (

    'eq'        => sub { $_[0] eq $_[1]; },
    'ne'        => sub { $_[0] ne $_[1]; },
    'lt'        => sub { $_[0] lt $_[1]; },
    'le'        => sub { $_[0] le $_[1]; },
    'gt'        => sub { $_[0] gt $_[1]; },
    'ge'        => sub { $_[0] ge $_[1]; },

    '=~'        => sub { $_[0] =~ $_[1]; },
    '!~'        => sub { $_[0] !~ $_[1]; },

    '=='        => sub { $_[0] == $_[1]; },
    '!='        => sub { $_[0] != $_[1]; },
    '<'         => sub { $_[0] <  $_[1]; },
    '>'         => sub { $_[0] >  $_[1]; },
    '<='        => sub { $_[0] <= $_[1]; },
    '>='        => sub { $_[0] >= $_[1]; },

    '<=>'       => sub { $_[0] <=> $_[1]; },
    'cmp'       => sub { $_[0] cmp $_[1]; },

    # Extensions (above and beyond perl operators)

    'eqic'      => sub { lc($_[0]) eq lc($_[1]); },
    'neic'      => sub { lc($_[0]) ne lc($_[1]); },

    # Multiple of
    'mult-of'   => sub { ($_[0] >= $_[1]) && ($_[0] % $_[1] == 0); },

);

# ------------------------------------------------------------------------------
# compare - Wrapper for Perl's internal comparison operators.
# compare $operator, $left_operand, $right_operand
#
# Support runtime comparison when the operator is held as a scalar.
#
# Where $operator may be one of:
#
#   eq        Equal
#   ne        Not equal
#   lt        Less than
#   le        Less than or equal
#   gt        Greater than
#   ge        Greater than or equal
#   ==        Numeric equal
#   !=        Numeric not equal
#   <         Numeric less than
#   >         Numeric greater than
#   <=        Numeric less than or equal
#   >=        Numeric greater than or equal
#   eqic      Equal ignoring case
#   neic      Not equal ignoring case
#   mult-of   Multple of
# ------------------------------------------------------------------------------
#|test(false)   compare('eq','',undef);
#|test(true)    compare('eq','abc','abc');
#|test(true)    compare('ne','abc','Abc');
#|test(false)   compare('eq','abc',undef);
#|test(true)    compare('!~','abc','A');
#|test(true)    compare('=~','abc','a');
#|test(true)    compare('==',1234,1234);
#|test(true)    compare('>=',1234,1234);
#|test(true)    compare('eqic','abc','Abc');
#|test(true)    compare('==',undef,undef);
#|test(false)   compare('==',0,undef);
#|test(match)   my @numbers = ( 20, 1, 10, 2 );
#|              join ';', sort { &compare('<=>',$a,$b) } @numbers;
#~              1;2;10;20
# ------------------------------------------------------------------------------

sub compare {
  my $comparator = shift or croak 'Comparator required';
  return defined $_[0]
    ? defined $_[1]
      ? &{$COMPARISONS{$comparator}}
      : 0
    : !defined $_[1]
      ? 1
      : 0;
}#compare

# ------------------------------------------------------------------------------
# sort_compare - Compare for sorting, returning 1, 0 or -1
# See also L<compare>
# ------------------------------------------------------------------------------

sub sort_compare {
  my $comparator = shift or croak 'Comparator required';
  return defined $_[0]
    ? defined $_[1]
      ? &{$COMPARISONS{$comparator}}
      : 1
    : defined $_[1]
      ? -1
      : 0;
}#sort_compare

# ------------------------------------------------------------------------------
# is_bipolar - Test to see if this is a blessed document/view object
# ------------------------------------------------------------------------------

sub is_bipolar {
  can($_[0], 'get_data') && can($_[0], 'get_content');
}#is_bipolar

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Scalar value comparisons

=pod:synopsis

  # usage: this_script.pl operator val1 val2
  use Hub qw(:standard);
  print compare(@ARGV) ? "True\n" : "False\n";

=pod:description

Efficient routine to compare scalar values when the operator is variable.

=cut
