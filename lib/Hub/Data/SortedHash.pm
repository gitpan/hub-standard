package Hub::Data::SortedHash;
use strict;
use Hub qw/:lib/;
our $AUTOLOAD = '';
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

sub new {
  my $self = shift;
  my $classname = ref($self) || $self;
  my $obj = bless {}, $classname;
  tie %$obj, 'Hub::Knots::TiedObject', 'Hub::Knots::SortedHash';
  return $obj;
}

sub set_sort_order {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  my $sort_order = shift;
  croak "Provide an array reference" unless isa($sort_order, 'ARRAY');
  $self->{'*tied'}->set_sort_keys(@$sort_order);
}

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Sorted Hash Object

=pod:synopsis

=pod:description

=cut
