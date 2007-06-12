package Hub::Parse::Hash;
use strict;
use Hub qw/:lib :console/;

our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw/hparse hprint/;

# Constants
our $NEWLINE            = "\n";
our $SPACE              = ' ';
our $INDENT             = '  ';

# Literal constants
our $LIT_OPEN           = '{';
our $LIT_CLOSE          = '}';
our $LIT_HASH           = '%';
our $LIT_ARRAY          = '@';
our $LIT_SCALAR         = '$';
our $LIT_ASSIGN         = '=>';
our $LIT_COMMENT        = '#';
our $LIT_COMMENT_BEGIN  = '#{';
our $LIT_COMMENT_END    = '#}';

# Used in regular expressions
our $PAT_OPEN           = $LIT_OPEN;
our $PAT_CLOSE          = $LIT_CLOSE;
our $PAT_HASH           = $LIT_HASH;
our $PAT_ARRAY          = $LIT_ARRAY;
our $PAT_SCALAR         = "\\$LIT_SCALAR";
our $PAT_ASSIGN         = $LIT_ASSIGN;
our $PAT_COMMENT        = $LIT_COMMENT;
our $PAT_COMMENT_BEGIN  = $LIT_COMMENT_BEGIN;
our $PAT_COMMENT_END    = $LIT_COMMENT_END;
our $PAT_LVAL           = '[\w\d\.\_\-]';
our $PAT_PROTECTED      = '[\%\@\$\{\}\>\=\#]';

# ------------------------------------------------------------------------------
# hparse - Parse text into perl data structures
# hparse \$text, [options]
# options:
#   -as_array=1         # Treat text as an array list (and return an array ref)
# ------------------------------------------------------------------------------

sub hparse {
  my ($opts, $text) = Hub::opts(\@_);
  croak "Provide a scalar reference" unless ref($text) eq 'SCALAR';
  my $root = $$opts{'into'} ? $$opts{'into'} : ();
  $root ||= $$opts{'as_array'} ? [] : Hub::mkinst('SortedHash');
  my $ptr = $root;
  my $block_comment = 0;
  my @parents = ();
  local $. = 0;

  for (split /\r?\n\r?/, $$text) {
    $.++;

    if ($block_comment) {
      # End of a block comment?
      /\s*$PAT_COMMENT_END/ and do {
        next if (ref($ptr) eq 'SCALAR');
        _trace($., "comment-e", $_);
        $block_comment = 0;
        next;
      };
      _trace($., "comment+", $_);
      next;
    }

    # Begin of a new hash structure
    /^\s*$PAT_HASH($PAT_LVAL*)\s*$PAT_OPEN?\s*$/ and do {
      _trace($., "hash", $_);
      push @parents, $ptr;
#     my %h; tie %h, 'Hub::Knots::SortedHash';
      my $h = Hub::mkinst('SortedHash');
      isa($ptr, 'HASH') and $ptr->{$1} = $h;
      isa($ptr, 'ARRAY') and push @$ptr, $h;
      $ptr = $h;
      next;
    };

    # Begin of a new array structure
    /^\s*$PAT_ARRAY($PAT_LVAL*)\s*$PAT_OPEN?\s*$/ and do {
      _trace($., "array", $_);
      push @parents, $ptr;
      my $a = [];
      isa($ptr, 'HASH') and $ptr->{$1} = $a;
      isa($ptr, 'ARRAY') and push @$ptr, $a;
      $ptr = $a;
      next;
    };

    # Begin of a new scalar structure
    /^\s*$PAT_SCALAR($PAT_LVAL*)\s*$PAT_OPEN?\s*$/ and do {
      _trace($., "scalar", $_);
      push @parents, $ptr;
      if (isa($ptr, 'HASH')) {
        $ptr->{$1} = '';
        $ptr = \$ptr->{$1};
      } elsif (isa($ptr, 'ARRAY')) {
        push @$ptr, '';
        $ptr = \$ptr->[$#$ptr];
      }
      next;
    };

    # A one-line hash member value
    /^\s*($PAT_LVAL+)\s*$PAT_ASSIGN\s*(.*)/ and do {
      _trace($., "assign", $_);
      die "Cannot assign variable to '$ptr'", _get_hint($., $_)
        unless isa($ptr, 'HASH');
      $ptr->{$1} = $2;
      next;
    };

    # Close a structure
    /^\s*$PAT_CLOSE\s*$/ and do {
      _trace($., "close", $_);
      $ptr = pop @parents;
      die "No parent" . _get_hint($., $_) unless defined $ptr;
      next;
    };

    # If this is a brand new structure then this could be a hanging brace.
    /^\s*$PAT_OPEN\s*/ and do {
      if ((isa($ptr, 'HASH') && !keys(%$ptr))
        || (isa($ptr, 'ARRAY') && !@$ptr)
        || (ref($ptr) eq 'SCALAR' && !$$ptr)) {
        _trace($., "hanging", $_);
        next;
        }
    };

    # A block comment
    /^\s*$PAT_COMMENT_BEGIN/ and do {
      next if (ref($ptr) eq 'SCALAR');
      _trace($., "comment-b", $_);
      $block_comment = 1;
      next;
    };

    # A one-line comment
    /^\s*$PAT_COMMENT/ and do {
      _trace($., "comment", $_);
      next unless (ref($ptr) eq 'SCALAR');
    };

    # A one-line array item
    ref($ptr) eq 'ARRAY' and do {
      _trace($., "array+", $_);
      s/^\s+//g;
      next unless $_; # Could be a blank line (arrays of hashes)
      push @$ptr, $_;
      next;
    };

    # Part of a scalar
    ref($ptr) eq 'SCALAR' and do {
      _trace($., "scalar+", $_);
      $$ptr .= $$ptr ? $NEWLINE . _unescape($_) : _unescape($_);
#     $$ptr .= $$ptr ? $NEWLINE . $_ : $_;
      next;
    };

    _trace($., "?", $_);
  }

  die "Unclosed structure" . _get_hint($., 'EOF') if @parents > 1;
  return $root;
}

# ------------------------------------------------------------------------------
# hprint - Format nested data structure as string
# hprint [options]
#
# options:
#
#   -as_ref => 1       Return a reference (default 0)
# ------------------------------------------------------------------------------

sub hprint {
  my ($opts, $ref) = Hub::opts(\@_, {'as_ref' => 0});
  croak "Provide a reference" unless ref($ref);
  my $result = _hprint($ref);
  return $$opts{'as_ref'} ? $result : ref($result) eq 'SCALAR' ? $$result : '';
}

# ------------------------------------------------------------------------------
# _hprint - Implementation of hprint
# ------------------------------------------------------------------------------

sub _hprint {
  my $ref = shift or croak "Provide a reference";
  my $name = shift || '';
  my $level = shift || 0;
  my $result_str = '';
  my $result = \$result_str;

  if (isa($ref, 'HASH') || isa($ref, 'ARRAY')) {

    # Structure declaration and name
    if ($level > 0) {
      my $symbol = isa($ref, 'HASH') ? $LIT_HASH : $LIT_ARRAY;
      $$result .= _get_indent($level) .$symbol.$name.$LIT_OPEN.$NEWLINE;
    }

    # Contents
    if (isa($ref, 'HASH')) {
      $level++;
      for (keys %$ref) {
        if (ref($$ref{$_})) {
          $$result .= ${_hprint($$ref{$_}, $_, $level)};
        } else {
          $$result .= ${_hprint(\$$ref{$_}, $_, $level)};
        }
      }
      $level--;
    } elsif (isa($ref, 'ARRAY')) {
      $level++;
      for (@$ref) {
        $$result .= ref($_) ?
          ${_hprint($_, '', $level)} :
          ${_hprint(\$_, '', $level)};
      }
      $level--;
    }

    # Close the structure
    $$result .= _get_indent($level) . $LIT_CLOSE.$NEWLINE
      if $level > 0;

  } elsif (ref($ref) eq 'SCALAR') {

    my $value = $$ref;
    $value = '' unless defined $value;

    # Scalar
    if (index($value, "\n") > -1 || $value =~ /^\s+/) {
      # Write a scalar block to protect data
      $$result .= _get_indent($level) .$LIT_SCALAR.$name.$LIT_OPEN.$NEWLINE;
      $$result .= _escape($value).$NEWLINE;
      $$result .= _get_indent($level) .$LIT_CLOSE.$NEWLINE;
    } else {
      # One-line scalar (key/value)
      if ($name) {
        $$result .= _get_indent($level) .
        $name.$SPACE.$LIT_ASSIGN.$SPACE.$value.$NEWLINE;
      } else {
        $$result .= _get_indent($level) .$value.$NEWLINE;
      }
    }

  } else {

    # Catch-all
    $$result .= _get_indent($level) . $LIT_COMMENT.$SPACE;
    $$result .= $name.$SPACE.$LIT_ASSIGN.$SPACE if (defined $name && $name);
    $$result .= $ref.'('.ref($ref).')'.$NEWLINE;

  }
  return $result;
}

# ------------------------------------------------------------------------------
# _escape - Esacape patterns which would be interpred as control characters
# ------------------------------------------------------------------------------

sub _escape {
  my $result = $_[0];
  $result =~ s/(?<!\\)($PAT_PROTECTED)/\\$1/g;
  return $result;
}#_escape

# ------------------------------------------------------------------------------
# _unescape - Remove protective backslashes
# ------------------------------------------------------------------------------

sub _unescape {
  my $result = $_[0];
  $result =~ s/\\($PAT_PROTECTED)/$1/g;
  return $result;
}#_unescape

# ------------------------------------------------------------------------------
# _get_indent - Get the indent for formatting nested sructures
# _get_indent $level
# ------------------------------------------------------------------------------

sub _get_indent {
  my $indent = $INDENT;
  return $_[0] > 1 ? $indent x= ($_[0] - 1): '';
}

# ------------------------------------------------------------------------------
# _trace - Debug output
# ------------------------------------------------------------------------------

sub _trace {
# warn sprintf("%4d", $_[0]), ": ", Hub::fw(10, $_[1]), " $_[2]\n";
}

# ------------------------------------------------------------------------------
# _get_hint - Context information for error messages
# _get_hint $line_num, $line_text
# ------------------------------------------------------------------------------

sub _get_hint {
  my $str =  substr($_[1], 0, 40);
  $str =~ s/^\s+//g;
  return " at line $_[0]: '$str'";
}

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Refactor of HashFile

=pod:synopsis

  TODO: Don't set structure values to scalar references
  TODO: Escape characters
  TODO: Write multiline values as scalar structures

=pod:description

=cut
