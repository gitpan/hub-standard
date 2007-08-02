package Hub::Data::HashFile;
use strict;
use Hub qw/:lib :console/;

our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

# ------------------------------------------------------------------------------
# new - Constructor.
# ------------------------------------------------------------------------------

sub new {
  my $self = shift;
  my $classname = ref($self) || $self;
  my $path = shift or croak "Provide a path";
  my $obj = Hub::fhandler($path, $classname);
  unless($obj) {
    $obj = bless {}, $classname;
    tie %$obj, 'Hub::Knots::TiedObject', 'Hub::Knots::SortedHash';
    $obj->{'*path'} = $path;
    $obj->{'*stats'} = stat($path);
    Hub::fattach($path, $obj);
  }
  return $obj;
}

# ------------------------------------------------------------------------------
# reload - Callback from L<FileCache> when a read from disk is performed
# ------------------------------------------------------------------------------

sub reload {
  my ($self,$opts,$file) = Hub::objopts(\@_);
  croak "Illegal call to instance method" unless ref($self);
  for (keys %$self) { delete $self->{$_}; }
  Hub::hparse(\$file->{'contents'}, -into => $self, -hint => $self->{'*path'});
#warn "data:\n\n", Hub::hprint($self), "\n\n";
#warn "contents:\n\n", $file->{'contents'}, "\n\n";
}

# ------------------------------------------------------------------------------
# get_data - Return data structure
# ------------------------------------------------------------------------------

sub get_data {
  my $self = shift;
  my $index = shift;
  croak "Illegal call to instance method" unless ref($self);
  if (defined $index) {
    return Hub::subset($self->{'*public'}, $index);
  }
  return $self;
}

# ------------------------------------------------------------------------------
# set_data - Set data
# ------------------------------------------------------------------------------

sub set_data {
  my ($opts,$self,$value) = Hub::opts(\@_, {'index' => '/'});
  croak "Illegal call to instance method" unless ref($self);
  if ($$opts{'index'} eq '/') {
    die "Provide a hash value for the root element" unless isa($value, 'HASH');
    %{$self->{'*public'}} = %{$value};
  } else {
    Hub::setv($self->{'*public'}, $$opts{'index'}, $value);
  }
}

# ------------------------------------------------------------------------------
# get_content - Return file contents
# get_content [options]
#
# options:
#
#   -as_ref => 1         # Return a reference
# ------------------------------------------------------------------------------

sub get_content {
  my ($opts, $self) = Hub::opts(\@_, {'as_ref' => 0});
  croak "Illegal call to instance method" unless ref($self);
  return Hub::hprint($self, -as_ref => $$opts{'as_ref'});
}

# ------------------------------------------------------------------------------
# set_content - Set file contents
# ------------------------------------------------------------------------------

sub set_content {
  my $self = shift;
  my $contents = shift;
  croak "Illegal call to instance method" unless ref($self);
  for (keys %$self) { delete $self->{$_}; }
  Hub::hparse(ref($contents) ? $contents : \$contents, -into => $self);
}

# ------------------------------------------------------------------------------
# save - Save file contents to disk
# ------------------------------------------------------------------------------

sub save {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  Hub::writefile($self->{'*path'}, $self->get_content(-asref => 1));
  Hub::frefresh($self->{'*path'}, -force);
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

=pod:summary Refactor of HashFile

=pod:synopsis

=pod:description

=cut
