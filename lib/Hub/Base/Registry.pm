package Hub::Base::Registry;
use strict;
use Hub qw/:lib :config/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/ROOT_KEYS/;

use constant ROOT_KEYS => qw(sys conf session cgi);

# ------------------------------------------------------------------------------
# new - Constructor
# ------------------------------------------------------------------------------

sub new {
	my $self = shift;
	my $classname = ref($self) || $self;
	$self = bless {}, $classname;
  tie %$self, 'Hub::Knots::TiedObject', 'Hub::Knots::FileSystem';
  return $self;
}#new

# ------------------------------------------------------------------------------
# run - Main action method
# run \&callback_subroutine
# ------------------------------------------------------------------------------

sub run {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  my $sub = shift;
  unless(defined &$sub) {
    croak "$0: Callback subroutine ($sub) not defined";
  }
  $self->bootstrap();
  my $ret = &$sub(@_);
  my $err = $@;
  $self->finish();
  croak $err if $err;
  return $ret;
}#run

# ------------------------------------------------------------------------------
# bootstrap - Bootstrap the scope for this thread
# ------------------------------------------------------------------------------

sub bootstrap {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  # System environment
  my @argv = (@ARGV);
  # Remove virtual containers
  do {delete $$self{"/$_"}} for qw(sys/.* conf session cgi);
  $$self{'/sys'} = {}; # Clear
  $$self{'/sys/OPTS'} = Hub::cmdopts(\@argv);
  $$self{'/sys/ARGV'} = \@argv;
  $$self{'/sys/ENV'} = Hub::cpref(\%ENV);
  $$self{'/sys/ENV/WORKING_DIR'} ||= cwd();
  # Configuration
  my $conf = Hub::CONF_BASE;
  if ($Hub::TAG_MAP{'Webapp'}) {
    $conf = Hub::merge($conf, Hub::CONF_WEBAPP, -overwrite, -copy)
  }
  my $conf_file = Hub::bestof($$Hub{'/sys/ENV/CONF_FILE'}, '.conf');
  if (-e $conf_file) {
    my $hf = Hub::mkinst('HashFile', $conf_file);
    $conf = Hub::merge($conf, $hf->get_data(), -overwrite, -copy);
  }
  $$self{'/conf'} = $conf;
  # Directories encountered first have prescedence
  my @root_keys = ();
  foreach my $var ('/sys/ENV/BASE_DIR', '/sys/ENV/WORKING_DIR') {
    my $dir = $$self{$var};
    if (defined $dir) {
      chdir $dir;
      push @root_keys, $self->_root_overlay($dir);
    }
  }
  # Clear
  foreach my $k (keys %$self) {
    unless (grep { $_ eq $k } (@root_keys, ROOT_KEYS)) {
      delete $$self{$k};
    }
  }
  # Our dot directory is the working (not base) directory
  $$self{'.'} = Hub::mkhandler($$self{'/sys/ENV/WORKING_DIR'});
}#bootstrap

sub _root_overlay {
  my ($self, $dir) = @_;
  return () unless defined $dir;
  my @root_files = Hub::readdir($dir);
  foreach my $name (@root_files) {
    next if grep {$_ eq $name} ROOT_KEYS; # don't overwrite the above
    my $init = $$self{$name}; # creates the handler
  }
  return @root_files;
}

# ------------------------------------------------------------------------------
# finish - The caller's script has completed
# ------------------------------------------------------------------------------

sub finish {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
}#finish

# ------------------------------------------------------------------------------
# resolve - Return a scalar value of a node
# resolve $key
# Because some nodes (like files) can be pointers to certain resources, this 
# method will return their final contents.
# ------------------------------------------------------------------------------

sub resolve {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  my $key = shift or confess "Provide a hash key";
  my $unresolved = $$self{$key};
  if (UNIVERSAL::isa($unresolved, 'Hub::Data::File')) {
    return $unresolved->get_content();
  } else {
    return $unresolved;
  }
}#resolve

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Runtime symbol storage and in-memory reflection of the filesystem

=pod:synopsis

  use Hub qw(:standard);
  use Data::Dumper qw(Dumper);
  callback(&main);
  sub main {
    Dumper($Hub);
  }

=pod:description

This class is used internally and represents a runtime instance.  The symbol
C<$Hub> is an instance of this package.

=cut
