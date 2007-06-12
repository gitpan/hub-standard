package Hub::Perl::Language;
use strict;
use Compress::Zlib;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
    sizeof
    check
    expect
    fear
    abort
    opts
    objopts
    cmdopts
    bestof
    subst
    getuid
    getgid
    max
    min
    flip
    rmval
    cpref
    checksum
    merge
    flatten
    replace
    digout
    diff
    touch
    intdiv
    dice
    indexmatch
/;

# Sorting
our ($a,$b) = ();

# Regular expression used for Hub::check comparisons
use constant EXPR_NUMERIC       => '\A[+-]?[\d\.Ee_]+\Z';

# Not all interpreters have getpwnam compiled in
eval ("getpwnam('')");
our $HAS_GETPWNAM = $@ ? 0 : 1;

# Not all interpreters have getgrnam compiled in
eval ("getgrnam('')");
our $HAS_GETGRNAM = $@ ? 0 : 1;

# ------------------------------------------------------------------------------
# sizeof - Integer size of hashes, arrays, and scalars
#
# sizeof \%hash
# sizeof \@array
# sizeof \$scalar_ref
# sizeof $scalar
# sizeof \%more, \@than, $one
#
# Sizes are computed as follows:
#
#   HASH    - Number of keys in the hash
#   ARRAY   - Number of elements
#   SCALAR  - Length as returned by C<length()>
#
# The total size of all arguments is returned.
# ------------------------------------------------------------------------------
#|test(match,3)     sizeof( { a=>1, b=>2, c=>3 } ); # Hash
#|test(match,3)     sizeof( [ 'a1', 'b2', 'c3' ] ); # Array
#|test(match,3)     sizeof( "abc"                ); # Scalar
#|test(match,3)     sizeof( \"abc"               ); # Scalar (ref)
#|test(match,0)     sizeof( undef                ); # Nothing
#|test(match,3)     sizeof( "a", "b", "c"        ); # Multiple values
# ------------------------------------------------------------------------------

sub sizeof {
  my $result = 0;
  foreach my $unk ( @_ ) {
    $result += !defined $unk
      ? 0
      : !ref($unk)
        ? length($unk)
        : isa($unk, 'HASH')
          ? Hub::sizeof([keys %$unk])
          : isa($unk, 'ARRAY')
            ? $#$unk + 1
            : ref($unk) =~ /^(SCALAR|REF)$/
              ? Hub::sizeof($$unk)
              : croak("Cannot compute size of: $unk");
  }
  return $result;
}#sizeof

# ------------------------------------------------------------------------------
# check - True if all items in list pass the test.
#
# check [OPTIONS], [TEST], LIST
#
# OPTIONS:
#
#   -opr    (or|and|xor)                            Operator  (default: 'and')
#
# TEST:
#
#   -test   (def|num|str|match|blessed|eval)        Test type (default: 'def')
#   -isa    EXPR
#   -ref    EXPR
#
# OPERATORS:
#
#   and             True when all items pass the test.
#   or              True when any single item passes the test.
#   xor             Alternation pattern. True unless two consecutive values
#                   both pass or fail the test.
#
# BASIC TEST:
#
#   def             Items are defined
#   num             Items are numeric
#   str             Items are *not* numeric
#
# OTHER TESTS:
#
#   match=EXPR      Items match EXPR
#   eval            Items are eval'd and truth is based on $@.  Note that the
#                   eval *actually* happens, so don't do anything that will
#                   break your code.  The intention of this check is for:
#
#|test(!abort) my $compression = check( '-test=eval', 'use IO::Zlib' ) ? 1 : 0;
#
# STRUCTURE TESTS:
#
#   blessed         Items are blessed
#   ref=EXPR        Item's ref matches EXPR (does *not* include @ISA)
#   isa=EXPR        Item's ref or @ISA match EXPR.  Much like UNIVERSAL::isa
#                   except allows regular expressions.
#
# ------------------------------------------------------------------------------
#|test(false) check( undef, undef, undef );         # none are defined
#|test(false) check( 1, undef );                    # only one is defined
#|test(true)  check( 1, 1 );                        # both are defined
#|test(true)  check( 1, undef, -opr => 'or' );      # one is defined
#|
#|test(false) check( -opr => 'xor', 1, 1 );
#|test(false) check( -opr => 'xor', undef, undef );
#|
#|test(true)  check( -opr => 'xor', undef, 1 );
#|test(true)  check( -opr => 'xor', 1, undef );
#|
#|test(true)  check( -opr => 'xor', 1, undef, 1, undef );
#|test(false) check( -opr => 'xor', 1, undef, 1, 1, undef );
#|test(true)  check( -opr => 'xor', undef, 1, undef, 1 );
# ------------------------------------------------------------------------------

sub check {

    my $opts = {
    
        'test'      => 'def',
        'opr'       => 'and',
        'match'     => '',
        'isa'       => '',
        'ref'       => '',

    };

    Hub::opts( \@_, $opts );

    $$opts{'ref'} and $$opts{'test'} = 'ref';

    $$opts{'isa'} and $$opts{'test'} = 'isa';

    my ($opt,$val) = ('','');

    ($opt,$val) = $$opts{'test'} =~ /^(\w+)=(.*)/ and do {

        $$opts{$opt} = $val;

        $$opts{'test'} = $opt;

    };

    my $ok = $$opts{'opr'} eq 'and' ? 1 : $$opts{'opr'} eq 'or' ? 0 : undef;

    for( my $i = 0; $i <= $#_; $i++ ) {

        my $result = 0;

        # Test item

        $$opts{'test'} eq 'def'     and $result = defined $_[$i];

        $$opts{'test'} eq 'num'     and $result = $_[$i] =~ EXPR_NUMERIC;

        $$opts{'test'} eq 'str'     and $result = $_[$i] !~ EXPR_NUMERIC;

        $$opts{'test'} eq 'match'   and $result = $_[$i] =~ /$$opts{'match'}/;

        $$opts{'test'} eq 'blessed' and $result = blessed( $_[$i] ) ? 1 : 0;

        $$opts{'test'} eq 'isa'     and $result = isa($_[$i], $$opts{'isa'});

        $$opts{'test'} eq 'ref' and do {
        
            if( ref($_[$i]) && $$opts{'ref'} ) {
            
                $result = scalar($_[$i]) =~ $$opts{'ref'};

            }#if

        };

        $$opts{'test'} eq 'eval' and do {

            no warnings; # useless use of eval return

            ref($_[$i]) eq 'CODE'   ? eval &{ $_[$i] }
            : !ref($_[$i])          ? eval { "$_[$i]" }
            : croak 'Cannot eval: $_[$i]';

            $result = !$@;

        };

        # Assign result

        $ok &= $result if( $$opts{'opr'} eq 'and' );

        $ok |= $result if( $$opts{'opr'} eq 'or' );

        if( $$opts{'opr'} eq 'xor' ) {

            if( ($i % 2) == 0 ) {

                $ok = $result;

                next;

            } else {

                $ok ^= $result;

            }#if

        }#if

        last unless $ok;

    }#for

    return $ok;

}#check

# ------------------------------------------------------------------------------
# opts [OPTIONS], \ARRAY, [\HASH]
#
# Split parameter arrays into options and arguments.
#
# OPTIONS:
#
#   -prefix=EXPR            # specify option prefix, default is single dash (-).
#
#   -assign=EXPR            # specify assignment character, default is the
#                             equal sign (=).
# 
#   -append=EXPR            # specify append character, default is the
#                             plus sign (+).
# 
# ------------------------------------------------------------------------------
#   
# In array context, we return two references.  Which may cause confusion:
#
#    my %opts = Hub::opts( \@_ );                # Wrong!
#    my $opts = Hub::opts( \@_ );                # Correct!
#    my ($opts,$args) = Hub::opts( \@_ );        # Correct!
#   
# ------------------------------------------------------------------------------
#   
# Options are extracted (via splice) from the referenced array. The advantage
# is both for performance (don't make a copy of the array), and so you may
# use @_ (or @ARGV, etc) normally, as data:
#
#|test(match,a;b;c;d) # at-underscore contains everyting but the '-with' option
#|
#|   sub myjoin {
#|      my $opts = Hub::opts( \@_ );
#|      return join( $$opts{'with'}, @_ );
#|   }
#|
#|   myjoin( 'a', 'b', '-with=;', 'c', 'd' );
#
# ------------------------------------------------------------------------------
#
# 1. Arguments are elements which do *not* begin with a dash (-).
#
# 2. Options are elements which begin with a B<single> dash (-) and are not 
#    negative numbers.
#
# 3. An option of '-opts' is reserved for passing in already parsed option
#    hashes.
#
# 4. Options will have their leading dash (-) removed.
#
# 5. Options values are formed as:
#
#   Given:                  opt1 will be:       because:
#
#   -opt1=value             'value'             contains an equal sign
#   -opt1 nextelem          'nextelem'          next element is *not* an option
#   -opt1 -option2          1                   next element is also an option
#   -opt1                   1                   it is the last element
#   -opt1                   1                   it is the last element
#   -opt1=a -opt1=b         b                   last one wins
#   -opt1=a +opt1=b         [ 'a', 'b' ]        it was specified using '+'
#   +opt1=a +opt1=b         [ 'a', 'b' ]        they can both be '+'
#
# ------------------------------------------------------------------------------
#   
# For example:
#
#   my($opts,$args) = Hub::opts( [ 'a', 'b', '-c' => 'c', '-x', '-o=out' ] );
# 
#   print "Opts:\n", Hub::hprint( $opts );
#   print "Args:\n", Hub::hprint( $args );
#
# Will print:
#
#   Opts:
#   c => c
#   o => out
#   x => 1
#   Args:
#   a
#   b
#     
# ------------------------------------------------------------------------------

sub opts {
  my $opts = {
    'append'    => '\+',
    'prefix'    => '-',
    'assign'    => '=',
  };
  my $argv    = shift;
  my $options = ref($_[0]) eq 'HASH' ? shift : {};
  my @remove  = ();
  Hub::opts(\@_,$opts) if @_;
  croak "Provide an array reference" if defined $argv && not isa($argv, 'ARRAY');
  return $options unless defined $argv && @$argv;
  for( my $idx = 0; $idx <= $#$argv; $idx++ ) {
    next unless defined $$argv[$idx];
    next if ref( $$argv[$idx] );
    if( my($prefix,$k) =
        $$argv[$idx] =~/^($$opts{'append'}|$$opts{'prefix'})((?!\d|$$opts{'prefix'}).*)$/ ) {
      next unless $k;
      if( $k eq 'opts' ) {
        Hub::merge( $options, $$argv[$idx+1], -overwrite => 1 )
            if defined $$argv[$idx+1];
        push @remove, ($idx, $idx+1);
      } elsif( $k =~ /$$opts{'assign'}/ ) {
        my ($k2,$v) = $k =~ /([^$$opts{'assign'}]+)?$$opts{'assign'}(.*)/;
        _assignopt( $opts, $options, $k2, $v, $prefix );
        push @remove, $idx;
      } elsif( $idx < $#$argv ) {
        if( !defined $$argv[$idx+1]
              || ( (defined $$argv[$idx+1])
              && $$argv[$idx+1] !~ /^($$opts{'append'}|$$opts{'prefix'})(?!\d)/) ) {
          _assignopt( $opts, $options, $k, $$argv[++$idx], $prefix );
          push @remove, ( ($idx-1), $idx );
        } else {
          _assignopt( $opts, $options, $k, 1, $prefix );
          push @remove, $idx;
        }
      } else {
        _assignopt( $opts, $options, $k, 1, $prefix );
        push @remove, $idx;
      }
    }
  }
  my $offset = 0;
  map { splice @$argv, $_ - $offset++, 1 } @remove;
  wantarray and return ($options,@$argv);
  return $options;
}#opts

# ------------------------------------------------------------------------------
# objopts - Split @_ into ($self,$opts), leaving @_ with remaining items.
# objopts \@params, [\%defaults]
# 
# Convienence method for splitting instance method parameters.
# Returns an array.
# ------------------------------------------------------------------------------
#|test(match) # Test return value
#|
#|  my $obj = mkinst( 'Object' );
#|  my @result = objopts( [ $obj ] );
#|  join( ',', map { ref($_) } @result );
#|
#=Hub::Base::Object,
# ------------------------------------------------------------------------------

sub objopts {
    my $params = shift;
    my $defaults = shift;
    my $self = $$params[0]; # not shifted
    shift @$params;
    Hub::expect(-blessed => $self, -back => 1);
    my $opts = Hub::opts($params, $defaults) if @$params;
    return($self, $opts, @$params);
}#objopts

# ------------------------------------------------------------------------------
# cmdopts - Extract short and long options from @ARGV
# cmdopts \@arguments
# cmdopts \@arguments, \%default_options
#
# Single-dash paramaters are always boolean flags.  Flags are broken apart such 
# that:
#
#   -lal
#
# becomes
#
#   -l -a -l
#
# To create a list (ARRAY) of items, use '++' where you would normally use '--'.
# ------------------------------------------------------------------------------
#|test(match,a-b-c)
#|  my $opts = cmdopts(['--letters=a', '++letters=b', '++letters=c']);
#|  join('-', @{$$opts{'letters'}});
# ------------------------------------------------------------------------------

sub cmdopts {
  my $argv = shift;
  my @flags = ();
  # Parse-out flags (single-dash parameters)
  my $i = 0;
  for (my $i = 0; $i < @$argv;) {
    my $arg = $$argv[$i];
    if ($arg =~ /^-\w/) {
      push @flags, $arg =~ /(\w)/g;
      splice @$argv, $i, 1;
    } else {
      $i++;
    }
  }
  # Parse double-dash parameters
  my $result = Hub::opts( $argv, @_, '-prefix=-{2}', '-append=\+{2}' );
  # Inject flags in final result
  foreach my $flag (@flags) {
    $result->{$flag} = defined $$result{$flag} ? $$result{$flag} + 1 : 1;
  }
  return $result;
}#cmdopts

# ------------------------------------------------------------------------------
# _assignopt Assign an option value.
# _assignopt \%options, \%dest, $key, $val
# ------------------------------------------------------------------------------

sub _assignopt {
  my $opts = $_[0];
  if( $_[4] !~ /^$$opts{'append'}$/ ) {
    $_[1]->{$_[2]} = $_[3];
    return;
  };
  if( defined $_[1]->{$_[2]} ) {
    if( ref($_[1]->{$_[2]}) eq 'ARRAY' ) {
      push @{$_[1]->{$_[2]}}, $_[3];
    } else {
      my $v = $_[1]->{$_[2]};
      $_[1]->{$_[2]} = [ $v, $_[3] ];
    }
  } else {
    push @{$_[1]->{$_[2]}}, $_[3];
#   $_[1]->{$_[2]} = $_[3];
  }
}#_assignopt

# ------------------------------------------------------------------------------
# subst
# 
# Call to perl's substitution operator.  Represented here as a function to 
# facilitate transformation by reducing the need for temporaries.  In essence,
# the goal is to reduce:
#
#   my $bakname = getfilename();
#   $bakname =~ s/\.db$/\.bak/;
#
# to:
#
#   my $bakname = Hub::subst( getfilename(), '\.db$', '.bak' );
#
# without modifying the original string returned by getfilename().
# ------------------------------------------------------------------------------

sub subst {
  my ($s,$l,$r,$m) = @_;
  #  s    string to operate on
  #  l    left-half of s/// operation
  #  r    right-half of s/// operation
  #  m    modifier for s/// operation
  return '' unless Hub::check( $s, $l, $r );
  ref($s) eq 'SCALAR' and $s = $$s;
  $m ||= '';
  eval( "\$s =~ s/$l/$r/$m" );
  croak $@ if $@;
  return $s;
}#subst

# ------------------------------------------------------------------------------
# getuid - Return the UID of the provided user
# getuid $user_name
# If perl has not been compiled with 'getpwnam', $user_name is returned.
# -1 is returned when no user is found
# ------------------------------------------------------------------------------

sub getuid {
  return $_[0] if Hub::check($_[0], -test => 'num');
  if ($HAS_GETPWNAM) {
    my ($login,$pass,$uid,$gid) = getpwnam($_[0]) or return -1;
    return $uid;
  } else {
    return $_[0];
  }
}#getuid

# ------------------------------------------------------------------------------
# getgid - Return the GID of the provided group
# getgid - $group_name
# If perl has not been compiled with 'getgrnam', $group_name is returned.
# -1 is returned when no group is found
# ------------------------------------------------------------------------------

sub getgid {
  return $_[0] if Hub::check($_[0], -test => 'num');
  if ($HAS_GETGRNAM) {
    my ($name,$passwd,$gid,$members) = getgrnam($_[0]) or return -1;
    return $gid;
  } else {
    return $_[0];
  }
}#getgid

# ------------------------------------------------------------------------------
# touch LIST
# 
# Changes the access and modification times on each file of a list of files.
# ------------------------------------------------------------------------------

sub touch {
  map { Hub::writefile( $_, '' ) unless -e $_ } @_;
  my $t = time;
  utime $t, $t, @_;
}#touch

# ------------------------------------------------------------------------------
# expect - Croak if arguments do not match their expected type
# expect [OPTIONS], [TEST], LIST
#
# OPTIONS:
#
#   -back   \d      # Carp level (for reporting further up the callstack)
#   -not    0|1     # Invert the result
#
# TESTS:
#
#   -blessed        # All LIST items are blessed
#   -match=EXPR     # All LIST items match /EXPR/
#   -ref=EXPR       # All LIST items' ref match /EXPR/
#
# By default, LIST is made up of key/value pairs, where the key is the type 
# (what ref() will return) and the value is what will be tested.  LIST may 
# contain one or more key/value pairs such as:
#
#   HASH            => arg
#   REF             => arg
#   My::Package     => arg
# ------------------------------------------------------------------------------
#|test(true)    Hub::expect( -match => 'and|or|xor', 'and' );
#|test(true)    Hub::expect( HASH => {}, HASH => {} );
#|test(abort)   Hub::expect( -blessed => {} );
#|test(true)    Hub::expect( -blessed => mkinst( 'Object' ) );
#|test(abort)   Hub::expect( -match => 'and|or|xor', 'if', 'or', 'and' );
#|test(abort)   Hub::expect( ARRAY => {} );
#|test(abort)   Hub::expect( -blessed => 'abc' );
#|test(true)    Hub::expect( -ref => 'HASH', {} );
#|test(true)    Hub::expect( -ref => 'HASH', mkinst('Object') );
# ------------------------------------------------------------------------------

sub expect {
  my $opts = Hub::opts( \@_ );
  my $invert = defined $$opts{'not'} ? 1 : 0;
  delete $$opts{'not'};
  my $back = $$opts{'back'} || 0;
  if( $$opts{'match'} ) {
    abort( -back => $back, -msg => "Expected: $$opts{'match'}" )
        unless( Hub::check( "-test=match=$$opts{'match'}", @_ )
            xor $invert );
    @_ = ();
  } elsif( $$opts{'blessed'} ) {
    abort( -back => $back, -msg => "Expected: blessed" )
        unless( Hub::check( "-test=blessed", $$opts{'blessed'}, @_ )
            xor $invert );
  } elsif( $$opts{'ref'} ) {
    abort( -back => $back, -msg => "Expected: hashable" )
        unless( Hub::check( "-ref=$$opts{'ref'}", @_ )
                xor $invert );
  } else {
    while( my ($k,$v) = (shift,shift) ) {
        last unless defined $k;
        abort( -back => $back, -msg => "Expected: '$k', got '"
            . ref($v) . "'" )
                if( $invert ? ref($v) eq $k : ref($v) ne $k );
    }
  }
  1;
}#expect

# ------------------------------------------------------------------------------
# Croak if arguments match their feared type.
# This is a shortcut to L<expect> with a '-not=1' option.
# ------------------------------------------------------------------------------
#|test(abort)   Hub::fear( HASH => {} );
#|test(true)    Hub::fear( HASH => [] );
# ------------------------------------------------------------------------------

sub fear {
  return Hub::expect( '-not=1', @_ );
}#fear

# ------------------------------------------------------------------------------
# abort - Croak nicely.
# abort -msg => 'Croak message'
# abort -back => LEVEL
# 
# ------------------------------------------------------------------------------
#|test(abort)   abort( -msg => 'Goddamn hippies' );
# ------------------------------------------------------------------------------

sub abort {
  my $opts = Hub::opts(\@_);
  $$opts{'msg'} ||= $@;
  $$opts{'msg'} ||= $!;
  $$opts{'back'} = 1 unless defined $$opts{'back'};
  $Carp::CarpLevel = $$opts{'back'};
  croak $$opts{'msg'};
}#abort

# ------------------------------------------------------------------------------
# bestof @list
# bestof @list, -by=max|min|def|len|gt|lt|true
#
# Best value by criteria (default 'def').
# ------------------------------------------------------------------------------

sub bestof {
  my $opts = Hub::opts( \@_ );
  $$opts{'by'} ||= 'def';
  my $best = $_[0];
  for( my $i = 1; $i <= $#_; $i++ ) {
    if( not defined $best ) {
      $best = $_[$i];
      ($$opts{'by'} eq 'def') && (defined $best) and last;
      next;
    }
    if( defined $_[$i] && defined $best ) {
      my $isbetter = 0;
      $$opts{'by'} eq 'gt'  and $isbetter = $_[$i] gt $best;
      $$opts{'by'} eq 'lt'  and $isbetter = $_[$i] lt $best;
      $$opts{'by'} eq 'max' and Hub::check( '-test=num', $_[$i], $best )
                            and $isbetter = $_[$i] > $best;
      $$opts{'by'} eq 'min' and Hub::check( '-test=num', $_[$i], $best )
                            and $isbetter = $_[$i] < $best;
      $$opts{'by'} eq 'len' and $isbetter = length($_[$i]) > length($best);
      $$opts{'by'} eq 'true' and $isbetter =
        defined $best && $best
          ? 0 # should call 'last' here
          : defined $_[$i] && $_[$i]
            ? 1
            : 0;
      $isbetter and $best = $_[$i];
    }
  }
  return $best;
}#bestof

# ------------------------------------------------------------------------------
# min - Minimum value
#
# min @LIST
#
# Returns the least element in a set.
# ------------------------------------------------------------------------------
#|test(match,1)     Hub::min(1,2); # Two integers
#|test(match,1)     Hub::min(2,1,3); # Three integers
#|test(match,-1)    Hub::min(2,-1,3); # Three integers
#|test(match,1)     Hub::min(1); # One integer
#|test(match,1)     Hub::min(1,undef); # Undefined value
#|test(match,0)     Hub::min(undef,1,0); # Zero
#|test(match,0.009) Hub::min(.009,1.001); # Three decimal values
# ------------------------------------------------------------------------------

sub min {
  return Hub::bestof( -by => 'min', @_ );
}#min

# ------------------------------------------------------------------------------
# max - Maximum value
#
# max @LIST
#
# Returns the greatest element in a set.
# ------------------------------------------------------------------------------
#|test(match,2)   Hub::max(.009,-1.01,2,undef,0); # Three decimal values
# ------------------------------------------------------------------------------

sub max {
  return Hub::bestof( -by => 'max', @_ );
}#max

# ------------------------------------------------------------------------------
# intdiv - Integer division
#
# intdiv $DIVIDEND, $DIVISOR
#
# Returns an array with the number of times the divisor is contained in the
# dividend, and the remainder.
# ------------------------------------------------------------------------------
#|test(match)   join(',',Hub::intdiv(3,2)); # 3 divided by 2 is 1R1
#=1,1
# ------------------------------------------------------------------------------

sub intdiv {
  my ($dividend,$divisor) = @_;
  return( undef, undef ) if $divisor == 0;
  return( int( $dividend / $divisor ), ( $dividend % $divisor ) );
}#intdiv

# ------------------------------------------------------------------------------
# given a hash reference, swap keys with values and return a new hash reference.
# ------------------------------------------------------------------------------

sub flip {
  my $hash = shift || return undef;
  my $new_hash = {};
  if (isa($hash, 'HASH')) {
    keys %$hash; # reset
    while (my ($k,$v) = each %$hash) {
      if ($$new_hash{$v}) {
        $$new_hash{$v} = [$$new_hash{$v}] unless isa($$new_hash{$v}, 'ARRAY');
        push @{$$new_hash{$v}}, $k;
      } else {
        $$new_hash{$v} = $k;
      }
    }
  }
  return $new_hash;
}#flip

# ------------------------------------------------------------------------------
# rmval - Remove matching elements from a hash or an array.
# rmval \@array, $value
# rmval \%hash, $value
# ------------------------------------------------------------------------------
#|test(match,124) join('',@{rmval([1,2,3,4],3)});
# ------------------------------------------------------------------------------

sub rmval {
  my ($container, $value) = @_;
  if (isa($container, 'HASH')) {
    foreach my $key ( keys %$container ) {
      if( $$container{$key} eq $value ) {
        delete $$container{$key};
      }
    }
  } elsif (isa($container, 'ARRAY')) {
    my $index = 0;
    foreach my $item (@$container) {
      if ($item eq $value) {
        splice @$container, $index, 1;
        # keep going
      } else {
        $index++;
      }
    }
  } else {
    croak "Cannot remove value from the provided container.";
  }
  return $container;
}#rmval 

# ------------------------------------------------------------------------------
# cpref - Recursively clone the reference, returning a new reference.
# cpref ?ref
# Implemented because the Clone module found on CPAN crashes under my mod_perl 
# and FastCGI test servers...
# ------------------------------------------------------------------------------

sub cpref {
  my $ref = shift;
  my $new = ();
  return $ref unless ref($ref);
  if (isa($ref, 'HASH')) {
    $new = blessed $ref ? ref($ref)->new() : {};
    keys %$ref; # reset iterator
    while( my($k,$v) = each %$ref ) {
      if( ref($v) ) {
        $new->{$k} = cpref($v) unless $v eq $ref;
      } else {
        $new->{$k} = $v;
      }
    }
  } elsif (isa($ref, 'ARRAY')) {
    $new = blessed $ref ? ref($ref)->new() : [];
    foreach my $v ( @$ref ) {
      if( ref($v) ) {
        push @$new, cpref($v);
      } else {
        push @$new, $v;
      }
    }
  } elsif (isa($ref, 'SCALAR')) {
    my $tmp = $$ref;
    $new = \$tmp;
  } elsif (ref($ref) eq 'REF') {
    $$ref eq $ref and
      warn "Self reference cannot be copied: $ref";
    ($$ref ne $ref) and $new = cpref($$ref);
  } else {
    croak "Cannot copy reference: $ref\n";
  }
  return $new;
}#cpref

# ------------------------------------------------------------------------------
# checksum - Create a unique identifier for the provided data
# checksum [params..]
# Params can be scalars, hash references, array references and the like.
# ------------------------------------------------------------------------------
#|test(match)
#|
#|  my $x = 'like catfood';
#|  Hub::checksum( 'my', { cats => 'breath' }, ( 'smells', $x ) );
#|
#~  2023611966
# ------------------------------------------------------------------------------

sub checksum {
  my $buffer = "";
  foreach my $param ( @_ ) {
    if( ref($param) eq 'HASH' ) {
      $buffer .= Hub::flatten( $param );
    } elsif( ref($param) eq 'ARRAY' ) {
      $buffer .= Hub::checksum( @$param );
    } elsif( ref($param) eq 'SCALAR' ) {
      $buffer .= $$param;
    } elsif( ref($param) eq "Fh" ) {
      $param =~ /(.*)/ and $buffer .= $1;
    } else {
      $buffer .= $param;
    }#if
  }#foreach
  my $crc32 = crc32($buffer); # crc32 is faster than adler32
  return $crc32;
}#checksum

# ------------------------------------------------------------------------------
# merge - Merge several hashes
# merge \%target, \%source, [\%source..], [options]
#
# Merges the provided hashes.  The first argument (destination hash) has
# precedence (as in values are NOT overwritten) unless -overwrite is given.
#
# OPTIONS:
#
#   -overwrite=1            Overwrite values as they are encounterred.
#
#   -prune=1                Gives the destination hash the same structure as
#                           the source hash (or the composite of all which is
#                           in common when multiple source hashes are provided).
#
#                           If the destination is missing a value, it is
#                           initialized from the source hash.
#
#                           If the destination has a value which is not in all
#                           of the source hashes, it is deleted.
# ------------------------------------------------------------------------------

sub merge {
  my ($opts) = Hub::opts(\@_, {
    'overwrite'   => 0,
    'prune'       => 0,
  });
  my $dh = shift; # destination hash
  $dh = {} unless defined $dh;
  return unless isa($dh, 'HASH');
  foreach my $sh ( @_ ) {
    _mergeHash($dh, $sh, $opts);
  }
  return $dh;
}#merge

sub _mergeHash {
  my ($dh,$sh,$opts) = @_;
  if ($$opts{'prune'}) {
    my @d_keys = keys %$dh;
    foreach my $k ( @d_keys ) {
      delete $$dh{$k} unless defined $$sh{$k};
    }
  }
  keys %$sh; # reset iterator
  while( my($k,$v) = each %$sh ) {
    &_mergeElement( $dh, $k, $v, $opts );
  }
}#_mergeHash

sub _mergeArray {
  my ($da,$sa,$opts) = @_; # destination array, source array
# splice @$da, scalar(@$sa);
# for (my $i = 0; $i < @$sa; $i++) {
#   if (defined $$sa[$i]) {
#     if (ref($$da[$i]) eq ref($$sa[$i])) {
#       &_mergeHash($$da[$i], $$sa[$i], $opts) if isa($$da[$i], 'HASH');
#       &_mergeArray($$da[$i], $$sa[$i], $opts) if isa($$da[$i], 'ARRAY');
#     } else {
#       $$da[$i] = $$sa[$i];
#     }
#   } else {
#     $$da[$i] = undef;
#   }
# }
  my $dh = {};
  map { $$dh{&_getId($_)} = $_ } @$da;
  my @d_keys = keys %$dh;
  foreach my $i ( @$sa ) {
    my $id = &_getId( $i );
    if( grep /^$id$/, @d_keys ) {
      if( (ref($i) =~ /HASH|::/) && ref($$dh{$id}) ) {
        &_mergeHash( $$dh{$id}, $i, $opts );
      }
    } else {
      push @$da, $i unless grep /^$id$/, @d_keys;
    }
  }
}#_mergeArray

sub _getId {
  my $h  = shift || return;
  my $id = "";
  if( ref($h) =~ /HASH|::/ ) {
    # in the order of prescedence, these are the subvalues we
    # use to determine this hash's uniqueness
    $id   = $$h{'_id'};
    $id ||= $$h{'id'};
    $id ||= $$h{'name'};
    $id ||= $$h{'value'};
  } elsif( ref($h) eq 'ARRAY' ) {
    $id = Hub::checksum( join '', @$h );
  }#if
  return $id ? $id : $h;
}#_getId

sub _mergeElement {
  my ($dh, $k, $v, $opts) = @_;
  if( defined($$dh{$k}) ) {
    my $c = ref($v); # class
    if( $c ) {
      if( $c eq ref($$dh{$k}) ) {
        $c =~ /HASH|::/ and &_mergeHash( $$dh{$k}, $v, $opts );
        $c eq 'ARRAY' and &_mergeArray( $$dh{$k}, $v, $opts );
      } else {
        # do not chage the type (unless overwriting)
        $$opts{'overwrite'} and $$dh{$k} = $v;
      }
    } else {
      $$opts{'overwrite'} and $$dh{$k} = $v;
    }
  } else {
    my $vcopy = Hub::cpref($v);
    $$dh{$k} = defined($vcopy) ? $vcopy : "";
  }
}#_mergeElement

# ------------------------------------------------------------------------------
# flatten - Get a consistent unique-by-data string for some data structure.
# flatten \%hash
# flatten \%array
# ------------------------------------------------------------------------------

sub flatten {
  my $ptr = shift || return;
  my $buf = "";
  if (isa($ptr, 'HASH')) {
    foreach my $k ( sort keys %$ptr ) {
      my $v = $$ptr{$k};
      if( ref($v) ) {
        $buf .= $k;
        $buf .= Hub::flatten( $v );
      } else {
        if( !$k || $v =~ /\n/ ) {
          $buf .= $v;
        } else {
          $buf .= $k . $v;
        }
      }
    }
  } elsif (isa($ptr, 'ARRAY')) {
    foreach my $v (sort @$ptr) {
      if (ref($v)) {
        $buf .= Hub::flatten($v);
      } else {
        $buf .= $v;
      }
    }
  } else {
    die "Cannot flatten structure: $ptr\n";
  }
  return $buf;
}#flatten

# ------------------------------------------------------------------------------
# replace MATCHING_REGEX, SUBSTITUTION_REGEX, TEXT
# 
# Do a s/// operation on a given segment of the string.
#
# For example, say we want to remove the ': ;' pattern from the style portion,
# but not from the data portion:
#
#   <div style="font-family: ;">keep this: ;stuff</div>
#
# Use this method as:
#
#   $text = Hub::replace( "style=\".*?\"", "s/[\\w\\-]+\\s*:\\s*;//g", $text );
#
# ------------------------------------------------------------------------------

sub replace {

    my ($match,$replace,$str) = @_;

    return unless $str;

    while( $str =~ m/\G.*?($match)/gs ) {

        my $substr = $1;

        my $beg = pos($str) - length( $substr );

        if( eval "\$substr =~ $replace" ) {

            pos $str = $beg;

            $str =~ s/\G$match/$substr/;

            pos $str = $beg + length($substr);

        }#if

    }#while

    return $str;

}#replace

# ------------------------------------------------------------------------------
# digout REF, ID
# 
# Return an array of all nested values in an order that can be processed.
#
# NOTE! Scalar values are returned as references.
# See how 'packdata' uses this method to dereference.
#
# Arrays are ignored unless their members are hashes with an _id member.
#
# Reverse the results of this array to process data in a way that the children
# are affected before their parents.
# ------------------------------------------------------------------------------

sub digout {

    my $r = shift;
    my $id = shift || '';

    return unless ref($r);

    my $h = {};

    my $data = [];

    if( ref($r) eq 'ARRAY' ) {

        foreach my $elem ( @$r ) {

            if( ref($elem) eq 'HASH' ) {

                if( $$elem{'_id'} ) {

                    $h->{$$elem{'_id'}} = $elem;

                }#if

            }#if

        }#foreach

    } elsif( ref($r) eq 'HASH' ) {

        $h = $r;

    }#if

    foreach my $k ( keys %$h ) {

        if( ref($h->{$k}) ) {

            push @$data, {
                key => $k,
                id  => "$id:$k",
                val => $h->{$k},
            };

            push @$data, @{ &digout($h->{$k},"$id:$k") };

        } else {

            push @$data, {
                key => $k,
                id  => "$id:$k",
                val => \$h->{$k},
            };

        }#if

    }#foreach

    return $data;

}#digout

# ------------------------------------------------------------------------------
# diff - Creates a nest of the differences between the provided structures.
# diff \%hash1, \%hash2
# diff \@array1, \@array2
#
# If a conflict of types (with the same key) is encounterred, the right-hand 
# sturcture is used.
#
# NOTE: Although this routine compares contents, it returns references to the 
# original hashes (use L<Hub::cpref> on the result to detatch.)
# ------------------------------------------------------------------------------

sub diff {
  my ($l,$r) = @_;
  if (isa($l, 'HASH')) {
    return _diff_hashes( $l, $r );
  } elsif (isa($l, 'ARRAY')) {
    return _diff_arrays( $l, $r );
  }
}#diff

# ------------------------------------------------------------------------------
# _diff_hashes &HASH, &HASH
# 
# Difference between two hashes.
# ------------------------------------------------------------------------------

sub _diff_hashes {
  my ($l,$r) = @_;
  return unless ref($l) eq 'HASH';
  return unless ref($r) eq 'HASH';
  my $h = undef;
  my @lkeys = keys %$l;
  while( my $key = shift @lkeys ) {
    if( defined $r->{$key} ) {
      if( ref($l->{$key}) eq ref($r->{$key}) ) {
        if( ref($l->{$key}) eq 'HASH' ) {
          my $subh = _diff_hashes( $l->{$key}, $r->{$key} );
          $h->{$key} = $subh if $subh;
        } elsif( ref($l->{$key}) eq 'ARRAY' ) {
          my $suba = _diff_arrays( $l->{$key}, $r->{$key} );
          $h->{$key} = $suba if $suba;
        } else {
          $h->{$key} = $r->{$key} unless $l->{$key} eq $r->{$key};
        }
      } else {
        $h->{$key} = $r->{$key};
      }
    } else {
      $h->{$key} = $l->{$key};
    }
  }
  my @rkeys = keys %$r;
  while( my $key = shift @rkeys ) {
    $h->{$key} = $r->{$key} unless defined $l->{$key};
  }
  return $h;
}#_diff_hashes

# ------------------------------------------------------------------------------
# _diff_arrays &ARRAY, &ARRAY
# 
# Difference between two arrays.
# ------------------------------------------------------------------------------

sub _diff_arrays {
  my ($l,$r) = @_;
  return unless isa($l, 'ARRAY');
  return unless isa($r, 'ARRAY');
  my $a = undef;
  my $idx = 0;
  my $min = Hub::min( $#$l, $#$r );
  for( my $idx = 0; $idx <= $min; $idx++ ) {
    my $lval = $l->[$idx];
    my $rval = $r->[$idx];
    if( ref($lval) eq ref($rval) ) {
      if( ref($lval) eq 'HASH' ) {
        my $subh = _diff_hashes( $lval, $rval );
        push( @$a, $subh ) if $subh;
      } elsif( ref($rval) eq 'ARRAY' ) {
        my $suba = _diff_arrays( $lval, $rval );
        push( @$a, $suba ) if $suba;
      } else {
        push( @$a, $rval ) unless $lval eq $rval;
      }
    } else {
      push @$a, $rval;
    }
    $idx++;
  }
  if( $#$l > $#$r ) {
    foreach my $idx ( ($#$r + 1) .. $#$l ) {
      push @$a, $l->[$idx];
    }
  } else {
    foreach my $idx ( ($#$l + 1) .. $#$r ) {
        push @$a, $r->[$idx];
    }
  }
  return $a;
}#_diff_arrays

# ------------------------------------------------------------------------------
# dice - Break apart the string into the least number of segments
# dice [options] $string
# options:
#   beg=$literal    Begin of balanced pair, Default is '{'
#   end=$literal    End of balanced pair, Default is '}'
# ------------------------------------------------------------------------------
#|test(match,a;{b{c}};c;{d}) join( ';', dice( "a{b{c}}c{d}" ) );
# ------------------------------------------------------------------------------

sub dice {

    my $opts = {
        'beg'   => '{',
        'end'   => '}',
    };

    Hub::opts( \@_, $opts );
    my $text        = shift;
    my @result      = ();

    my %beg = (
        str     => $$opts{'beg'},
        char    => substr($$opts{'beg'}, 0, 1),
        len     => length($$opts{'beg'}),
    );

    my %end = (
        str     => $$opts{'end'},
        char    => substr($$opts{'end'}, 0, 1),
        len     => length($$opts{'end'}),
    );

    # find the beginning
    my ($p,$p2,$p3) = (0,0,0);
    while( ($p = index( $text, $beg{'str'}, 0 )) > -1 ) {

        # find the end
        my $p2 = $p + $beg{'len'}; # start of the current search
        my $p3 = index( $text, $end{'char'}, $p2 ); # point of closing
        while( $p3 > -1 ) {
            my $ic = 0; # inner count
            my $im = index( $text, $beg{'char'}, $p2 ); # inner match
            while( ($im > -1) && ($im < $p3) ) {
                $ic++;
                $p2 = ($im + 1);
                $im = index( $text, $beg{'char'}, $p2 );
            }
            last unless $ic > 0;
            for( 1 .. $ic ) {
                $p3 = index( $text, $end{'char'}, ($p3 + 1) );
            }
        }
        if( $p3 > $p ) {
            my $str = substr( $text, $p, (($p3 + $end{'len'}) - $p) );
            my $left = substr( $text, 0, $p );
            my $right = substr( $text, $p + length($str) );
            push @result, $left, $str;
            $text = $right;
        } else {
            croak "Unmatched $beg{'str'}";
        }
    }

    $text and push @result, $text;
    return @result;

}#dice

# ------------------------------------------------------------------------------
# indexmatch - Search for an expression within a string and return the offset
# indexmatch [options] $string, $expression, $position
# indexmatch [options] $string, $expression
# Returns -1 if $expression is not found.
# options:
#   after   1|0     Return the position *after* the expression.  Default is 0.
# ------------------------------------------------------------------------------
#|test(match,4)   indexmatch("abracadabra", "[cd]")
#|test(match,3)   indexmatch("abracadabra", "a", 3)
#|test(match,-1)  indexmatch("abracadabra", "d{2,2}")
#|test(match,3)   indexmatch("scant", "can", "-after=1")
#|                - indexmatch("scant", "can")
# ------------------------------------------------------------------------------

sub indexmatch {
  my ($opts, $str, $expr, $from) = Hub::opts(\@_, {'after' => 0,});
  croak "undefined search string" unless defined $str;
  croak "undefined search expression" unless defined $expr;
  $from = 0 if not defined $from;
  my $temp_str = substr $str, $from;
  croak "undefined search substring" unless defined $temp_str;
  my $pos = undef;
  $temp_str =~ /($expr)/;
  $pos = index $temp_str, $1 if (defined $1);
  return defined $pos
    ?  $$opts{'after'}
      ? $from + $pos + length($1)
      : $from + $pos
    : -1;
}#indexmatch

# ------------------------------------------------------------------------------
1;
