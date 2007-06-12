package Hub::Data::Subset;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my $object = bless [], $class;
  push @$object, @_;
  return $object;
}

sub get_data {
  my $self = shift;
  my $index = shift;
  croak "Illegal call to instance method" unless ref($self);
  Hub::subset($self, $index);
#warn "refining: $index ?? $item\n";
}

sub get_content {
  my $self = shift;
  my $index = shift;
  croak "Illegal call to instance method" unless ref($self);
  return @$self;
}

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Self cropping set of data

=pod:synopsis

=pod:description

=cut
