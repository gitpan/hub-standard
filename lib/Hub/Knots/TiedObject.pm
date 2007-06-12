package Hub::Knots::TiedObject;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

# ------------------------------------------------------------------------------
# _key - Determine which key (public or private) to use
# ------------------------------------------------------------------------------

sub _key {
  my $index = shift;
  local $1;
  return $index =~ /^\*(.*)/ ? ('private',$1) : ('public',$index);
}

# ------------------------------------------------------------------------------
# TIEHASH - Tie interface method
# TIEHASH 'Hub::Knots::TiedObject', $PACKAGE
# ------------------------------------------------------------------------------

sub TIEHASH {
  my $self = shift;
  my $pkg_name = shift;
  my %data = ();
  my $obj = bless {
    'public' => \%data,
    'private' => {
      'tied' => tie(%data, $pkg_name),
      'public' => \%data,
    },
  }, $self;
  return $obj;
}

# ------------------------------------------------------------------------------
# FETCH - Return a value
# ------------------------------------------------------------------------------

sub FETCH {
  my $self = shift;
  my $index = shift;
  my ($namespace,$key) = _key($index);
  return $self->{$namespace}->{$key};
}

# ------------------------------------------------------------------------------
# STORE - Store a value
# ------------------------------------------------------------------------------

sub STORE {
  my $self = shift;
  my $index = shift;
  my $value = shift;
  my ($namespace,$key) = _key($index);
  $self->{$namespace}->{$key} = $value;
}

# ------------------------------------------------------------------------------
# DELETE - Remove a value
# ------------------------------------------------------------------------------

sub DELETE {
  my $self = shift;
  my $index = shift;
  my ($namespace,$key) = _key($index);
  delete $self->{$namespace}->{$key};
}#DELETE

# ------------------------------------------------------------------------------
# CLEAR - Remove all public values
# ------------------------------------------------------------------------------

sub CLEAR {
  $_[0]->{'private'}{'tied'}->CLEAR(@_);
}

# ------------------------------------------------------------------------------
# EXISTS - Boolean test for value
# ------------------------------------------------------------------------------

sub EXISTS {
  my $self = shift;
  my $index = shift;
  my ($namespace,$key) = _key($index);
  exists $self->{$namespace}->{$key};
}

# ------------------------------------------------------------------------------
# FIRSTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub FIRSTKEY {
  $_[0]->{'private'}{'tied'}->FIRSTKEY(@_);
}

# ------------------------------------------------------------------------------
# NEXTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub NEXTKEY {
  $_[0]->{'private'}{'tied'}->NEXTKEY(@_);
}

# ------------------------------------------------------------------------------
# SCALAR - Scalar representation
# ------------------------------------------------------------------------------

sub SCALAR {
  $_[0]->{'private'}{'tied'}->SCALAR(@_);
}

# ------------------------------------------------------------------------------
# UNTIE - Tie interface method
# ------------------------------------------------------------------------------

sub UNTIE {
  my $self = shift;
  my $count = shift || 0;
}

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Tied object

=pod:synopsis

In your class:

  package __Package_Name__;
  use Hub qw(:lib);
  sub new {
    my $self = shift;
    my $class = ref( $self ) || $self;
    my $obj = bless {}, $class;
    tie %$obj, 'Hub::Knots::TiedObject', '__Tie_Package__';
    return $obj;
  }#new

=pod:description

Perl5 does not let one implement tie methods for a normal blessed package.  To 
get around this, the above constructor ties the blessed reference to this
package, providing '__Tie_Package__' as the package which should implement the
tie methods.

=head2 Intention

To transparently provide `tie' methods inline with an existing class.  For
example, one may have a User class which supports several methods, such as
`print', and we wish to update the database on the fly...

    my $user = new User( $conn, 'mary', 'alzxjVT8kR.aU' );
    $user->{'lname'} = "Lopez";
    $user->print();

=head2 Implementation

TiedObject simply provides two hashes for the object: `public' and `private'.
When data members are accessed, the 'public' hash is acted upon.  If the index
begins with an asterisk (*) then the private hash is used.  The only values
currently in the private hash are:

    $self->{'*tied'};         # Points to the reference returned by tie-ing 
                              # '__Tie_Package__' to the public hash.

    $self->{'*public'};       # Points to the public hash


=cut
