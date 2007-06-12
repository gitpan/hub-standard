package Hub::Knots::FileSystem;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;
push our @ISA, qw(Tie::StdHash);
# Infinite recursion will occur unless 'sys' is initialized.
sub TIEHASH  { bless {'sys'=>{}}, $_[0] }
sub FETCH { Hub::fetch(@_); }
sub STORE { Hub::store(@_); }
sub DELETE { Hub::delete(@_); }
1;

=pod:summary Nested data structure which reflects the filesystem

=pod:synopsis

=pod:description

=cut
