package Hub::Parse::Parser;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
    PARSER_ALL_BEGIN
    PARSER_ALL_END
    PARSER_MAX_DEPTH
    PARSER_MAX_SCOPE_DEPTH
/;
use constant {
  PARSER_ALL_BEGIN        => '[#',
  PARSER_ALL_END          => ']',
  # recursion accross _populate calls  consequently, also max replacements per 
  # template
  PARSER_MAX_DEPTH        => 10000,
  PARSER_MAX_SCOPE_DEPTH  => 100,
};


# ------------------------------------------------------------------------------
# %EVALUATORS - Routines invoked when the parser encounters a directive
#
# Each subroutine will be called with three arguments, a pointer back to the
# parser, a parameter hash, and a result hash:
#
#   my ($self, $params, $result) = @_;
#
# $params ARRAY
#
#  0 outer_str    $ The directive text which should be replaced
#  1 fields      \@ The parsed parameters from the directive
#  2 pos         \$ Current position
#  3 text        \$ The template
#  4 parents     \@ Array of ancestors which this should be parsed into
#  5 valdata     \@ Current stack of value data
#
# $result HASH:
#
#   'value'       $ The new value
#   'width'       $ Width of data to be replaced with 'value'
#   'keep_ws'     $ Keep whitespace around the original directive
#   'goto'        $ Go to this position after the replacement
# ------------------------------------------------------------------------------

our %EVALUATORS;

$EVALUATORS{'parser'} = sub {
  my ($self, $params, $result) = @_;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;
  if ($$fields[1] eq 'off') {
    $$result{'goto'} = $self->_find_point($text, $$pos, 'parser', 'on');
  }
  if ($$fields[1] eq 'off' || $$fields[1] eq 'on') {
    $$result{'value'} = undef;
  }
};

# ------------------------------------------------------------------------------
# new - Construct a new instance
# new -template => \$text|$text, [options]
#
# options:
#
#   -var_begin => $string     # Identifies beginning of a variable (no regexp)
#   -var_end => $string       # Identifies the end of a variable (no regexp)
# ------------------------------------------------------------------------------

sub new {
	my $self = shift;
	my $class = ref( $self ) || $self;
	my $obj = bless {}, $class;
  $obj->refresh(@_);
  return $obj;
}#new

# ------------------------------------------------------------------------------
# refresh - Return instance to initial state
# ------------------------------------------------------------------------------

sub refresh {

  my ($self,$opts) = Hub::objopts(\@_, {
    'template'    => '',
    'var_begin'   => PARSER_ALL_BEGIN,
    'var_end'     => PARSER_ALL_END,
    'max_depth'   => Hub::bestof($$Hub{'/conf/parser/max_depth'},
        PARSER_MAX_DEPTH),
    'max_scope_depth'   => Hub::bestof($$Hub{'/conf/parser/max_scope_depth'},
        PARSER_MAX_SCOPE_DEPTH),
  });
  croak "Illegal call to instance method" unless ref($self);

  # Template may be provided as arg1
  @_ and $$opts{'template'} ||= shift;

  # Set member variables via options
  foreach my $k (keys %$opts) {
    $self->{$k} = $$opts{$k};
  }

  # Create characters for inner matching
  $self->{'beg_char'} = substr $self->{'var_begin'}, 0, 1;
  $self->{'end_char'} = substr $self->{'var_end'}, 0, 1;

  # Create regex-able versions of the terminators
  $self->{'regex_begin'} = $self->{'var_begin'};
  $self->{'regex_end'} = $self->{'var_end'};
  $self->{'regex_begin'} =~ s/(?<!\\)(\W)/\\$1/g;
  $self->{'regex_end'} =~ s/(?<!\\)(\W)/\\$1/g;

}#refresh

# ------------------------------------------------------------------------------
# populate \HASH+
# 
# Populate our template with provided variable definitions.
#
# PARAMETERS:
#
#   \HASH               Variable name to definition map
# ------------------------------------------------------------------------------
#|test(match)   my $parser = mkinst( 'Parser', -template => 'Hello [#who]' );
#|              ${$parser->populate( { who => 'World' } )};
#~              Hello World
# ------------------------------------------------------------------------------

sub populate {
  my ($self,$opts) = Hub::objopts( \@_ );
  $self->{'values'} = \@_;
  $self->{'*depth'} = 0;
  $self->{'*exit_point'} = 0;
  my $text = $self->_populate();
  my $parser_directives = $$self{'regex_begin'}
    . 'parser ["\'](on|off)["\']' . $$self{'regex_end'} . '[\r\n]{0,2}';
  $$text =~ s/$parser_directives//g;
  return $text;
}#populate

# ------------------------------------------------------------------------------
# _populate [OPTIONS], \HASH+
# 
# Internal worker function.
# Recursive.
#
# PARAMETERS:
#
#   \HASH               Variable name to definition map
#
# OPTIONS:
#
#   -text   \SCALAR     Template text to populate
# ------------------------------------------------------------------------------

sub _populate {
  
  my ($self,$opts) = Hub::objopts(\@_);
  my $text = defined $$opts{'text'} ? $$opts{'text'} : $self->{'template'};
  ref($text) eq 'SCALAR' and $text = $$text;
  $self->{'*depth'}++;
  return unless defined $text;

  # Parsing constants
  my $BEGIN           = $self->{'var_begin'};
  my $END             = $self->{'var_end'};
  my $BEGINCHAR       = $self->{'beg_char'};
  my $ENDCHAR         = $self->{'end_char'};
  my $MAX_DEPTH       = $self->{'max_depth'};
  my $MAX_SCOPE_DEPTH = $self->{'max_scope_depth'};

  my @parents = ();   # templates we will pass the parsed text into
  my %skip = ();      # remember undefined values
  my $p = 0;          # string position as we progress
  $self->{'*replace_count'} = 0;

  # recursion control (high level, templates calling templates)
  croak "High-level recursion limit ($MAX_DEPTH) exceeded"
      . $self->get_hint($p, \$text)
        if $self->{'*depth'} > $MAX_DEPTH;

  # recursion control (medium level, like foreach loops)
  croak "Medium-level recursion limit ($MAX_SCOPE_DEPTH) exceeded"
      . $self->get_hint($p, \$text)
        if @_ > $MAX_SCOPE_DEPTH;

  while( $p > -1 ) {

    # find the beginning of a variable definition: '['
    $p = index( $text, $BEGIN, $p );
    last unless $p > -1;

    # recursion control (low level, variable nesting)
    if ($p > $self->{'*exit_point'}) {
      $self->{'*replace_count'} = 0;
      $self->{'*exit_point'} = $p;
    } else {
      if ($self->{'*replace_count'} > $MAX_DEPTH) {
        croak "Low-level recursion limit ($MAX_DEPTH) exceeded"
          . $self->get_hint($p, \$text);
      }
    }

    # find the end of this definition: ']'
    my $p2 = $p + length($BEGIN); # start of the current search
    my $p3 = index( $text, $ENDCHAR, $p2 ); # point of closing
    while( $p3 > -1 ) {
      my $ic = 0; # inner count of begin chars
      my $im = index( $text, $BEGINCHAR, $p2 ); # inner match
      while( ($im > -1) && ($im < $p3) ) {
        $ic++;
        $p2 = ($im + 1);
        $im = index( $text, $BEGINCHAR, $p2 );
      }
      last unless $ic > 0;
      for( 1 .. $ic ) {
        $p3 = index( $text, $ENDCHAR, ($p3 + 1) );
      }
    }

    # unterminated variable
    if( $p3 <= $p ) {
      warn "Unterminated variable ($p3)" . $self->get_hint($p, \$text);
      $p += length($BEGIN);
      next;
    }#if

    # inside the '[#' .. ']' marks
    my $inner_str = substr( $text, ($p + length($BEGIN)),
      ($p3 - ($p + length($BEGIN))) );

    # include the '[#' and ']' marks
    my $outer_str = substr( $text, $p,
      (($p3 + length($END)) - $p) );

    # evaluate inner '[#..]' matches first
    if (index($inner_str, $BEGIN) > -1) {
      my $inner_val = ${$self->_populate(-text => \$inner_str, @_)};
      $self->{'*depth'}--;
      if(defined $inner_val && $inner_val ne $inner_str) {
        $self->remove_variables(\$inner_val);
        # replace
        substr $text, $p + length($BEGIN),
          length($inner_str), $inner_val;
        next; # repeat without moving pointer
      } else {
        # unresolved, move on
        $p += length($outer_str);
        next;
      }
    }

    # Break apart the inner string into fields
    my @fields = ();
    if ($inner_str =~ /^["'](.*)["']$/) {
      push @fields, $1;
    } else {
      @fields = map {s/[\r\n]+//g; $_} split
        /\s+["']{1}|=["']{1}|(?<!\\)["']{1}\s+|(?<!\\)["']{1}$/, $inner_str;
      next unless (@fields); # empty construct
      # Account for un-quoted first parameter
      my @name_fields = split /\s+/, $fields[0];
      if (@name_fields > 1) {
        shift @fields;
        unshift @fields, @name_fields;
      }
    }

    # Evaluate the match
    $self->_evaluate($fields[0],
      [$outer_str, \@fields, \$p, \$text, \@parents, \@_,]);
  }

  # Parents are templates specified by the 'into' directive
  my $result = ref($text) eq 'SCALAR' ? $text : \$text;
  while (my $parent = pop @parents) {
    my $contents = $Hub->resolve($$parent{'into'});
    if (defined $contents) {
      if (defined $$parent{'as'}) {
        # Do not reparse this text
        substr $$result, 0, 0, '[#parser "off"]';
        $$result .= '[#parser "on"]';
        # Populate the parent with ourselves
        $result = $self->_populate(-text => $contents, {
          $$parent{'as'} => $result,
        }, @_);
      } else {
        $result = $self->_populate(-text => $contents . $$result, @_);
      }
    }
  }

  return $result; # scalar ref
}

# ------------------------------------------------------------------------------
# get_evaluator - Hook into evaluator loop by overriding this method.
# get_evaluator $directive
#
# Returns a subroutine (CODE) reference.
#
# This method is used by this base class to get the evaluator when a particular
# directive is incountered.  For instance, if the template contains:
#
#   Hello [#if 'var1' eq 'var2']
#
# get_evaluator('if') will be called.  See L<Hub::Parse::StandardParser> for 
# an example of how this class is extended.
# ------------------------------------------------------------------------------

sub get_evaluator {
  return $EVALUATORS{$_[1]};
}#get_evaluator

# ------------------------------------------------------------------------------
# _evaluate - Evaluate the expression
# _evaluate \@value_data, @parameters
#
# Where @parameters are:
#
#   -fields     => \@fields
#   -outer_str  => $outer_str
#   -pos        => $position
#   -text       => \$text
# ------------------------------------------------------------------------------

sub _evaluate {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  my $name = shift or croak 'Provide an address to evaluate';
  my $params = shift;
  my ($outer_str, $fields, $pos, $text, $parents, $valdata) = @$params;

  # Return values
  my $result = {
    'value'   => undef,
    'width'   => length($outer_str),
    'keep_ws' => 0,
    'goto'    => 0,
  };

  my $evaluator = $self->get_evaluator($name);
  if (ref $evaluator eq 'CODE') {
    &$evaluator($self, $params, $result);
  } else {
    $$result{'keep_ws'} = 1;
    shift @$fields; # strip off $name
    # Get value (with parameters)
    $$result{'value'} = $self->resolve($name, \@$valdata, $fields);
    if (defined $$result{'value'}) {
      # Infinite recursion variables
      $self->{'*replace_count'}++;
      $self->{'*exit_point'} += length($$result{'value'}) - $$result{'width'};
#     if ($self->{'*replace_count'} > 4) {
#       warn "Approaching MAX_DEPTH: $name"
#         . $self->get_hint($$pos, $text);
#     }
    } else {
      warn "Value not found", $self->get_hint($$pos, $text)
          if $$Hub{'/sys/ENV/DEBUG'};
    }
  }

  # Replace the directive
  if (defined $$result{'value'}) {
    # Eat whitespace due to indenting (limit of 80 char indent)
    unless($$result{'keep_ws'}) {
      my @padding = _padding($text, $$pos, $$result{'width'});
      if (@padding) {
        $$pos -= $padding[0];
        $$result{'width'} += $padding[0];
        $$result{'width'} += $padding[1];
      }
    }
    # Do the replacement
    substr($$text, $$pos, $$result{'width'}, $$result{'value'});
    # Infinite recursion control.  Trim out directives which extract portions 
    # of the template (like #define and if/else blocks)
    if (length($$result{'value'}) == 0) {
      $self->{'*exit_point'} -= $$result{'width'};
    }
  } else {
    $$result{'goto'} ||= $$pos + $$result{'width'};
  }
  $$pos = $$result{'goto'} if ($$result{'goto'})

}#_evaluate

# ------------------------------------------------------------------------------
# get_value - Search the provided hashes for a value
# get_value $name, $hash, [$hash..]
# ------------------------------------------------------------------------------

sub get_value {
  my ($self, $name, $valdata, $params) = @_;
  croak "Illegal call to instance method" unless ref($self);
  my $value = undef;
  return unless $name;
  # Literal values are encapsulated in quotes
  my ($literal) = $name =~ /^['"](.*)['"]$/;
  return $literal if defined $literal;
  # Executable variables
  if ($name =~ s/^\!//) {
    $params ||= [];
    push @$params, ('-_get_value', sub {
      my ($n, $vd, $p) = @_;
      $vd ||= [];
      push @$vd, @$valdata;
      $self->resolve($n, $vd, $p);
    });
    my ($file, $method) = split ':{1,2}', $name;
    if ($$Hub{$file}) {
      return Hub::modexec(-filename => $file, -method => $method, $params);
    } else {
      return warn "Cannot find module: $file";
    }
  }
  # Search value data for the value
  foreach my $h (@$valdata, @{$self->{'values'}}) {
    next unless defined $h;
    if (ref($h)) {
      $value = isa($h, 'Hub::Base::Registry')
        ? $$h{$name}
        : Hub::getv($h, $name);
    }
    last if defined $value;
  }
  # Alternative value
  if (!defined($value) && defined $params && @$params) {
    # Make params hash-friendly
##  push @$params, undef if ((scalar (@$params) % 2) != 0);
#   if ((scalar (@$params) % 2) != 0) {
#     warn "Odd number of elements: ", join(", ", @$params), "\n";
#   }
    my ($param_opts, %params) = Hub::hashopts($params);
    if (defined $params{'or'} && $params{'or'} ne $name) {
      $value = $self->resolve($params{'or'}, $valdata, $params);
    }
  }
  return $value;
}

# ------------------------------------------------------------------------------
# resolve - Get a string representation of a value
# ------------------------------------------------------------------------------

sub resolve {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  my $value = $self->get_value(@_);
  # Convert objects to strings
  if (ref($value)) {
    $value = Hub::resolve($value);
#   if (UNIVERSAL::can($value,'get_content')) {
#     $value = $value->get_content();
#   } elsif (UNIVERSAL::can($value,'populate')) {
#     $value = ${$value->populate()};
#   } elsif (ref($value) eq 'SCALAR') {
#     $value = $$value;
#   }
  }
  if (defined $value && !ref($value)) {
    my ($name, $valdata, $params) = @_;
    if (defined $params && @$params && $name !~ /^\!/) {
      # Populate value with parameters
      my %args = @$params;
      $value = ${$self->_populate( -text => $value, \%args, @$valdata)}
          unless ((@$params == 2) && (defined $args{'or'}));
    }
  } elsif (isa($value, 'HASH')) {
    $value = Hub::hprint($value);
  }
  return $value;
}#resolve

# ------------------------------------------------------------------------------
# _value_of - The default string value of an object
# ------------------------------------------------------------------------------

sub _to_string {
  my $self = shift;
  # Translate file objects into their relative pathname
  if (UNIVERSAL::isa($_[0], 'Hub::Data::File')) {
    my $path = Hub::abspath($_[0]{'*filename'});
    if (defined $$Hub{'/sys/ENV/WORKING_DIR'}) {
      $path = substr $path, length($$Hub{'/sys/ENV/WORKING_DIR'});
    }
    return $path;
  }
  return $_[0];
}#_to_string

# ------------------------------------------------------------------------------
# get_hint - Show where we are in parsing the text
# get_hint $position, \$text
# ------------------------------------------------------------------------------

sub get_hint {
  my $self = shift;
  my ($p, $text) = @_;
  my $hint = substr($$text, $p, 60);
  $hint =~ s/[\n]/\\n/g;
  $hint =~ s/[\r]/\\r/g;
  return " at char[$p]: '$hint...'";
  last;
}

# ------------------------------------------------------------------------------
# remove_variables - Remove variable statements from the text
# remove_variables \$text
# This will *not* remove parents of nested variables.
# ------------------------------------------------------------------------------

sub remove_variables {
  my $self = shift;
  my $str = shift;
  croak "Illegal call to instance method" unless ref($self);
  croak "Provide a scalar reference" unless ref($str) eq 'SCALAR';
  # Prefix with '\' for regex pattern
  my $BEGIN = '\\' . $self->{'var_begin'};
  my $END = '\\' . $self->{'var_end'};
  $$str =~ s/$BEGIN[^($BEGIN)]+?$END//g;
}

# ------------------------------------------------------------------------------
# _get_block - Find the block for a given directive
# _get_block $start_position, \$text, $type
# ------------------------------------------------------------------------------

sub _get_block {
  my ($self, $start_p, $text, $type) = @_;
  croak "Illegal call to instance method" unless ref($self);
  croak "Provide a scalar reference" unless ref($text) eq 'SCALAR';
  my $subtext = '';
  # Find start of conditional text
  while (substr($$text, $start_p, 1) =~ /[\r\n]/) {
    $start_p++;
  }
  # Find the end point
  my $end_p = $self->_find_end_point($text, $start_p, $type);
  if ($end_p > 0) {
    $subtext = substr $$text, $start_p, $end_p - $start_p;
  } else {
    $subtext = substr $$text, $start_p;
    $end_p = length($$text) - 1;
  }
  return ($end_p, \$subtext);
}

# ------------------------------------------------------------------------------
# _find_point - Find the next occurance of a single argument directive
# _find_point \$text, $begin_point, $directive_name, $argument_value
#
# If you are looking for: [#parser "on"] then you would use this method as:
#
#   _find_point($text, $pos, 'parser', 'on');
# ------------------------------------------------------------------------------

sub _find_point {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);
  my ($text, $pos, $name, $arg) = @_;
  # TODO Pack this regular expression better (remove backslash prefix hack)
  my $str = '\\' . $self->{'var_begin'} . $name . "\\s+['\"]" . $arg . "['\"]"
    . '\\' . $self->{'var_end'};
  my $p = Hub::indexmatch($$text, $str, $pos);
  return $p > 0 ? $p : length($$text) - 1;
}#_find_point

# ------------------------------------------------------------------------------
# _find_end_point - Find the '[#end "???"]' marker
# _find_end_point - \$text, $begin_point, $type
#
# Returns the beg
# ------------------------------------------------------------------------------

sub _find_end_point {
  my $self = shift;
  croak "Illegal call to instance method" unless ref($self);

  my ($text, $p, $type) = @_;
  my $begin_str = $self->{'var_begin'} . $type;
  my $end_p = $self->_find_point($text, $p, 'end', $type);

  # Account for nested elements
  my $nested_p = $p;
  while (($nested_p =
    index($$text, $begin_str, $nested_p)) > -1) {
    $nested_p += length($begin_str);
    last if $nested_p > $end_p;
    my $start_p = index $$text, $self->{'var_end'}, $end_p;
    $end_p = $self->_find_point($text, $start_p, 'end', $type);
    die "Directive not terminated"
      . $self->get_hint($p, $text) if $end_p < 0;
  }

  if ($end_p >= 0) {
    my $closing_p = index($$text, $self->{'var_end'}, $end_p) +1;
    my $width = ($closing_p - $end_p);
#warn "end[$width]=$$text'", substr($$text, ($end_p), ($width)), "'\n";
    my @padding = _padding($text, $end_p, $width);
    $end_p -= $padding[0] if @padding;
#warn "removing $padding[0]\n" if @padding;
    return $end_p;
  } else {
    return length($$text) - 1;
  }

}

# ------------------------------------------------------------------------------
# _padding - Get number of preceeding and trailing whitespace characters
# _padding \$text, $pos, $width
#
#   \$text    template
#   $pos      current position in $$text
#   $width    width of the current match
#
# Returns an array of widths: ($w1, $w2)
#
#   $w1 = Number of preceeding whitespace characters
#   $w2 = Number of trailing whitespace characters
#
# Returns an empty array if non-whitespace characters are found in the 
# preceeding or trailing regions.
#
# We will look up to 80 characters in front of the current position (ie, 80
# character indent maximum.)
# ------------------------------------------------------------------------------

sub _padding {

  my ($text, $pos, $width) = @_;
  my ($prefix, $suffix, $starts_line) = ();

  if ($pos == 0) {
    $prefix = 0;
    $starts_line = 1;
  } else {
    for my $i (1 .. 80) {
      my $prev_c = substr $$text, $pos - $i, 1;
      last unless $prev_c =~ /\s/;
      $prefix = 0 if !defined $prefix;
      if (($prev_c eq "\r") || ($prev_c eq "\n")) {
        $starts_line = 1;
        if ($i > 1) {
          $prefix = $i - 1;
        }
        last;
      }
    }
  }

  if ($starts_line) {
    $suffix = 0;
    my $next_p = $pos + $width;
    my $last_c = '';
    for my $i (0 .. 1) {
      my $next_c = substr $$text, $next_p + $i, 1;
      if ((($next_c eq "\r") || ($next_c eq "\n"))
        && ($next_c ne $last_c)) {
        $suffix++;
        $last_c = $next_c;
      } else {
        last;
      }
    }
  }

  return defined $prefix && defined $suffix
    ? ($prefix, $suffix)
    : ();

}#_padding

sub _split_if_else {
  my $self = shift;
  my $text = shift;
  croak "Illegal call to instance method" unless ref($self);
  my $str_if = $self->{'var_begin'} . 'if';
  my $str_else = $self->{'var_begin'} . 'else' . $self->{'var_end'};
  my $p = 0;
  while ($p > -1) {
    my $p_else = index($$text, $str_else, $p);
    if ($p_else > -1) {
      my $p_if = index($$text, $str_if, $p );
      if (($p_if > -1) && ($p_if < $p_else)) {
        $p = $self->_find_end_point($text, $p_if + length($str_if), 'if');
#warn "p=$p p_else=$p_else p_if=$p_if\n";
      } else {
        my $separator = length($str_else);
        my $terminator = substr($$text, $p_else + $separator, 2);
        $separator += $terminator =~ s/[\r\n]//g;
        return (
          substr($$text, 0, $p_else),
          substr($$text, $p_else + $separator)
        );
      }
    } else {
      return($$text,'');
    }
  }
}

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Template parser

=pod:synopsis

  use Hub qw(:standard);

  my $text = 'Hello [#/user], it is [#/date/month]';
  my $values = {
    user => ryan,
    date => {
      year => 2007,
      day => 10,
      month => March
    },
  };

  my $parser = mkinst('Parser', -tempate => \$text);
  print $parser->parse($values);

Will produce the result:

  Hello ryan, it is March

=pod:description

=head2 Intention

=cut
