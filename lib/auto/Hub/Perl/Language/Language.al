# NOTE: Changes made here will be lost when bulksplit is run again.
package Hub::Perl::Language;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Language
#
# Called by the framework to invoke Autoloader::AUTOLOAD, in essence loading
# this file.
# ------------------------------------------------------------------------------
sub Language {
}#Language

#line 57

# ------------------------------------------------------------------------------
# asa - As ARRAY
# ------------------------------------------------------------------------------
#|test(match)  join 'X', asa(undef);
# ------------------------------------------------------------------------------

sub asa {

    my $opts = Hub::opts(\@_);

    if( $#_ eq 0 && defined $_[0] ) {
    
        ref $_[0] eq 'ARRAY' and return @{$_[0]};

    }#if

    return @_;

}#asa

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

        $$opts{'test'} eq 'isa'     and do {

            if( $_[$i] =~ EXPR_BLESSED ) {

                my $class = ref($_[$i]);

                my @isa = ();
            
                @isa = @{"${class}::ISA"} if defined @{"${class}::ISA"};

                $result = $class =~ /$$opts{'isa'}/;

                $result ||= grep /$$opts{'isa'}/, @isa;

            }#if

        };

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
#   print "Opts:\n", Hub::hffmt( $opts );
#   print "Args:\n", Hub::hffmt( $args );
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
    
        'append'    => '+',
        'prefix'    => '-',
        'assign'    => '=',

    };

    my $argv    = shift;
    my $options = ref($_[0]) eq 'HASH' ? shift : {};
    my @remove  = ();

    Hub::opts(\@_,$opts) if @_;

    return $options unless defined $argv && @$argv;

    for( my $idx = 0; $idx <= $#$argv; $idx++ ) {

        next unless defined $$argv[$idx];

        next if ref( $$argv[$idx] );

        if( my($prefix,$k) =
            $$argv[$idx] =~ /^($$opts{'prefix'})((?!\d|$$opts{'prefix'}).*)$/ ) {

            next unless $k;

            if( $k eq 'opts' ) {

                Hub::merge( $options, $$argv[$idx+1], '--overwrite' )
                    if defined $$argv[$idx+1];

                push @remove, ($idx, $idx+1);

            } elsif( $k =~ /$$opts{'assign'}/ ) {

                my ($k2,$v) = $k =~ /([^$$opts{'assign'}]+)?$$opts{'assign'}(.*)/;

                _assignopt( $opts, $options, $k2, $v );

                push @remove, $idx;

            } elsif( $idx < $#$argv ) {

                if( !defined $$argv[$idx+1]
                    || ( (defined $$argv[$idx+1])
                        && $$argv[$idx+1] !~ /^$$opts{'prefix'}(?!\d)/) ) {

                    _assignopt( $opts, $options, $k, $$argv[++$idx] );

                    push @remove, ( ($idx-1), $idx );

                } else {

                    _assignopt( $opts, $options, $k, 1 );

                    push @remove, $idx;

                }#if

            } else {

                _assignopt( $opts, $options, $k, 1 );

                push @remove, $idx;

            }#if

        }#if

    }#for

    my $offset = 0;

    map { splice @$argv, $_ - $offset++, 1 } @remove;

    wantarray and return ($options,@$argv);

    return $options;

}#opts

# ------------------------------------------------------------------------------
# objopts - Split @_ into ($self,$opts), leaving @_ with remaining items.
# objopts \ARRAY
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

    my $self = $$params[0]; # not shifted
    
    shift @$params;

    Hub::expect( -blessed => $self, -back => 1 );

    my $opts = Hub::opts( $params ) if @$params;

    return($self,$opts,@$params);

}#objopts

# ------------------------------------------------------------------------------
# cmdopts - Extract short and long options from @ARGV
# cmdopts \ARRAY
# cmdopts \ARRAY, \HASH
#
# Convienence method which deals with short single-dash and long double-dash 
# options.
# ------------------------------------------------------------------------------

sub cmdopts {

    my $argv = shift;

    # Expand options:
    #
    #   -lal  becomes  -l -a -l
    #
    # Done inline so that the last one is followed by the next argument.  As in:
    #
    #   -xzf foo.tgz  becomes  -x -z -f foo.tgz

    for( my $i = 0; $i < @$argv; $i++ ) {

        my ($flags) = $$argv[$i] =~ /\A-([a-zA-Z]{2,})\Z/;

        if( $flags ) {

            my @args = map { "-$_" } $flags =~ /([a-zA-Z])/g;

            splice @$argv, $i, 1, @args;

        }#if

    }#for

    return Hub::opts( $argv, @_, '-prefix=-{1,2}' );

}#cmdopts

# ------------------------------------------------------------------------------
# _assignopt \%, $key, $val
# 
# Assign an option value.
# ------------------------------------------------------------------------------

sub _assignopt {

    my $opts = $_[0];

    $$opts{'prefix'} ne $$opts{'append'} and do {
    
        $_[1]->{$_[2]} = $_[3];

        return;

    };

    if( defined $_[1]->{$_[2]} ) {

        if( ref($_[1]->{$_[2]}) eq 'ARRAY' ) {

            push @{$_[1]->{$_[2]}}, $_[3];

        } else {

            my $v = $_[1]->{$_[2]};

            $_[1]->{$_[2]} = [ $v, $_[3] ];

        }#if

    } else {

        $_[1]->{$_[2]} = $_[3];

    }#if

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
# getuid
# 
# Return the UID of the user of the provided login id.
# ------------------------------------------------------------------------------

sub getuid {

    my $user = shift;

    eval( "getpwnam(\$user)" );

    if( $@ ) {
        Hub::lerr( $@ );
        return $user;
    }#if

    my ($login,$pass,$uid,$gid) = getpwnam($user)
        or return -1;

    return $uid;

}#getuid

# ------------------------------------------------------------------------------
# getgid
# 
# Return the GID of the user of the provided login id.
# ------------------------------------------------------------------------------

sub getgid {

    my $group = shift;

    eval( "getgrnam(\$group)" );

    if( $@ ) {
        Hub::lerr( $@ );
        return $group;
    }#if

    my ($name,$passwd,$gid,$members) = getgrnam($group)
        or return -1;

    return $gid;

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

        }#while

    }#if

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
# abort
# abort -msg => 'Croak message'
# abort -back => LEVEL
# 
# Croak nicely.
# ------------------------------------------------------------------------------
#|test(abort)   abort( -msg => 'Goddamn hippies' );
# ------------------------------------------------------------------------------

sub abort {

    my $opts = Hub::opts( \@_ );

    $$opts{'msg'} ||= $@;

    $$opts{'msg'} ||= $!;

    $$opts{'back'} = 1 unless defined $$opts{'back'};

    $Carp::CarpLevel = $$opts{'back'};

    croak $$opts{'msg'};

}#abort

# ------------------------------------------------------------------------------
# is the passed in thingy a HASH reference?
#
# ------------------------------------------------------------------------------
sub hash {

    return ( ref(shift) eq 'HASH' ? 1 : 0 );
    
}#hash

# ------------------------------------------------------------------------------
# is the passed in thingy an ARRAY reference?
#
# ------------------------------------------------------------------------------
sub array {

    return ( ref(shift) eq 'ARRAY' ? 1 : 0 );

}#array

# ------------------------------------------------------------------------------
# is the passed in thingy a SCALAR?  NOTE: This does not mean a SCALAR ref!
#
# ------------------------------------------------------------------------------
sub scalar {

    my $test_var = shift || return 0;

    return ( ref($test_var) ? 0 : 1 );

}#array

# ------------------------------------------------------------------------------
# bestof @list
# bestof @list, -by=max|min|def|len|gt|lt
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

        }#if

        if( defined $_[$i] && defined $best ) {
        
            my $isbetter = 0;

            $$opts{'by'} eq 'gt'  and $isbetter = $_[$i] gt $best;

            $$opts{'by'} eq 'lt'  and $isbetter = $_[$i] lt $best;

            $$opts{'by'} eq 'max' and Hub::check( '-test=num', $_[$i], $best )

                                  and $isbetter = $_[$i] > $best;

            $$opts{'by'} eq 'min' and Hub::check( '-test=num', $_[$i], $best )

                                  and $isbetter = $_[$i] < $best;

            $$opts{'by'} eq 'len' and $isbetter = length($_[$i]) > length($best);
        
            $isbetter and $best = $_[$i];

        }#if

    }#for

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

    if( ref($hash) eq 'HASH' ) {

        keys %$hash; # reset

        while( my ($k,$v) = each %$hash ) {

            if( $$new_hash{$v} ) {

                $$new_hash{$v} = [$$new_hash{$v}] unless ref($$new_hash{$v});

                push @{$$new_hash{$v}}, $k if ref($$new_hash{$v}) eq 'ARRAY';

            } else {

                $$new_hash{$v} = $k;

            }#if

        }#foreach

    }#if

    return $new_hash;

}#flip

# ------------------------------------------------------------------------------
# remove an element from a hash or array, by value
#
# ------------------------------------------------------------------------------
sub rmval {
    
    my ($container, $value) = @_;

    if( ref($container) eq 'HASH' ) {

        foreach my $key ( keys %$container ) {

            if( $$container{$key} eq $value ) {

                delete $$container{$key};

                last;

            }#if

        }#foreach

    } elsif( ref($container) eq 'ARRAY' ) {

        my $index = 0;

        foreach my $item ( @$container ) {

            if( $item eq $value ) {

                splice @$container, $index, 1;

                last;

            }#if

            $index++;

        }#foreach

    } else {

        # what now...

    }#if

}#rmval 

# ------------------------------------------------------------------------------
# remove an element from an array of hash refs, by some key's value
#
# ------------------------------------------------------------------------------
sub rmsubhash {
    
    my ($container, $key, $value) = @_;

    if( &ref($container) eq 'ARRAY' ) {

        my $index = 0;

        foreach my $item ( @$container ) {

            next unless ref( $item ) eq 'HASH';

            if( $$item{$key} eq $value ) {

                splice @$container, $index, 1;

                last;

            }#if

            $index++;

        }#foreach

    }#if

}#rmsubhash 

# ------------------------------------------------------------------------------
# hashget KEY, HASHREF
# 
# Get a nested hash member using the colon-delimited key format.
# ------------------------------------------------------------------------------

sub hashget {

    my ($key,$hashref,$default) = @_;

    return unless $key;

    return unless ref($hashref) eq 'HASH';

    my $val = LNS::hgetv( $hashref, $key );

    return defined $val ? $val : $default;

}#hashget

# ------------------------------------------------------------------------------
# given an array or hash reference, return the a new reference to an identical
# array, minus the duplicates.  if a hash reference is passed, the hash's keys
# are used to determine uniqueness.
#
# return structure is sorted.
#
# ------------------------------------------------------------------------------
sub uniq {
    
    my $thing = shift || return;

    my $return = ();

    if( ref( $thing ) eq 'HASH' ) {

        #
        # This doesn't make any sense, how can a hash have duplicate keys!
        # (...should be values, right?)
        #

        my $last_key = ();

        $return = {};

        foreach my $key ( sort keys %$thing ) {

            $$return{$key} = $$thing{$key} unless $key eq $last_key;

            $last_key = $key;

        }#foreach

    } elsif( ref( $thing ) eq 'ARRAY' ) {

        my $last_item = 1 - time;

        $return = [];

        foreach my $item ( sort @$thing ) {

            push @$return, $item unless $item eq $last_item;

            $last_item = $item;

        }#foreach

    }#if

    return $return;

}#uniq

# ------------------------------------------------------------------------------
# given a hash reference, return an array of its keys sorted by their values.
#
# ------------------------------------------------------------------------------
sub sortkbyv {

    my $hash = shift;

    if( ref( $hash ) eq 'HASH' ) {

        return sort { $$hash{$a} cmp $$hash{$b} } keys %$hash;

    }#if

    return undef;

}#sortkbyv

# ------------------------------------------------------------------------------
# subhash REF, KEY, VALUE
#
# Return the matching subhashes, which have KEY eq VALUE
# 
# VALUE can be:
#
#   'exactmatch'
#   '~regex'
#
# The '~' is used to make the determination.
#
# Return value:
#
#   When there *are* matches:
#       wantarray ? all matches
#       otherwise   the first match
#   otherwise,
#       wantarray ? an emtpy list
#       otherwise,  undef
# ------------------------------------------------------------------------------

sub subhash {

    my ($ref, $key, $value) = @_;

    my @matches = ();

    my $target = ();

    if( ref($ref) eq 'ARRAY' ) {

        $target = $ref;

    } elsif( ref($ref) eq 'HASH' ) {

        $target = [ values %$ref ];

    } else {

        die "How can subhashes exist in: $ref";

    }#if

    my $tilde = substr $value, 0, 1;

    my $useregex = $tilde eq '~' ? 1 : 0;

    $useregex and substr $value, 0, 1, ""; # trim

    foreach my $subhash ( @$target ) {

        if( $useregex && ($$subhash{$key} =~ /$value/) ) {

            push @matches, $subhash;

        } elsif( $$subhash{$key} eq $value ) {
        
            push @matches, $subhash;

        }#if

    }#foreach

    if( @matches ) {

        wantarray and return @matches;

        return shift @matches; # only return the first match

    }#if

    wantarray and return @matches;

    return undef;

}#subhash

# ------------------------------------------------------------------------------
# cpref - Recursively clone the reference, returning a new reference.
#
# The Clone module found on CPAN crashes under my mod_perl and FastCGI
# test servers...
#
# Note: Have not tested recursive references.
# ------------------------------------------------------------------------------

sub cpref {

    my $opts = { 'sdref' => 0 };

    Hub::opts( \@_, $opts );

    my $ref = shift;

    my $new = ();

    return $ref unless ref($ref);

    for( ref($ref) ) {

        $_ eq 'HASH' and do {

            $new = {};

            keys %$ref; # reset iterator

            while( my($k,$v) = each %$ref ) {

                if( ref($v) ) {

                    $new->{$k} = Hub::cpref($v, -opts => $opts) unless $v eq $ref;

                } else {

                    $new->{$k} = $v;

                }#if

            }#while

            last;

        };

        $_ eq 'ARRAY' and do {

            $new = [];

            foreach my $v ( @$ref ) {

                if( ref($v) ) {

                    push @$new, Hub::cpref($v, -opts => $opts);

                } else {

                    push @$new, $v;

                }#if

            }#foreach

            last;

        };
    
        $_ eq 'SCALAR' and do {

            if( $$opts{'sdref'} ) {

                # De-reference scalars

                $new = $$ref;

            } else {

                my $tmp = $$ref;

                $new = \$tmp;

            }#if

            last;

        };
        
        $_ eq 'Fh' and do {

            # Just copy the filename from file handles

            $ref =~ /(.*)/ and $new = $1;

            last;

        };
    
        $_ eq 'REF' and do {

            $$ref eq $ref and
                warn "Self reference cannot be copied: $ref";

            ($$ref ne $ref) and $new = Hub::cpref( $$ref, -opts => $opts );

            last;

        };
    
        Hub::check('-test=blessed', $ref) and do {

            eval( '$new = ' . ref($ref) . '->new()' );

            $@ and die $@;

            keys %$ref; # reset

            while( my ($k,$v) = each %$ref ) {

                $new->{$k} = Hub::cpref( $v, -opts => $opts );

            }#while

            last;

        };

    }#for
    
    return $new;

}#cpref

# ------------------------------------------------------------------------------
# Hub::checksum( @params )
#
# Create a unique identifier for the provided data
#
# Params can be scalars, hash references, array references and the like.  We
# use the HashFile's print routine to transform nested structures into flat
# strings.  As for performance, improvements should be made in the HashFile
# module.  The only reason I create a new instance of HashFile each time is
# because I know there are symbol tables (such as the order of elements) in 
# that class which get update when the print method is called.
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

sub getbyname {

    my $fully_qualified_id  = shift;
    my $hash                = shift;

    return unless ref($hash);

    my @parts = split /:/, $fully_qualified_id;

    $fully_qualified_id and push @parts, $fully_qualified_id unless @parts;

    my $ptr = $hash;

    my $ret = undef;

    my ($parent, $child, $parent_part) = undef;

    my $level = 0;

    return undef unless @parts;

    foreach my $part ( @parts ) {

        $part eq "" and next;

        if( ref($ptr) eq 'ARRAY' ) {

            $ret    = undef;
            $parent = undef;

            foreach my $item ( @{$ptr} ) {

                if( ref($item) eq 'HASH' ) {

                    if(    ($$item{'_id'}   eq $part)
                        || ($$item{'id'}    eq $part)
                        || ($$item{'name'}  eq $part) ) {

                        $parent = $ptr;
                        $ret    = $item;
                        $ptr    = $item;

                        last;

                    }#if
                    
                }#if

            }#foreach

        } else {

            if( ref($ptr) ne 'HASH' ) {

              return undef;

            }#if

            $parent         = $ptr;
            $parent_part    = $part;
            $ret            = $ptr->{$part};
            $ptr            = $ptr->{$part};

        }#if

        $child = $part;

        $level++;

    }#foreach

    return $ret;

}#getbyname

# ------------------------------------------------------------------------------
# merge TARGET_HREF, SOURCE_HREF..., OPTION...
#
# Merges the provided hashes.  The first argument (destination hash) has
# precedence (as in values are NOT overwritten) unless --overwrite is given.
#
# OPTIONS:
#
#   --overwrite             Overwrite values as they are encounterred.
#
#   --prune                 Gives the destination hash the same structure as
#                           the source hash (or the composite of all which is
#                           in common when multiple source hashes are provided).
#
#                           If the destination is missing a value, it is
#                           initialized from the source hash.
#
#                           If the destination has a value which is not in all
#                           of the source hashes, it is deleted.
#
#   --keeparrays            When the destination contains the same key as the
#                           source, but the destination is an array where the 
#                           source is a hash, take all of the hash elements and
#                           merge them into the array.
#
# ------------------------------------------------------------------------------

sub merge {

    my $dh = shift || return; # destination hash

    return unless ref($dh) eq 'HASH';

    my @sources = ();
    my $flags   = '';

    foreach my $arg ( @_ ) {

        if( ref($arg) eq 'HASH' ) {
        
            push @sources, $arg;

        } elsif( $arg =~ "^--" ) {

            $flags .= $arg;

        }#if

    }#foreach

    foreach my $sh ( @sources ) {

        &_mergeHash( $dh, $sh, $flags );

    }#foreach

    return $dh;

}#merge

sub _mergeHash {

    my ($dh,$sh,$flags) = @_;

    if( $flags =~ /--prune/ ) {

        my @d_keys = keys %$dh;

        foreach my $k ( @d_keys ) {

            delete $$dh{$k} unless defined $$sh{$k};
        
        }#foreach

    }#if

    keys %$sh; # reset iterator

    while( my($k,$v) = each %$sh ) {

        &_mergeElement( $dh, $k, $v, $flags );

    }#while

}#_mergeHash

sub _mergeArray {

    my ($da,$sa,$flags) = @_; # destination array, source array

    my $dh = {};

    map { $$dh{&_getId($_)} = $_ } @$da;

    my @d_keys = keys %$dh;

    foreach my $i ( @$sa ) {

        my $id = &_getId( $i );

        if( grep /^$id$/, @d_keys ) {

            if( (ref($i) eq 'HASH') && ref($$dh{$id}) ) {

                &_mergeHash( $$dh{$id}, $i, $flags );

            }#if

        } else {

            push @$da, $i unless grep /^$id$/, @d_keys;
        
        }#if

    }#foreach

}#_mergeArray

sub _getId {

    my $h  = shift || return;
    my $id = "";

    if( ref($h) eq 'HASH' ) {
    
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

    my ($dh, $k, $v, $flags) = @_;

    if( defined($$dh{$k}) ) {

        my $c = ref($v); # class

        if( $c ) {

            if( $c eq ref($$dh{$k}) ) {

                $c eq 'HASH' and &_mergeHash( $$dh{$k}, $v, $flags );

                $c eq 'ARRAY' and &_mergeArray( $$dh{$k}, $v, $flags );

            } elsif( ($flags =~ "--keeparrays") &&
                     (ref($$dh{$k}) eq 'ARRAY') && ($c eq 'HASH') ) {

                my @sa = Hub::asarray( $v );

                &_mergeArray( $$dh{$k}, \@sa, $flags );

            } else {

                # do not chage the type (unless overwriting)

                $flags =~ "--overwrite" and $$dh{$k} = $v;

            }#if

        } else {

            $flags =~ "--overwrite" and $$dh{$k} = $v;

        }#if

    } else {

        my $vcopy = Hub::cpref($v);

        $$dh{$k} = defined($vcopy) ? $vcopy : "";

    }#if

}#_mergeElement

# ------------------------------------------------------------------------------
# asarray HASHREF|ARRAYREF [KEY] [OPTIONS]
# 
# Turn a hashref of hashref's, or an array of hashref's into an array.
#
# Sort by KEY
#
# OPTIONS
#
#  --asref              Return a reference instead
#  --lose               Lose the key (for hash references)
#  --filter:key=val     Only include items where key eq val
#
# Unless --lose is specified,  we will modify the provided hash, storing the
# outer key as '_id' of each subhash.
# ------------------------------------------------------------------------------

sub asarray {

    my $ref         = shift || return ();

    my $key         = DEFAULTSORTKEY;
    my @array       = ();
    my $flags       = '';
    my $filterkey   = '';
    my $filterval   = '';

    foreach my $arg ( @_ ) {

        next unless $arg;

        if( $arg =~ /--filter:(\w+)=(.*)/ ) {

            $filterkey = $1;

            $filterval = $2;

        } elsif( $arg =~ "^--" ) {

            $flags .= $arg;

        } else {

            $key = $arg;

        }#if

    }#foreach

    $SORT_KEY = $key;

	if( ref($ref) eq 'HASH' ) {

        map { $$ref{$_}->{'_id'} = $_ } keys %$ref unless $flags =~ /--lose/;

        if( $filterkey ) {

            my @filtered = subhash( $ref, $filterkey, $filterval );

            @array = sort { &_prioritysort } @filtered;

        } else {

            @array = sort { &_prioritysort } values %$ref;

        }#if

    } elsif( ref($ref) eq 'ARRAY' ) {

        if( $filterkey ) {

            my @filtered = subhash( $ref, $filterkey, $filterval );

            @array = sort { &_prioritysort } @filtered;

        } else {

            @array = sort { &_prioritysort } @$ref;

        }#if

    }#if

    return $flags =~ /--asref/ ? \@array : @array;

}#asarray

# ------------------------------------------------------------------------------
# _prioritysort
# 
# Sorts by a key, with the intention of re-ordering.  In order to do so, the
# secondary sort key is set to the *old* value of the item.  For instance, we
# have three items, with sort values 1, 1, and 2:
#
#   item1: 0
#   item2: 1
#   item3: 2
#
# So, to move item1 to the second position, set the _sort key to 1, and the 
# _sort2 key to 0 (it's old value).
# ------------------------------------------------------------------------------

sub _prioritysort {

    return $a cmp $b
        unless( ref($a) eq 'HASH'
            && ref($b) eq 'HASH' );

    my $A = $$a{$SORT_KEY};

    my $B = $$b{$SORT_KEY};

    # Primary sort

    my $r = _compscalar( $A, $B );

    $r = 1 unless defined $A;

    $r = -1 unless defined $B;

    if( $r == 0 ) {

        my $A2 = $$a{$SORT_KEY."2"};

        my $B2 = $$b{$SORT_KEY."2"};

        if( defined $A2 && defined $B2 ) {

            $r = _compscalar( $A2, $B2 );

        } else {

            defined $A2 and $r = ($A2 < $B) ? 1 : -1;

            defined $B2 and $r = ($A < $B2) ? 1 : -1;

        }#if

    }#if

    my $x = $$a{'name'};

    my $y = $$b{'name'};

    return $r;

}#_prioritysort

# ------------------------------------------------------------------------------
# _compscalar
# 
# Use cmp or <=> if the data is all numbers (decimal points included)
# ------------------------------------------------------------------------------

sub _compscalar {

    my ($a,$b) = @_;

    return 1 if $a eq 'LAST';

    return -1 if $b eq 'LAST';

    $a.$b =~ /^[\.\d]+$/ and return $a <=> $b;

    return $a cmp $b;

}#_compscalar

# ------------------------------------------------------------------------------
sub flatten {

    my $ptr = shift || return;
    my $buf = "";

    if( ref($ptr) =~ /(HASH|::)/ ) {

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

                }#if

            }#if

        }#foreach

    } elsif( ref($ptr) eq 'ARRAY' ) {

        foreach my $v ( sort @$ptr ) {

            if( ref( $v ) ) {

                $buf .= Hub::flatten( $v );

            } else {

                $buf .= $v;

            }#if

        }#foreach

    }#if

    return $buf;

}#flatten

# ------------------------------------------------------------------------------
# subfield POS, DELIMITER, STRING
# 
# Given a delimited string, return the substring given a field position (zero
# based).
# ------------------------------------------------------------------------------

sub subfield {

    my ($pos,$delim,$str) = @_;

    my @parts = split $delim, $str;

    if( ($pos > 0) && ($pos <= $#parts) ) {

        return $parts[$pos];

    }#if

}#subfield

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
# diff &HASH, &HASH
#
# Creates a nest of the differences between the two provided.  If a conflict of
# types (with the same key) is encounterred, the right-hand sturcture is used.
#
# NOTE: Although this routine compares contents, it returns references to the 
# original hashes (use cpref on the result to detatch.)
# ------------------------------------------------------------------------------

sub diff {

    my ($l,$r) = @_;

    my $h = _diff_hashes( $l, $r );

    return $h;

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

                }#if

            } else {

                $h->{$key} = $r->{$key};

            }#if

        } else {

            $h->{$key} = $l->{$key};

        }#if

    }#while

    my @rkeys = keys %$r;

    while( my $key = shift @rkeys ) {

        $h->{$key} = $r->{$key} unless defined $l->{$key};

    }#while

    return $h;

}#_diff_hashes

# ------------------------------------------------------------------------------
# _diff_arrays &ARRAY, &ARRAY
# 
# Difference between two arrays.
# ------------------------------------------------------------------------------

sub _diff_arrays {

    my ($l,$r) = @_;

    return unless ref($l) eq 'ARRAY';

    return unless ref($r) eq 'ARRAY';

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

            }#if

        } else {

            push @$a, $rval;

        }#if

        $idx++;

    }#foreach

    if( $#$l > $#$r ) {

        foreach my $idx ( ($#$r + 1) .. $#$l ) {

            push @$a, $l->[$idx];

        }#for

    } else {

        foreach my $idx ( ($#$l + 1) .. $#$r ) {

            push @$a, $r->[$idx];

        }#for

    }#if

    return $a;

}#_diff_arrays

# ------------------------------------------------------------------------------
# dice - Break apart the string
#
# dice STRING
# ------------------------------------------------------------------------------
#|test(match,a;{b{c}};c;{d}) join( ';', dice( "a{b{c}}c{d}" ) );
# ------------------------------------------------------------------------------

sub dice {

    my $opts = {

        'beg' => {
            'char'  => '{',
            'str'   => '{',
            'len'   => 1,
        },

        'end' => {
            'char'  => '}',
            'str'   => '}',
            'len'   => 1,
        },

    };

    Hub::opts( \@_, $opts );

    my $text        = shift;

    my @result      = ();

    my %beg = %{$$opts{'beg'}};

    my %end = %{$$opts{'end'}};

    #
    # find the beginning
    #

    my ($p,$p2,$p3) = (0,0,0);

    while( ($p = index( $text, $beg{'str'}, 0 )) > -1 ) {

        #
        # find the end
        #

        my $p2 = $p + $beg{'len'}; # start of the current search

        my $p3 = index( $text, $end{'char'}, $p2 ); # point of closing

        while( $p3 > -1 ) {

            my $ic = 0; # inner count

            my $im = index( $text, $beg{'char'}, $p2 ); # inner match
            
            while( ($im > -1) && ($im < $p3) ) {

                $ic++;

                $p2 = ($im + 1);

                $im = index( $text, $beg{'char'}, $p2 );

            }#while

            last unless $ic > 0;

            for( 1 .. $ic ) {

                $p3 = index( $text, $end{'char'}, ($p3 + 1) );

            }#for

        }#while

        if( $p3 > $p ) {

            my $str = substr( $text, $p, (($p3 + $end{'len'}) - $p) );

            my $left = substr( $text, 0, $p );

            my $right = substr( $text, $p + length($str) );

            push @result, $left, $str;

            $text = $right;

        } else {

            croak "Unmatched $beg{'str'}";

        }#if

    }#while

    $text and push @result, $text;

    return @result;

}#dice

# ------------------------------------------------------------------------------

1;
