package Hub::Base::Registry;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw//;

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
  $$self{'/sys/OPTS'} = Hub::cmdopts(\@argv);
  $$self{'/sys/ARGV'} = \@argv;
  $$self{'/sys/ENV'} = Hub::cpref(\%ENV);
  $$self{'/sys/ENV/WORKING_DIR'} ||= cwd();
  # Configuration
  my $conf_file = Hub::bestof($$Hub{'/sys/ENV/CONF_FILE'}, '.conf');
  if (-e $conf_file) {
    my $hf = Hub::mkinst('HashFile', $conf_file);
    $$self{'/conf'} = $hf->get_data();
  }
  # Stub out each root file or directory
  my $workdir = $$self{'/sys/ENV/WORKING_DIR'};
  foreach my $name (Hub::readdir($workdir)) {
    next if grep {$_ eq $name} qw(sys conf); # don't overwrite the above
    my $init = $$self{$name}; # creates the handler
#   $$self{$name} = Hub::mkhandler($name);
  }
}#bootstrap

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
