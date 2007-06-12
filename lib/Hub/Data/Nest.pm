package Hub::Data::Nest;
use strict;
use Hub qw/:lib/;
our $AUTOLOAD = '';
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

# ------------------------------------------------------------------------------
# new - Constructor.
# ------------------------------------------------------------------------------

sub new {
    my $self = shift;
    my $class = ref( $self ) || $self;
    my $obj = bless {}, $class;
    tie %$obj, 'Hub::Knots::TiedObject', 'Hub::Knots::Nest';
    Hub::merge($$obj{'/'}, $_) for @_;
    return $obj;
}#new

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Nested data object

=pod:synopsis

  use Hub qw(:standard);
  my $nest = mkinst( 'Nest' );
  $$nest{'colors'} = {
    white => 'fff',
    black => '000',
  };
  print '#', $$nest{'colors/black'}, "\n";

=pod:description

This virtual base class ties itself to
L<Hub::Knots::Nest|Hub::Knots::Nest> in order to hook into member 
access routines.

=head2 Intention

We wish to have a single hash which behaves as the root element of a 
hierarchical data structure.

=head2 See also:

L<hubaddr>

=cut
