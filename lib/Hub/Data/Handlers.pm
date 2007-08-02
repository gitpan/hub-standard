package Hub::Data::Handlers;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/fetch store getv setv delete/;

# ------------------------------------------------------------------------------
# fetch - Get a nested value whose parent may need to be loaded from disk
# fetch \%data, $index
# ------------------------------------------------------------------------------

sub fetch {
  my $result = _traverse($_[0], $_[1]);
  _transcend($result) if (@{$result->{'not_found'}});
  $result->{'value'};
}#fetch

# ------------------------------------------------------------------------------
# store - Store a nested value whose parent may need to be loaded from disk
# store \%data, $index, ?value
# ------------------------------------------------------------------------------

sub store {
  my $result = _traverse($_[0], $_[1]);
  _transcend($result) if (@{$result->{'not_found'}});
  _autovivify($result) if (@{$result->{'not_found'}});
  _set($result->{'parent'}, $result->{'last_node'}, $_[2]);
}#store

# ------------------------------------------------------------------------------
# getv - Get a nested value
# getv \%data, $index
# getv \@data, $index
# ------------------------------------------------------------------------------

sub getv {
  my $result = _traverse($_[0], $_[1]);
  $result->{'value'};
}#getv

# ------------------------------------------------------------------------------
# setv - Store a nested value
# setv \%data, $index, ?value
# setv \@data, $index, ?value
# ------------------------------------------------------------------------------

sub setv {
  my $result = _traverse($_[0], $_[1]);
  _transcend($result) if (@{$result->{'not_found'}});
  _autovivify($result) if (@{$result->{'not_found'}});
  _set($result->{'parent'}, $result->{'last_node'}, $_[2]);
}#setv

# ------------------------------------------------------------------------------
# delete - Remove a nested value
# delete \%data, $index
# delete \@data, $index
# ------------------------------------------------------------------------------

sub delete {
  my $result = _traverse($_[0], $_[1]);
  return if @{$result->{'not_found'}};
  _delete($result->{'parent'}, $result->{'last_node'});
}#delete

# ------------------------------------------------------------------------------
# _get - Get node value from an array or hash
# _get \%data, $node
# _get \@data, $node
# ------------------------------------------------------------------------------

sub _get {
  Hub::is_bipolar($_[0])
    ? $_[0]->get_data($_[1])
    : ref($_[0]) eq 'ARRAY' && $_[1] =~ /^\d+$/
      ? $_[0]->[$_[1]]
      : $_[1] =~ /^\{(.*)\}$/
        ? Hub::subset(@_)
        : isa($_[0], 'HASH')
          ? $_[0]->{$_[1]}
          : Hub::subset(@_);

# $_[1] =~ /^\{(.*)\}$/
#   ? Hub::subset(@_)
#   : ref($_[0]) eq 'ARRAY' && $_[1] =~ /^\d+$/
#     ? $_[0]->[$_[1]]
#     : ref($_[0]) eq 'HASH'
#       ? Hub::subset(@_)
#       : Hub::is_bipolar($_[0])
#         ? $_[0]->get_data($_[1])
#         : isa($_[0], 'HASH')
#           ? Hub::subset(@_)
#           : undef;

}#_get

# ------------------------------------------------------------------------------
# _set - Set a node value on an array or hash
# _set \%data, $node, $value
# _set \@data, $node, $value
# ------------------------------------------------------------------------------

sub _set {
  if ((ref($_[0]) eq 'ARRAY') && ($_[1] =~ /^\d+$/)) {
    $_[0]->[$_[1]] = $_[2];
  } elsif (isa($_[0], 'HASH')) {
    $_[0]->{$_[1]} = $_[2];
  } else {
    confess "Type mismatch";
  }
  return $_[2];
}#_set

# ------------------------------------------------------------------------------
# _delete - Remove a node from an array or hash
# _delete - \%data, $node
# _delete - \@data, $node
# ------------------------------------------------------------------------------

sub _delete {
  if ($_[1] =~ /^\d+$/ && ref($_[0]) eq 'ARRAY') {
    delete $_[0]->[$_[1]];
  } elsif (isa($_[0], 'HASH')) {
    delete $_[0]->{$_[1]};
  }
}#_delete

# ------------------------------------------------------------------------------
# _autovivify - Create missing parent nodes
# _autovivify \%result
# ------------------------------------------------------------------------------

sub _autovivify {
  my $result = shift;
  my $not_found = $result->{'not_found'};
  # autovivify (create parents) if needed
  while (@$not_found) {
    my $node = shift @$not_found;
    if (@$not_found) {
      # fill intermediates as hashes, unless the next node is an array index
      $result->{'parent'} =
        _set($result->{'parent'}, $node,
          $$not_found[0] =~ /^\d+$/ ? [] : {});
      push @{$result->{'found'}}, $node;
    }
  }
}#_autovivify

# ------------------------------------------------------------------------------
# _traverse - Step into the nested data structure one index node at a time
# _traverse \%data, $index
# _traverse \@data, $index
# ------------------------------------------------------------------------------

sub _traverse {
  my $ptr = $_[0];
  my $parent = $_[0];
  my @found = ();
  my @nodes = _split($_[1]);
  my $last_node = @nodes ? $nodes[-1] : $_[1];
  while (@nodes) {
    $parent = $ptr;
    $ptr = _get($ptr, $nodes[0]);
    last unless defined $ptr;
    push @found, shift @nodes;
  }
  return {
    'value'     => $ptr,
    'parent'    => $parent,
    'found'     => \@found,
    'not_found' => \@nodes,
    'last_node' => $last_node,
  };
}#_traverse

# ------------------------------------------------------------------------------
# _transcend - Extend the search to the file system
# _transcend \%result
# ------------------------------------------------------------------------------

sub _transcend {
  my $result = shift;
  my $base = join '/', @{$result->{'found'}};
  my $ptr = $result->{'parent'};
  my $continue = 1;
  while ($continue && @{$result->{'not_found'}}) {
    my $node = $result->{'not_found'}[0];
    $result->{'parent'} = $ptr;
    my $path = $base ? "$base/$node" : $node;
    if (-e $path) {
      $ptr->{$node} = Hub::mkhandler($path);
      $continue = -d $path;
      $base = $path;
      $ptr = $ptr->{$node};
      push @{$result->{'found'}}, shift @{$result->{'not_found'}};
    } else {
      $continue = 0;
    }
  }
  if (@{$result->{'not_found'}}) {
    my $result2 = _traverse($ptr, join('/', @{$result->{'not_found'}}));
    $result->{'value'} = $result2->{'value'};
    $result->{'parent'} = $result2->{'parent'};
    push @{$result->{'found'}}, @{$result2->{'found'}};
    $result->{'not_found'} = $result2->{'not_found'}; 
  } else {
    $result->{'value'} = $ptr;
  }
  $result;
}#_transcend

# ------------------------------------------------------------------------------
# _get_parser - Get the parser for a given file
# ------------------------------------------------------------------------------

sub _get_parser {
  my $parser = 'File';
  if ($_[0] =~ /\.(dat|hf|metadata)$/) {
    $parser = 'HashFile';
  }
  Hub::mkinst($parser, $_[0]);
}#_get_parser

# ------------------------------------------------------------------------------
# _split - Split an index into nodes, removing empty ones
# _split - $index
# ------------------------------------------------------------------------------

sub _split {
  grep {length $_ > 0} split '/', $_[0];
}#_split

1;

=pod:summary Access nested data

=pod:synopsis

=pod:description

=cut
