package Hub::Perl::Compare;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2

use strict;
use warnings;
use Hub qw(:lib);

our $VERSION        = '3.01048';

our @EXPORT         = qw();

our @EXPORT_OK      = qw(compare);

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

    # Extensions

    'eqic'      => sub { lc($_[0]) eq lc($_[1]); },
    'neic'      => sub { lc($_[0]) ne lc($_[1]); },

);

# ------------------------------------------------------------------------------
# compare - Wrapper for Perl's internal comparison operators.
#
# compare OPERATOR, LEFT_OPERAND, RIGHT_OPERAND
#
# OPERATOR's:
#
#   eq ne lt le gt ge == != < > <= >=
#
# Extended OPERATOR's:
#
#   eqic    Equal ignore case
#   neic    Not-equal ignore case
#
# The purpose here is twofold: a) support runtime comparison when the operator
# is held as string; and b) behave like Perl does when warnings are disabled.
# ------------------------------------------------------------------------------
#|test(true)    compare('eq','',undef);
#|test(true)    compare('eq','abc','abc');
#|test(true)    compare('ne','abc','Abc');
#|test(false)   compare('eq','abc',undef);
#|test(true)    compare('!~','abc','A');
#|test(true)    compare('=~','abc','a');
#|test(true)    compare('==',1234,1234);
#|test(true)    compare('>=',1234,1234);
#|test(true)    compare('eqic','abc','Abc');
#|test(true)    compare('==',undef,undef);
#|test(true)    compare('==',0,undef);
#|test(match)   my @numbers = ( 20, 1, 10, 2 );
#|              join ';', sort { &compare('<=>',$a,$b) } @numbers;
#~              1;2;10;20
# ------------------------------------------------------------------------------

sub compare {

    my $comparator = shift or croak 'Comparator required';

    no warnings;

    &{$COMPARISONS{$comparator}};

}#compare

# ------------------------------------------------------------------------------

'???';
