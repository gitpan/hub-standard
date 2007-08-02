package Hub::Data::Directory;
use strict;
use Hub qw/:lib/;
our $AUTOLOAD = '';
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

sub new {
  my $self = shift;
  my $classname = ref($self) || $self;
  my $path = shift or croak "Provide a path";
  $path = Hub::abspath($path, -must_exist);
  return unless defined $path;
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

sub get_data {
  my $self = shift;
  my $index = shift;
  croak "Illegal call to instance method" unless ref($self);
  if (defined $index) {
    $self->{$index} = Hub::mkhandler("$self->{'*path'}/$index")
      if -e "$self->{'*path'}/$index" && !defined $self->{$index};
    return $index =~ /^\{(.*)\}$/
      ? mkinst('Subset', # map {$self->{'*path'}.'/'.$_}
          grep {/$1/} keys %{$self->{'*public'}})
      : $self->{$index};
  }
  return $self;
}

sub get_content {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  return $self;
}

sub reload {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  my $instance = shift;
  my $dir = $instance->{'filename'};
#warn "-loading: $dir\n";
  # Sorted list
  my @list = sort grep {!/^\./} @{$instance->{'contents'}};
  Hub::sort_dir_list($dir, \@list);
  # Stub out each entry
  $self->{'*tied'}->set_sort_keys(@list);
  $self->{$_} ||= undef for (@list);
  # Prune deleted files from our list
  foreach my $k (keys %$self) {
    delete $self->{$k} unless grep {$_ eq $k} @list;
  }
}

sub set_sort_order {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  my $sort_order = shift;
  croak "Provide an array reference" unless isa($sort_order, 'ARRAY');
  my $md_filename = $self->{'*path'} . '/' . Hub::META_FILENAME;
  my $md = $$Hub{Hub::getaddr($md_filename)};
  $md = mkinst('HashFile', $md_filename) unless (defined $md);
  $md->{'sort_order'} = $sort_order;
  $md->save();
  Hub::frefresh($self->{'*path'}, -force);
}

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary File system directory

=pod:synopsis

=pod:description

=cut
