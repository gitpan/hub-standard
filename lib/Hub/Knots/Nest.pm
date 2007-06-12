package Hub::Knots::Nest;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;
push our @ISA, qw(Tie::StdHash);
sub FETCH { Hub::getv(@_); }
sub STORE { Hub::setv(@_); }
sub DELETE { Hub::delete(@_); }
1;

=pod:summary Nested data structure

=pod:synopsis

=pod:description

=cut
