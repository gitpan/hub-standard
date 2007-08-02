package Hub::Knots::Object;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

# ------------------------------------------------------------------------------
# _access - Direct access to members
# ------------------------------------------------------------------------------

sub _access {
  my $self = shift;
  my $index = shift;
  return $self->{$index};
}#_access

# ------------------------------------------------------------------------------
# _keyname - Determine which key (public or private) to use
# ------------------------------------------------------------------------------

sub _keyname {
  my $self = shift;
  my $index = shift;
  my $datakey = defined $index &&
    $$index =~ s/^(internal|public|private):// ? $1 : ();
  my $called_from = caller(1);
  $datakey ||= $self->{'internal'}{'impl'}->isa($called_from) ? 'private' : 'public';
  return $datakey;
}#_keyname

# ------------------------------------------------------------------------------
# TIEHASH - Tie interface method
# ------------------------------------------------------------------------------

sub TIEHASH {
  my $self = shift;
  my $impl = shift;
  my $obj = bless {
    'internal'  => { impl => $impl }, # neither public or private
    'public'    => {},
    'private'   => {},
  }, $self;
  return $obj;
}#TIEHASH

# ------------------------------------------------------------------------------
# FETCH - Tie interface method
# ------------------------------------------------------------------------------

sub FETCH {
  my $self = shift;
  my $index = shift;
  my $datakey = $self->_keyname( \$index );
  return $index ? $self->{$datakey}->{$index} : $self->{$datakey};
}#FETCH

# ------------------------------------------------------------------------------
# STORE - Tie interface method
# ------------------------------------------------------------------------------

sub STORE {
  my $self = shift;
  my $index = shift;
  my $value = shift;
  my $datakey = $self->_keyname( \$index );
  $index ? $self->{$datakey}->{$index} = $value : $self->{$datakey} = $value;
}#STORE

# ------------------------------------------------------------------------------
# DELETE - Tie interface method
# ------------------------------------------------------------------------------

sub DELETE {
  my $self = shift;
  my $index = shift;
  my $datakey = $self->_keyname( \$index );
  delete $self->{$datakey}->{$index};
}#DELETE

# ------------------------------------------------------------------------------
# CLEAR - Tie interface method
# ------------------------------------------------------------------------------

sub CLEAR {
  my $self = shift;
  my $datakey = $self->_keyname();
  my @reset = keys %{$self->{$datakey}};
  map { delete $self->{$datakey}->{$_} } keys %{$self->{$datakey}};
}#CLEAR

# ------------------------------------------------------------------------------
# EXISTS - Tie interface method
# ------------------------------------------------------------------------------

sub EXISTS {
  my $self = shift;
  my $index = shift;
  my $datakey = $self->_keyname( \$index );
  exists $self->{$datakey}->{$index};
}#EXISTS

# ------------------------------------------------------------------------------
# FIRSTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub FIRSTKEY {
  my $self = shift;
  my $datakey = $self->_keyname();
  my @reset = keys %{$self->{$datakey}};
  each %{$self->{$datakey}};
}#FIRSTKEY

# ------------------------------------------------------------------------------
# NEXTKEY - Tie interface method
# ------------------------------------------------------------------------------

sub NEXTKEY {
  my $self = shift;
  my $lastindex = shift;
  my $datakey = $self->_keyname();
  each %{$self->{$datakey}};
}#NEXTKEY

# ------------------------------------------------------------------------------
# SCALAR - Tie interface method
# ------------------------------------------------------------------------------

sub SCALAR {
  my $self = shift;
  my $datakey = $self->_keyname();
  scalar %{$self->{$datakey}};
}#SCALAR

# ------------------------------------------------------------------------------
# UNTIE - Tie interface method
# ------------------------------------------------------------------------------

sub UNTIE {
  my $self = shift;
  my $count = shift || 0;
  my $datakey = $self->_keyname();
}#UNTIE

1;

__END__

=pod:summary Nested data structure

=pod:synopsis

=pod:description

=cut
