package Hub::Data::Create;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/subset mkhandler resolve get_save_handler save_data/;

# ------------------------------------------------------------------------------
# subset - Get a subset of hash values
# subset - \%data, $regex
# subset - \%data, $non-regex
# In the second form (only one key can exist) the matching value is returned.
# ------------------------------------------------------------------------------

sub subset {
  my $matches = undef;
  if ($_[1] =~ /^\{(.+)\}$/) {
    my $criteria = $1;
    my @expr = $criteria =~ /(\w+)\s+(.+)\s+(.+)/;
    if (@expr) {
      @$matches = grep {
        isa($_, 'HASH') and
        Hub::compare($expr[1], $_->{$expr[0]}, $expr[2])
      } isa($_[0], 'ARRAY')
        ? @{$_[0]}
        : isa($_[0], 'HASH')
          ? values %{$_[0]}
          : ();
    } else {
      @$matches = isa($_[0], 'HASH')
        ? map {$_[0]->{$_}} grep {/$criteria/} keys %{$_[0]}
        : isa($_[0], 'ARRAY')
          ? grep {/$criteria/} @{$_[0]}
          : undef;
    }
  } else {
    return $_[0]->{$_[1]} if isa($_[0], 'HASH');
    if (isa($_[0], 'ARRAY')) {
      my $key = $_[1];
      @$matches = map {$$_{$key}}
          grep {isa($_, 'HASH') and exists $$_{$key}} @{$_[0]}
    }
  }
  return defined $matches
    ? @$matches > 1
      ? mkinst('Subset', @$matches)
      : pop @$matches
    : undef;
}#subset

# ------------------------------------------------------------------------------
# mkhandler - Get the parser for a given path
# mkhandler $path
# ------------------------------------------------------------------------------
#|test(regex) Hub::mkhandler('/jonnyboy.dat')
#~Hub::Data::HashFile
#|test(regex) Hub::mkhandler('/jonnyboy.data')
#~Hub::Data::HashFile
#|test(regex) Hub::mkhandler('/jonnyboy.hf')
#~Hub::Data::HashFile
#|test(regex) Hub::mkhandler('/data.dat.foo')
#~Hub::Data::File
#|test(regex) use Cwd qw(cwd); Hub::mkhandler(cwd())
#~Hub::Data::Directory
# ------------------------------------------------------------------------------

sub mkhandler {
  my $parser = undef;
  if (-d $_[0]) {
    $parser = 'Directory';
  } else {
    my $hf_types = '(\.hf|\.data?|'.Hub::META_FILENAME.')$';
    $parser = $_[0] =~ /$hf_types/ ? 'HashFile' : 'File';
  }
  confess "Cannot determine parser" unless defined $parser;
  Hub::mkinst($parser, $_[0]);
}#mkhandler

# ------------------------------------------------------------------------------
# resolve - Get a string value for an object
# ------------------------------------------------------------------------------

sub resolve {
  can($_[0], 'get_content')
    ? $_[0]->get_content()
    : can($_[0], 'populate')
      ? ${$_[0]->populate()}
      : ref($_[0]) eq 'SCALAR'
        ? ${$_[0]}
        : $_[0];
}#resolve

# ------------------------------------------------------------------------------
# get_save_handler - Save a node object (traverse upwards when needed)
# get_save_hander $address, [%options]
#
# options:
#
#   -as_addr=1          # Just return the address of the handler
# ------------------------------------------------------------------------------

sub get_save_handler {
  my ($opts,$path) = Hub::opts(\@_, {as_addr=>0});
# my $path = shift;
  my $handler = ();
  # Find the handler for this address
  while (!defined $handler) {
    my $init = $$Hub{$path};  # Ensure it is loaded
    for (Hub::fhandler(Hub::realpath($path))) {
      if (UNIVERSAL::can($_, 'save')) {
        $handler = $_;
      }
    }
    unless (defined $handler) {
      $path = Hub::varparent($path);
      last unless $path;
    }
  }
  return $$opts{'as_addr'} ? $path : $handler;
}#get_save_handler

# ------------------------------------------------------------------------------
# save_data - Save registry data
# save_data $address
#
# Returns -1 if a handler cannot be found.
# ------------------------------------------------------------------------------

sub save_data {
  my ($opts, $address) = Hub::opts(\@_);
  my $handler = Hub::get_save_handler($address);
  unless (defined $handler) {
    warn "Save handler not found for: $address\n";
    return -1;
  }
  $handler->save();
}#save_data

1;
