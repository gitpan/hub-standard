package Hub::Parse::DataInjector;
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
# return if $$self{'priority'} eq 'content';
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my %directive = @$fields;
  my $varname = $directive{'define'};
  my ($end_p, $block) =
    $self->_get_block($$pos + length($outer_str), $text, 'define');
  $$result{'width'} = $end_p - $$pos;
  my $data = defined $varname
    ? Hub::getv($self->{'data'}, $varname)
    : $self->{'data'};
  if (defined $data) {
    my $type = ref($data)
      ? isa($data, 'HASH')
        ? 'HASH'
        : isa($data, 'ARRAY')
          ? 'ARRAY'
          : ref($data)
      : 'TEXT';
    $$result{'value'} = "$$self{'var_begin'}define";
    $$result{'value'} .= " '$varname' as '$type'" if (defined $varname);
    $$result{'value'} .= "$$self{'var_end'}\n";
    $$result{'value'} .= ref($data) ? Hub::hprint($data) : $data;
    $$result{'value'} .= $self->_end_define();
  } else {
    $$result{'value'} = '';
  }
  $$result{'goto'} = $$pos + length($$result{'value'});
};

$EVALUATORS{'end'} = sub {
  my ($self, $params, $result) = @_;
# return if $$self{'priority'} eq 'content';
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  my %directive = @$fields;
  $result->{'value'} = '' if $directive{'end'} eq 'define';
};

sub get_value {
  return undef;
}

sub populate {
  my ($self,$opts) = Hub::objopts(\@_);
  $self->{'data'} = shift;
  $self->SUPER::populate();
}#populate

sub _end_define {
  return "$_[0]->{'var_begin'}end 'define'$_[0]->{'var_end'}";
}

1;
