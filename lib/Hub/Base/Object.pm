package Hub::Base::Object;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

# ------------------------------------------------------------------------------
# new - Constructor.
# new [@parameters]
# Parameters are passed to the standard initialization method L<refresh>.
# ------------------------------------------------------------------------------

sub new {
  my $self = shift;
  my $class = ref( $self ) || $self;
  my $obj = bless {}, $self;
  my $tied = tie %$obj, 'Hub::Knots::Object', $obj;
  $obj->{'internal:tied'} = $tied;
  $obj->refresh( @_ );
  return $obj;
}#new

# ------------------------------------------------------------------------------
# daccess - Direct access to member hashes
# daccess $hash_key
# Where $hash_key and be:
#   'public'        Public hash
#   'private'       Private hash
#   'internal'      Internal hash (used to tie things together)
# ------------------------------------------------------------------------------

sub daccess {
    my ($self,$opts) = Hub::objopts( \@_ );
    $self->{'internal:tied'}->_access( @_ );
}#daccess

# ------------------------------------------------------------------------------
# refresh - Return instance to initial state.
# refresh [@parameters]
#
# Interface method, override in your derived class.  Nothing is done in this
# base class.
#
# Called implictly by L<new>, and when persistent interpreters (such as
# mod_perl) would have called L<new>.
# ------------------------------------------------------------------------------

sub refresh {
# my ($self,$opts) = Hub::objopts( \@_ );
}#refresh

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Standard object base class

=pod:synopsis

    package MyPackage;
    use strict;
    use Hub qw(:base);
    push our @ISA, qw(Hub::Base::Object);

=pod:description

This virtual base class ties itself to L<Hub::Knots::Object|Hub::Knots::Object> 
in order to separate private variables from public ones.  That determination is 
made by inspecting the 'caller', such that a derived class can:

    $self->{'name'} = ref($self);

and the consumer of that class can:

    $object->{'name'} = 'Kylee';

without stepping on your private 'name' variable.

=head2 Intention

Using this scheme, one can create an instance of your class and use it just
like a HASH, or an object.  When your class wants to maintain state
information, it may use its self reference as normal.  And when the consumer
wants to iterate through data values, it may:

    while( my($k,$v) = keys %$object ) {

without any of your state variables needing to be parsed-out.

=head2 Bypassing public/private switching

If you wish to set a public member from inside your class, prepend the hash key
with B<public:>

    $self->{'public:name'} = 'Steve';

And, to set a private member on an instance of your class, prepend the hash key
with B<private:>

    $object->{'private:name'} = 'My::Object';

Additionally, you may grab a reference to the underlying public and private
data hashes by using the L<daccess> method:

    my $public = $object->daccess('public');
    croak unless $$public{'name'} eq $$object{'name'};

=cut
