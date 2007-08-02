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
  my ($opts, %directive) = Hub::opts($fields);
  $result->{'value'} = '';
  push @$parents, \%directive;
};

$EVALUATORS{'use'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my ($opts, %directive) = Hub::hashopts($fields);
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
  my ($opts, %directive) = Hub::hashopts($fields);
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
  my ($opts, @params) = Hub::opts($fields);
  shift @params; # drop 'if' part
  my $true = 0; # default to false
  if (defined $params[2]) {
    # This is a two-part evaluation
    my $l = $self->get_value($params[0], \@$valdata);
    my $r = $self->get_value($params[2], \@$valdata);
    if (defined $l && defined $r) {
      $true = Hub::compare($params[1], $l, $r);
    } elsif (!defined $l && !defined $r) {
      $true = 1;
    }
  } else {
    # This boolean condition
    my $v = $self->get_value($params[0], \@$valdata);
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
  # Logical not
  $true = !$true if $$opts{'not'};
  # Replace block with logical portion
  $$result{'value'} = $true ? $if : $else;
};

$EVALUATORS{'foreach'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  # Parse parameters (we delete the internally removed parameters
  # so that the others may be passed to get_value.)
  my ($opts, %directive) = Hub::opts($fields);
  $result->{'value'} = '';
  my $varname = $directive{'foreach'};
  delete $directive{'foreach'};
  die "Missing variable name parameter" . $self->get_hint($$pos, $text)
    unless defined $varname;
  my $in = $directive{'in'};
  delete $directive{'in'};
  die "Missing 'in' parameter" . $self->get_hint($$pos, $text)
    unless defined $in;
  my $sort = $$opts{'sort'} || 0;
  my ($end_p, $block) =
    $self->_get_block($$pos + length($outer_str), $text, 'foreach');
  $$result{'width'} = $end_p - $$pos;
  # Get the data for the sub-template
  my $data = $self->get_value($in, \@$valdata, $fields);
  if (defined $data && !ref($data)) {
    if ($$opts{'split'}) {
      $data = [split($$opts{'split'}, $data)];
    } elsif ($$opts{'split_hash'}) {
      my %hash_data = split($$opts{'split_hash'}, $data);
      $data = \%hash_data;
    }
  }
  my @items = ();
  if (isa($data, 'HASH')) {
    my @keys = keys %$data;
    if ($sort) {
      my $comparator = $sort eq '1' ? 'cmp' : $sort;
      @keys = sort {
        Hub::sort_compare($comparator, $self->_to_string($a), $self->_to_string($b))
      } keys %$data;
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
    my $comparator = $sort eq '1' ? 'cmp' : $sort;
    for ($sort ? sort {
        Hub::sort_compare($comparator, $self->_to_string($a), $self->_to_string($b))
      } @$data : @$data) {
      push @items, { $varname => $self->_to_string($_), };
    }
  } elsif (defined $data) {
    push @items, { $varname => $data, };
  }
  # Populate the sub-template for each datum
  my $idx = 0;
  my @text_results = ();
  foreach my $item (@items) {
    my $item_text = $self->_populate(-text => $block,
      $item, @$valdata, {
        '.idx' => $idx,
        '.num' => ($idx + 1),
        '.total' => scalar(@items),
        '.pen'  => $#items, # penultimate
      });
    $self->{'*depth'}--; # our call to _populate is not stepping deeper
    push @text_results, $item_text
      if defined $item_text && ref($item_text) eq 'SCALAR';
    $idx++;
  }
  my $num_joins = 0;
  for(my $i = 0; $i < @text_results; $i++) {
    my $item_text = $text_results[$i];
    if ($$item_text) {
      if ($$opts{'joint'} && $num_joins > 0) {
        $$result{'value'} .= $$opts{'joint'};
      }
      $$result{'value'} .= $$item_text;
      $num_joins++;
    }
  }
  # This worked everywhere, but with the foreach loop on
  # dev.livesite.net/custom-fonts.  The idea is to skip
  # over the entire foreach section after it is parsed so that
  # it doesn't get reparsed.
# $$result{'goto'} = $$pos + length($$result{'value'});
};

$EVALUATORS{'end'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my ($opts, %directive) = Hub::opts($fields);
  $result->{'value'} = '';
  shift @$valdata if $directive{'end'} eq 'use';
};

1;
