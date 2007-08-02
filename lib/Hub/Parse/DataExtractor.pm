package Hub::Parse::DataExtractor;
use strict;
use Hub qw/:lib/;

push our @ISA, qw(Hub::Parse::Parser);

our %EVALUATORS;

sub get_evaluator {
  my $evaluator = defined $EVALUATORS{$_[1]}
    ? $EVALUATORS{$_[1]}
    : &Hub::Parse::Parser::get_evaluator(@_);
  # Avoid undefined parser directive warnings
  return defined $evaluator ? $evaluator : sub {};
}

$EVALUATORS{'define'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my ($opts, %directive) = Hub::hashopts($fields);
  my $varname = $directive{'define'};
  my ($end_p, $block) =
    $self->_get_block($$pos + length($outer_str), $text, 'define');
  $$result{'width'} = $end_p - $$pos;
  $directive{'as'} = 'HASH' unless defined $directive{'as'};
  my $data = ();
  if ($directive{'as'} =~ /^(DATA|HASH)$/i) {
    if (defined $varname) {
      $self->{'data'}{$varname} ||= mkinst('SortedHash');
      Hub::hparse($block, -into => $self->{'data'}{$varname});
    } else {
      Hub::hparse($block, -into => $self->{'data'});
    }
  } elsif ($directive{'as'} =~ /^(LIST|ARRAY)$/i) {
    if (defined $varname) {
      $self->{'data'}{$varname} ||= [];
      die "Cannot parse array data into: $self->{'data'}{$varname}"
        unless isa($self->{'data'}{$varname}, 'ARRAY');
      Hub::hparse($block, -into => $self->{'data'}{$varname});
    } else {
      die "Cannot use root element as: $directive{'as'}\n";
    }
  } elsif ($directive{'as'} =~ /^(TEXT|SCALAR)$/i) {
    if (defined $varname) {
      $self->{'data'}{$varname} = $block;
    } else {
      die "Cannot use root element as: $directive{'as'}\n";
    }
  }
};

sub get_value {
  return '';
}

# ------------------------------------------------------------------------------
# get_data - Return extracted data
# ------------------------------------------------------------------------------

sub get_data {
  my ($self,$opts) = Hub::objopts(\@_);
  $$self{'data'} ||= {};
  $self->populate();
  return $$self{'data'};
}#get_data

1;
