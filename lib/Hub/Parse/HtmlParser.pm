package Hub::Parse::HtmlParser;
use strict;
use Hub qw/:lib/;
our $has_imagelib;

BEGIN {
  eval 'use Image::Size qw(imgsize)';
  our $has_imagelib = !$@;
}

push our @ISA, qw(Hub::Parse::StandardParser);

our %EVALUATORS;

sub get_evaluator {
  return defined $EVALUATORS{$_[1]}
    ? $EVALUATORS{$_[1]}
    : &Hub::Parse::StandardParser::get_evaluator(@_);
}

$EVALUATORS{'url'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my ($opts, %directive) = Hub::opts($fields);
  $result->{'value'} = '';
  my $literal = $directive{'url'};

# Get the site URL.  This is...
# my $script_filename = $$Hub{'/sys/ENV/SCRIPT_FILENAME'};
# my $relative_filename = substr $script_filename, length($$Hub{'/sys/ENV/WORKING_DIR'});
#warn "script_filename:    $script_filename\n";

  my $relative_filename = Hub::getaddr($ENV{'SCRIPT_FILENAME'});
  my $script_name  = $$Hub{'/sys/ENV/SCRIPT_NAME'};
  my $site_url = substr($script_name, 0, - length($relative_filename)) || '';

#warn "relative_filename:  $relative_filename\n";
#warn "script_name:        $script_name\n";
#warn "site_url:           $site_url\n";

#warn "--url--: $literal\n";
  if ($$opts{'relative'}) {
    # Figure out script directory
    my $script_dir = Hub::getpath($$Hub{'/sys/ENV/SCRIPT_FILENAME'});
    my $work_dir = $$Hub{'/sys/ENV/WORKING_DIR'};
    if (index($script_dir, $work_dir) == 0 ) {
#warn "   trim: $work_dir\n";
      $script_dir = substr($script_dir, length($work_dir));
    }
    if ($script_dir eq $work_dir) {
      $script_dir = '/';
    }
    $script_dir ||= '/';
    # Find the relative path
    my $relative_path = Hub::relpath($literal, $script_dir);
#warn "   from: $script_dir\n";
#warn "     to: $literal\n";
#warn "      =: $relative_path\n";
    $$result{'value'} = $relative_path;
  } else {
    $$result{'value'} = $literal =~ /^\// ? $site_url . $literal : $literal;
  }
};

$EVALUATORS{'image'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my ($opts, %directive) = Hub::opts($fields);
  $result->{'value'} = '';
  my $relpath = $directive{'image'} || '';
  my %args = %directive; # copy
  my $path = Hub::srcpath($relpath) || $relpath;
  unless ($path) {
    warn "Image path not found: $args{'image'}";
    return;
  }
  delete $args{'image'};
  if ($has_imagelib) {
#   my ($x,$y,$error) = imgsize($path);
    my ($x,$y) = _getdims($path, -opts => $opts);
    $args{'width'} ||= $x;
    $args{'height'} ||= $y;
  }
  $args{'src'} = $$self{'var_begin'}
    . "url \"$relpath\"" . $$self{'var_end'};
  $$result{'value'} = '<img ' . Hub::hashtoattrs(\%args) . '/>';
};

# ------------------------------------------------------------------------------
# _getdims - Get image dimensions
# _getdims $path, [options]
#
# options:
# 
#   -max_x=n    Maximum width
#   -max_y=n    Maximum height
#   -min_x=n    Minimum width
#   -min_y=n    Minimum height
#
# my ($w,$h) = _getdims( "/images/laura.jpg", -max_x => 50, -max_y => 50 );
# ------------------------------------------------------------------------------

sub _getdims {

  my ($opts, $file) = Hub::opts(\@_, {
    'max_x' => 0,
    'min_x' => 0,
    'max_y' => 0,
    'min_y' => 0,
  });

  my $nx      = 0;
  my $ny      = 0;
  my $w       = 0;
  my $h       = 0;

  ($nx,$ny) = imgsize($file);
  $w = $nx;
  $h = $ny;

  # Expand
  if( $nx > 0 && $$opts{'min_x'} > 0 ) {
    if( $nx < $$opts{'min_x'} ) {
      my $ratio = $ny/$nx;
      my $expandX = $$opts{'min_x'} - $nx;
      my $expandY = int($expandX*$ratio);
      $w = $nx + $expandX;
      $h = $ny + $expandY;
      $nx = $w;
      $ny = $h;
    }#if
  }#if
  if( $ny > 0 && $$opts{'min_y'} > 0 ) {
    if( $ny < $$opts{'min_y'} ) {
      my $ratio = $nx/$ny;
      my $expandY = $$opts{'min_y'} - $ny;
      my $expandX = int($expandY*$ratio);
      $w = $nx + $expandX;
      $h = $ny + $expandY;
      $nx = $w;
      $ny = $h;
    }#if
  }#if

  # Reduce
  if( $$opts{'max_x'} > 0 ) {
    if( $nx > $$opts{'max_x'} ) {
      my $ratio = $ny/$nx;
      my $reduceX = $nx - $$opts{'max_x'};
      my $reduceY = int($reduceX*$ratio);
      $w = $nx - $reduceX;
      $h = $ny - $reduceY;
      $nx = $w;
      $ny = $h;
    }#if
  }#if
  if( $$opts{'max_y'} > 0 ) {
    if( $ny > $$opts{'max_y'} ) {
      my $ratio = $nx/$ny;
      my $reduceY = $ny - $$opts{'max_y'};
      my $reduceX = int($reduceY*$ratio);
      $w = $nx - $reduceX;
      $h = $ny - $reduceY;
      $nx = $w;
      $ny = $h;
    }#if
  }#if

  return ($nx, $ny);
}#_getdims


$EVALUATORS{'jsvar'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my ($opts, %directive) = Hub::opts($fields);
  my $value = $self->get_value($directive{'jsvar'}, $valdata, $fields);
  return unless defined $value;
  $$result{'value'} = _jsvar($value, $self, $valdata);
};

sub _jsvar {
  my $item = shift;
  return isa($item, 'HASH')
    ?  '{' . join(', ', _jsvar_hash($item, @_)) . '}'
    : isa($item, 'ARRAY')
      ? '[' . join(', ', _jsvar_array($item, @_)) . ']'
      : "'" . Hub::jsstr(_jsvar_scalar($item, @_)) . "'";
}

sub _jsvar_hash {
  my $item = shift;
  my @args = @_;
  map {Hub::safestr($_) . ": " . _jsvar($$item{$_}, @args)} keys %$item
}

sub _jsvar_array {
  my $item = shift;
  my @args = @_;
  map {_jsvar($_, @args)} @$item;
}

sub _jsvar_scalar {
  my ($item, $self, $valdata) = @_;
  my $value = $self->_populate(-text => $item, @$valdata);
  $self->{'*depth'}--;
  return $$value;
};


1;
