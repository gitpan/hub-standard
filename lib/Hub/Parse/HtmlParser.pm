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
  my %directive = @$fields;
  $result->{'value'} = '';
  my $literal = $directive{'url'};
#warn "--url--: $literal\n";
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
warn "   from: $script_dir\n";
warn "     to: $literal\n";
warn "      =: $relative_path\n";
  $$result{'value'} = $relative_path;
};

$EVALUATORS{'image'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my %directive = @$fields;
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
    my ($x,$y,$error) = imgsize($path);
    $args{'width'} = $x;
    $args{'height'} = $y;
  }
  $args{'src'} = $$self{'var_begin'}
    . "url \"$relpath\"" . $$self{'var_end'};
  $$result{'value'} = '<img ' . Hub::hashtoattrs(\%args) . '/>';
};

1;
