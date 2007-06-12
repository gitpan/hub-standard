package Hub::Parse::StandardParser;
use strict;
use Hub qw/:lib/;

push our @ISA, qw(Hub::Parse::Parser);

our %EVALUATORS;

sub get_evaluator {
  return defined $EVALUATORS{$_[1]}
    ? $EVALUATORS{$_[1]}
    : &Hub::Parse::Parser::get_evaluator(@_);
}

$EVALUATORS{'into'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my %directive = @$fields;
  $result->{'value'} = '';
  push @$parents, \%directive;
};

$EVALUATORS{'use'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my %directive = @$fields;
  $result->{'value'} = '';
  my $h = $self->get_value($directive{'use'}, $valdata, $fields);
  unless (ref($h)) {
    warn "Cannot use item '$h'" . $self->get_hint($$pos, $text)
      if $$Hub{'/sys/ENV/DEBUG'};
  }
  $h = { $directive{'as'} => $h } if $directive{'as'};
  unshift @$valdata, $h;
};

$EVALUATORS{'define'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my %directive = @$fields;
  $result->{'value'} = '';
  my $varname = $directive{'define'};
  my ($end_p, $block) =
    $self->_get_block($$pos + length($outer_str), $text, 'define');
  $$result{'width'} = $end_p - $$pos;
  $directive{'as'} ||= 'HASH';
  my $data = ();
  if ($directive{'as'} =~ /^(DATA|HASH)$/i) {
    $data = Hub::hparse($block);
  } elsif ($directive{'as'} =~ /^(LIST|ARRAY)$/i) {
    $data = Hub::hparse($block, -as_array => 1);
  } elsif ($directive{'as'} =~ /^(TEXT|SCALAR)$/i) {
    $data = $block;
  }
  push @$valdata, defined $varname ? {$varname, $data} : $data;
};

$EVALUATORS{'if'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  $result->{'value'} = '';
  shift @$fields; # drop 'if' part
  my $true = 0; # default to false
  if (defined $$fields[2]) {
    # This is a two-part evaluation
    my $l = $self->get_value($$fields[0], \@$valdata);
    my $r = $self->get_value($$fields[2], \@$valdata);
    if (defined $l && defined $r) {
      $true = Hub::compare($$fields[1], $l, $r);
    } elsif (!defined $l && !defined $r) {
      $true = 1;
    }
  } else {
    # This boolean condition
    my $v = $self->get_value($$fields[0], \@$valdata);
    $true = defined $v
      ? Hub::is_bipolar($v)
        ? 1
        : isa($v, 'ARRAY')
          ? @$v
          : isa($v, 'HASH')
            ? scalar(keys %$v)
            : ref($v) eq 'SCALAR'
              ? $$v
              : $v
      : 0;
  }
  my ($end_p, $block) =
    $self->_get_block($$pos + length($outer_str), $text, 'if');
  $$result{'width'} = $end_p - $$pos;
  my ($if,$else) = $self->_split_if_else($block);
  # Replace block with logical portion
  $$result{'value'} = $true ? $if : $else;
};

$EVALUATORS{'foreach'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  # Parse parameters (we delete the internally removed parameters
  # so that the others may be passed to get_value.)
  my %directive = @$fields;
  $result->{'value'} = '';
  my $varname = $directive{'foreach'};
  delete $directive{'foreach'};
  die "Missing variable name parameter" . $self->get_hint($$pos, $text)
    unless defined $varname;
  my $in = $directive{'in'};
  delete $directive{'in'};
  die "Missing 'in' parameter" . $self->get_hint($$pos, $text)
    unless defined $in;
  my $sort = $directive{'sort'} || 0;
  delete $directive{'sort'} if defined $directive{'sort'};
  my ($end_p, $block) =
    $self->_get_block($$pos + length($outer_str), $text, 'foreach');
  $$result{'width'} = $end_p - $$pos;
  # Get the data for the sub-template
  my $data = $self->get_value($in, \@$valdata, $fields);
  my @items = ();
  if (isa($data, 'HASH')) {
    my @keys = keys %$data;
    if ($sort) {
      @keys = sort keys %$data;
    }
    @keys = grep { substr($_, 0, 1) ne '.' } @keys;
    for (@keys) {
      push @items, {
        $varname => {
          'name'    => $self->_to_string($_),
          'value'   => $$data{$_},
        }
      }
    }
  } elsif (isa($data, 'ARRAY')) {
    for ($sort ? sort {$self->_to_string($a) cmp $self->_to_string($b)} @$data
        : @$data) {
      push @items, { $varname => $self->_to_string($_), };
    }
  } elsif (defined $data) {
    push @items, { $varname => $data, };
  }
  # Populate the sub-template for each datum
  my $idx = 0;
  foreach my $item (@items) {
    my $item_text = $self->_populate(-text => $block,
      $item, @$valdata, {
        '.idx' => $idx,
        '.num' => ($idx + 1),
        '.total' => scalar(@items),
        '.pen'  => $#items, # penultimate
      });
    $self->{'*depth'}--; # our call to _populate is not stepping deeper
    $$result{'value'} .= $$item_text
      if defined $item_text && ref($item_text) eq 'SCALAR';
    $idx++;
  }
};

$EVALUATORS{'end'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my %directive = @$fields;
  $result->{'value'} = '';
  shift @$valdata if $directive{'end'} eq 'use';
};

1;
