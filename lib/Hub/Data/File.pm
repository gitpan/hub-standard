package Hub::Data::File;
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
  my $classname = ref( $self ) || $self;
  my $filename = shift || croak "Provide a file name";
  my $obj = Hub::fhandler($filename, $classname);
  unless($obj) {
    $obj = bless {}, $classname;
    tie %$obj, 'Hub::Knots::TiedObject', 'Hub::Knots::SortedHash';
    $obj->{'*filename'} = $filename;
    $obj->{'*contents'} = undef;
    $obj->{'*data'} = undef;
    $obj->{'*delay_reading'} = 1;
    Hub::fattach($filename, $obj);
  }
  return $obj;
}#new

# ------------------------------------------------------------------------------
# delay_reading - Instruct L<FileCache> to delay reading from disk
# ------------------------------------------------------------------------------

sub delay_reading {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  return $$self{'*delay_reading'};
}

# ------------------------------------------------------------------------------
# reload - Callback from L<FileCache> when a read from disk is performed
# ------------------------------------------------------------------------------

sub reload {
  my ($self,$opts,$file) = Hub::objopts(\@_);
  croak "Illegal call to instance method" unless ref($self);
  $self->{'*contents'} = \$file->{'contents'};
  for (keys %$self) { delete $self->{$_}; }
  my $extractor = Hub::mkinst('DataExtractor',
      -template => \$file->{'contents'}, -data => $self);
  $extractor->get_data();
# my $data = $extractor->get_data();
# Hub::merge($self, $data, -overwrite, -prune);
  $$self{'*delay_reading'} = 0;
}

# ------------------------------------------------------------------------------
# get_data - Get a reference to the hash data defined in this file
# ------------------------------------------------------------------------------

sub get_data {
  my $self = shift;
  my $addr = shift;
  croak "Illegal call to instance method" unless ref($self);
  if (!defined $$self{'*contents'}) {
    $$self{'*delay_reading'} = 0;
    my $instance = Hub::finstance($$self{'*filename'});
    Hub::fread($instance);
  }
  return defined $addr ? Hub::subset($self, $addr) : $self;
}#get_data

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
  if (!defined $$self{'*contents'}) {
    $$self{'*delay_reading'} = 0;
    my $instance = Hub::finstance($$self{'*filename'});
    Hub::fread($instance);
  }
  return $$opts{'as_ref'}
    ? $$self{'*contents'}
    : defined $$self{'*contents'}
      ? ${$$self{'*contents'}}
      : '';
}

# ------------------------------------------------------------------------------
# set_content - Set file contents
# ------------------------------------------------------------------------------

sub set_content {
  my $self = shift;
  my $contents = shift;
  croak "Illegal call to instance method" unless ref($self);
  $$self{'*contents'} = ref($contents) ? $contents : \$contents;
}

# ------------------------------------------------------------------------------
# save - Save file contents to disk
# save [options]
#
# options:
#   -priority => 'content'    Content values presceed data values
# ------------------------------------------------------------------------------

sub save {
  my ($opts,$self) = Hub::opts(\@_, {'priority' => 'data'});
  croak "Illegal call to instance method" unless ref($self);
  if (defined $$self{'*contents'}) {
    $self->_merge_data_into_content() unless $$opts{'priority'} eq 'content';
    Hub::writefile($$self{'*filename'}, $self->get_content());
    $$self{'*delay_reading'} = 0;
    Hub::frefresh($$self{'*filename'}, -force);
  }
}

sub _merge_data_into_content {
  my ($opts, $self) = Hub::opts(\@_);
  my $injector = Hub::mkinst('DataInjector', -opts => $opts,
      -template => $self->get_content(-as_ref => 1));
  $self->{'*contents'} = $injector->populate($self->get_data());
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

=pod:summary File

=pod:synopsis

  use Hub qw(:standard);
  my $file = mkinst('File', 'foo.txt');
  print ${$file->get_content()};

=pod:description

A basic file which can be written and saved.  It acts as a singleton
and is integrated into the filecache system (supports refresh).

=head2 Intention

The L<FileSystem::snapshot> method creates an image of the file
system.  Each file is an instance of this class.  We delay reading from disk
until it is necessary.  We do not keep a file handle open.

=cut
