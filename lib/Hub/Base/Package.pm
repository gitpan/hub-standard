package Hub::Base::Package;
use strict;
use Hub qw/:lib/;
our ($AUTOLOAD);
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw/modexec/;
use constant RTMOD_NAME => 'module.pm';   # Default runtime module name
use constant RTMOD_INVOKE => 'run';       # Default runtime invokation method

# ------------------------------------------------------------------------------
# modexec - Execute runtime module
# ------------------------------------------------------------------------------

sub modexec {
  my $opts = Hub::opts(\@_, {
    filename  => RTMOD_NAME,
    method    => RTMOD_INVOKE,
  });
  my $args = shift || [];
  my $path = Hub::srcpath($$opts{'filename'});
  if ($path) {
    my $pkg = mkinst('Package', $path);
    return $pkg->call($$opts{'method'}, @$args);
  } else {
    confess ("Module not found: $$opts{'filename'}");
  }#if
}#modexec

# ------------------------------------------------------------------------------
# new - Constructor
# new $module_filename
# This creates a singleton adapter of the perl module
# ------------------------------------------------------------------------------

sub new {
	my $self = shift;
  my $path = shift or confess "Filename required";
	my $classname = ref($self) || $self;
  my $filename = Hub::abspath($path)
    or confess "Module does not exist: $path";
  my $object = Hub::fhandler($filename, $classname);
  unless( $object ) {
    my $workdir = Hub::getpath($filename);
    my $package = $filename;
    $package =~ s/[\s\W]/_/g;
    $self = {
      'filename' => $filename,
      'package'  => $package,
      'workdir'  => $workdir,
    };
    $object = bless $self, $classname;
    Hub::fattach($filename, $object);
  }#unless
  return $object;
}#new

# ------------------------------------------------------------------------------
# call - Call a method in the underlying package
# call $method, [@parameters]
# Note that wrapped methods do not pass the 'defined' test
# ------------------------------------------------------------------------------

sub call {
  my $self = shift;
  my $classname = ref($self) or croak "Illegal call to instance method";
  my $method = shift or croak "Method required";
  my $sub = $$self{'package'} . '::' . $method;
  no strict 'refs';
  Hub::pushwp($$self{'workdir'});
  my $result = &$sub(@_);
  Hub::popwp();
  return $result;
}#call

# ------------------------------------------------------------------------------
# AUTOLOAD - Proxy the call to the underlying package
# ------------------------------------------------------------------------------

sub AUTOLOAD {
  my $self = shift;
  my $classname = ref($self) or croak "Illegal call to instance method";
  my $name = $AUTOLOAD;
  if( $name =~ /::(\w+)$/ ) {
    return $self->call($1, @_);
  } else {
    die "Unhandled AUTOLOAD name";
  }#if
}#AUTOLOAD

# ------------------------------------------------------------------------------
# DESTROY - Defining this function prevents it from being searched in AUTOLOAD
# ------------------------------------------------------------------------------

sub DESTROY {
}#DESTROY

# ------------------------------------------------------------------------------
# reload - Callback method from L<Hub::Data::FileCache::fattach>
# reload $file_instance
# Called implicty on the first attachment or when the file has been modified
# on disk.  Not to be used unless you override L<Hub::Data::FileCache>.
#
# Special patterns:
#
#   package PACKAGE;          # for dynamically allocating based on full path
#
#   import 'foo.pm' as 'FOO'; # for including dynamic packages
#   FOO::method();
# ------------------------------------------------------------------------------

sub reload {
  my $self = shift;
  my $classname = ref($self) or croak "Illegal call to instance method";
  my $instance = shift or croak "FileCache file-instance hash required";
#warn "file=$self->{'filename'}\n";
#warn " pkg=$self->{'package'}\n";
  my $contents = $$instance{'contents'};
  my %imports = ();
  Hub::pushwp($$self{'workdir'});
  $contents =~ s/\bPACKAGE\b/$self->{'package'}/mg;
  $contents =~ s/^\s*IMPORT\s+['"]([^'"]+)['"]\s+AS\s+['"]([A-Z]+)['"];\s*$/
  my $fn = $1;
  my $alias = $2;
  my $pkg = Hub::srcpath("$fn");
  $pkg =~ s#[\s\W]#_#g;
  $imports{$alias} = $pkg;
  "Hub::mkinst('Package', Hub::srcpath('$fn'));\n"/mgei;
  foreach my $k (keys %imports) {
    $contents =~ s/\b$k\b/$imports{$k}/mg;
  }
  local $!;
  eval $contents;
  Hub::popwp();
  if( $@ ) {
    my $error = $@;
    my ($eval_number) = $error =~ s/\(eval (\d+)\)/$$instance{'filename'}/;
    die $error;
  }#if
}#reload


# ------------------------------------------------------------------------------
1;
