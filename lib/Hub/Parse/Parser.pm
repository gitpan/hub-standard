package Hub::Parse::Parser;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our @EXPORT     = qw//;
our @EXPORT_OK  = qw/

    PARSER_VAR_BEGIN
    PARSER_VAR_END
    PARSER_TWEAK_CHAR

/;

use constant {

    PARSER_VAR_BEGIN    => '<#',
    PARSER_VAR_END      => '>',
    PARSER_TWEAK_CHAR   => ';',

};

# ------------------------------------------------------------------------------
# new
# 
# Constructor.
# ------------------------------------------------------------------------------

sub new {

	my $self = shift;

	my $class = ref( $self ) || $self;

	my $obj = bless {}, $class;

    $obj->refresh( @_ );

    return $obj;

}#new

# ------------------------------------------------------------------------------
# refresh
# 
# Return instance to initial state.
# ------------------------------------------------------------------------------

sub refresh {

    my ($self,$opts) = Hub::objopts( \@_ );

    @_ and $$opts{'template'} ||= shift;

    $self->{'template'}     = '';
    $self->{'var_begin'}    = PARSER_VAR_BEGIN;
    $self->{'var_end'}      = PARSER_VAR_END;
    $self->{'tweak_char'}   = PARSER_TWEAK_CHAR;
    $self->{'tweakers'}     = [ \&tweaker ];
    $self->{'values'}       = [];

    for( qw/template var_begin var_end tweak_char/ ) {

        Hub::hsetv( $self, $_, $$opts{$_} ) if defined $$opts{$_};

    }#for

    $self->{'beg_char'} = substr $self->{'var_begin'}, 0, 1;
    $self->{'end_char'} = substr $self->{'var_end'}, 0, 1;

    $self->{'idle_depth'}   = $Hub->getcv( 'idle_depth' ) || 10;
    $self->{'mirror_depth'} = $Hub->getcv( 'mirror_depth' ) || 1000;

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
#|test(match)   my $parser = mkinst( 'Parser', -template => 'Hello <#who>' );
#|              ${$parser->populate( { who => 'World' } )};
#~              Hello World
# ------------------------------------------------------------------------------

sub populate {

    my ($self,$opts) = Hub::objopts( \@_ );

    $self->{'values'} = \@_;

    return $self->_populate();

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
    
    my ($self,$opts) = Hub::objopts( \@_ );

    my $text = defined $$opts{'text'} ? $$opts{'text'} : $self->{'template'};

    ref($text) eq 'SCALAR' and $text = $$text;

    my $BEGIN           = $self->{'var_begin'};
    my $END             = $self->{'var_end'};
    my $BEGINCHAR       = $self->{'beg_char'};
    my $ENDCHAR         = $self->{'end_char'};
    my $IDLE_DEPTH      = $self->{'idle_depth'};
    my $MIRROR_DEPTH    = $self->{'mirror_depth'};

    my %watch = ();

    my %skip = ();

    my $p = 0; # main file pointer as we progress

    while( $p > -1 ) {

        #
        # find the beginning of a variable definition: '<#'
        #

        $p = index( $text, $BEGIN, $p );

        $watch{$p}++;

        if( $watch{$p} > $IDLE_DEPTH ) {

            my $hint = substr( $text, $p, 20 );

            Hub::lerr( "[Idle > $IDLE_DEPTH] Stopping population at[$p]: $hint..." );

            #move on
            $p++;

        }#if

        if( $p > -1 ) {

            #
            # find the end of this definition: '>'
            #

            my $p2 = $p + length($BEGIN); # start of the current search

            my $p3 = index( $text, $ENDCHAR, $p2 ); # point of closing

            while( $p3 > -1 ) {

                my $ic = 0; # inner count

                my $im = index( $text, $BEGINCHAR, $p2 ); # inner match
                
                while( ($im > -1) && ($im < $p3) ) {

                    $ic++;

                    $p2 = ($im + 1);

                    $im = index( $text, $BEGINCHAR, $p2 );

                }#while

                last unless $ic > 0;

                for( 1 .. $ic ) {

                    $p3 = index( $text, $ENDCHAR, ($p3 + 1) );

                }#for

            }#while

            if( $p3 > $p ) {

                # inside the '<#' .. '>' marks
                my $inner_str = substr( $text, ($p + length($BEGIN)), ($p3 - ($p + length($BEGIN))) );

                # include the '<#' and '>' marks
                my $outer_str = substr( $text, $p, (($p3 + length($END)) - $p) );

                if( index( $inner_str, $BEGIN ) == 0 ) {

                    # this is an embedded value which should resolve to a name
                    my $inner_val = ${$self->_populate( -text => \$inner_str )};

                    if( $inner_val ) {

                        # replace

                        # [A]
                        #$text =~ s/$inner_str/$inner_val/g;

                        # [B]
                        substr $text, $p + length($BEGIN), length($inner_str), $inner_val;

                        # [C]
                        #my $left = substr( $text, 0, ($p + 2) );
                        #my $right = substr( $text, ($p + 2) + length($inner_str) );
                        #$text = $left . $inner_val . $right;

                        next;

                    } else {

                        # move on
                        $p += length( $outer_str );

                        next;

                    }#if

                }#if

                my @params = split /[\s]+/, $inner_str;

                my $name = shift @params;

                my $scope = Hub::attrhash( @params ) if @params;

                #
                # Maybe there are tweaks which we should perform
                #

                my @tweaks = split $self->{'tweak_char'}, $name;

                $name = pop @tweaks;

                #
                # We have a variable ($name) which may have attributes (%$scope)
                # and we will now look for values.
                #

                my $value = undef;

                if( $skip{$name} ) {

                    $p += 2; # next

                } else {

                    foreach my $h ( @_, @{$self->{'values'}} ) {

                        if( Hub::check( '-ref=HASH', $h ) ) {

                            $value = Hub::hgetv( $h, $name );

                            if( defined $value ) {

                                Hub::fear( REF => $value );

                                $value = $$value if( ref($value) eq 'SCALAR' );

                                if( @tweaks ) {
                                
                                    $value = $self->_tweak( $value, $scope, @tweaks );

                                }#if

                                if( ref($value) eq 'ARRAY' ) {
                                
                                    unless( @$value ) {

                                        # Prevent empty arrays from becoming
                                        # scalars such as: ARRAY(0x1079b9e0)

                                        $value = '';

                                        last;

                                    }#unless

                                    my $newval = ();

                                    foreach my $v ( @$value ) {

                                        next unless defined $v;

                                        if( Hub::check( '-test=blessed', $v ) ) {

                                            $newval .= ${$v->populate()};

                                        } elsif( ref($v) eq 'HASH' ) {

                                            $newval .= ${ $self->_populate(
                                                -text => $$v{'text'}, $$v{'value'} ) };

                                        } elsif( ref($v) eq 'SCALAR' ) {

                                            $newval .= $$v;

                                        } elsif( ref($v) ) {

                                            Hub::lerr( "Parser cannot populate: $v" );

                                        } else {

                                            $newval .= $v;

                                        }#if

                                    }#foreach

                                    $value = $newval;

                                }#if

                                if( defined $value && defined $scope && %$scope ) {

                                    my $orig = $value;

                                    $value = ${$self->_populate( -text => \$value, $scope )};

                                    if( $orig eq $value ) {

                                        my $attrs = Hub::hashtoattrs( $scope );

                                        # If the value looks like an html tag, we insert
                                        # the scope as attributes before any other attributes

                                        $value =~ s/^(\s*<[\w]+)/$1 $attrs/;

                                    }#if

                                }#if

                                last;

                            }#if

                        }#if

                    }#foreach

                    if( defined($value) ) {

                        if( (index( $value, "$BEGIN$name$END" ) > -1) ) {

                            # TODO: Look for the NEXT occurance of $name in the hashes

                            Hub::lerr( "Stopping population as value contains key: $name" )
                                unless ($value eq "$BEGIN$name$END");

                            $p += 2; # next

                        } elsif( $watch{$name} && $watch{$name} > $MIRROR_DEPTH ) {

                            Hub::lerr( "Stopping population as mirror depth ($MIRROR_DEPTH) " .
                                "has been reached for: $name" );

                            $p += 2; # next

                        } else {

                            $watch{$name}++;

                            # [A]
                            # this cannot be done with tweaks
                            #$text =~ s/$outer_str/$value/g;

                            # [B]
                            substr $text, $p, length($outer_str), $value;

                            # [C]
                            #my $left = substr( $text, 0, $p );
                            #my $right = substr( $text, $p + length($outer_str) );
                            #$text = $left . $value . $right;

                        }#if

                    } elsif( $name =~ /\.html$/ ) {

                        my $path = Hub::abspath( $name );

                        if( $path ) {

                            my $template = Hub::mkinst( 'Template', $name );

                            $value = ${$template->populate($scope)};

                        } else {

                            Hub::lerr( "Parser cannot find: $name.html" );

                        }#if

                        if( defined($value) ) {

                            substr $text, $p, length($outer_str), $value;

                        } else {

                            $skip{$name} = 1;

                            $p += 2; # next

                        }#if

                    } else {

                        if( 0 && @tweaks ) {
                        
                            $value = $self->_tweak( $value, $scope, @tweaks );

                            if( defined($value) ) {

                                substr $text, $p, length($outer_str), $value;

                            } else {

                                $skip{$name} = 1;

                            }#if

                        }#if

                        $skip{$name} = 1;

                        $p += 2; # next

                    }#if

                }#if

            } else {

                # unterminated variable

                my $hint = substr( $text, $p, 20 );

                Hub::lerr( "Unterminated variable ($p3) at char[$p]: $hint..." );

                last;

            }#if
        
        }#if

    }#while

    return \$text;

}#_populate

# ------------------------------------------------------------------------------
# _tweak
# 
# Internal function.
# Tweak values.
# Subroutine for tweaking must be provided in the constructor.
# ------------------------------------------------------------------------------

sub _tweak {

    my ($self,$opts) = Hub::objopts( \@_ );

    my $value = shift;

    foreach my $tweaker ( @{$self->{'tweakers'}} ) {

        if( ref($tweaker) eq 'CODE' ) {

            &$tweaker( ref($value) ? $value : \$value, @_ ) and last;

        }#if

    }#if

    return $value;

}#_tweak

# ------------------------------------------------------------------------------
# tweaker \$value, $tweak+
#
# Tweaks allow modification to variable values.  This is expensive, and hence
# should be used only as a last resort.
#
# No spaces are allowed in the tweak name!
#
# Variables have to be specified as {#name} (not <#name>) because of the use
# of s/name/value/g in the main populate routine.
#
# Implemented tweaks:
#
#   !                   # Run command (custom tweak)
#
#   tr///               # transliterates search chars with replacement chars
#   lc                  # lower case
#   uc                  # upper case
#   lcfirst             # lower case first letter
#   ucfirst             # upper case first letter
#   x=                  # repeat the value so many times
#
#   esc                 # escape non-word characters
#   html                # replace '<' and '>' with '&lt;' and '&gt;'
#
#   num                 # number (will use zero '0' if empty)
#   dt(opts)            # datetime with options (see datetime).
#   dhms(opts)          # day/hour/min/sec with options (see dhms).
#
#   eq                  # equal
#   ne                  # not equal
#   gt                  # greater than
#   lt                  # less than
#   if                  # is greater than zero (or non-empty string)
#
#   -                   # minus
#   +                   # plus
#   *                   # multiply
#   /                   # divide
#   %                   # mod
# ------------------------------------------------------------------------------

sub tweaker {

    my $value = shift;
    my $scope = shift;

    my $matched = 0;

    foreach my $tweak ( @_ ) {

        my ($opr,$opr1,$opr2,$num,$opts) = ();

        if( $tweak =~ /^!(\w+)\(([^\)]*)\)$/ ) {

            my ($module,$params) = ($1,$2);

            $value = Hub::modexec( '-in=tweaks', $module,
                [ $value, split( /[=,]/, $params ) ] );

        } elsif( $tweak =~ /^(lc|uc|ucfirst|lcfirst)$/ ) {

            $$value = eval( "$1( '$$value' )" ) if $$value;

        } elsif( $tweak =~ /x=([0-9]+)/ ) {

            $$value = $$value;

            $$value x= $1;

        } elsif( $tweak =~ /^tr\/(.*?)\/(.*?)\/([a-z]*)$/ ) {

            $$value = $$value;

            eval( "\$\$value =~ tr/$1/$2/$3" );

        } elsif( $tweak =~ /^if\([\s"']*([^'"]*)[\s"']*\)$/ ) {

            $opr1 = $1;

            $$value = $opr1 ? $$value : '';

        } elsif( $tweak =~ /^unless\([\s"']*([^'"]*)[\s"']*\)$/ ) {

            $opr1 = $1;

            $$value = $opr1 ? '': $$value ;

        } elsif( $tweak =~ /^(\-|\+|\/|\*|\%)(\d+)$/ ) {

            $opr  = $1;
            $opr1 = $2;

            if( $$value =~ /(\d+)/ ) {

                $num = $1;

                my $rslt = eval( "$num $opr $opr1" );

                $$value = $$value;

                $$value =~ s/$num/$rslt/;

            } elsif( !$$value ) {

                $num  = 0;

                $$value = eval( "$num $opr $opr1" );

            }#if

        } elsif( $tweak =~ /^(eq|ne|gt|lt)\([\s"']*([^'",]+)[\s"']*[,]?[\s"']*([^'",]*)[\s"']*\)$/ ) {

            my $cond = $1;
            $opr1 = $2;
            $opr2 = $3;

            unless( defined $opr2 ) {

                $opr2 = $opr1;
                $opr1 = $$value;

            }#unless

            my $true = eval( "\$opr1 $cond \$opr2" );

            $$value = '' unless $true;

        } elsif( $tweak =~ /^(html|nbsp)$/ ) {

            $$value = eval( "Hub::$1( \$value )" );

        } elsif( $tweak =~ /^esc$/ ) {

            $$value =~ s/(?<!\\)(\W)/\\$1/g;

        } elsif( $tweak eq "num" ) {

            $$value = "0" unless $$value;

        } elsif( $tweak =~ /^dt\(?(.*?)\)?$/ ) {

            $opts = $1;

            $$value =~ /^[\d\.]+$/ and $$value = Hub::datetime( $$value, $opts );

        } elsif( $tweak =~ /^dhms[\(]?(.*?)[\)]?$/ ) {

            $opts = $1;

            $$value =~ /^\d+$/ and $$value = Hub::dhms( $$value, $opts );

        } elsif( $tweak =~ /^sort\(?([^\)]*)\)?$/ ) {

            my $on = defined $1 ? $1 : '';

            if( ref($value) eq 'ARRAY' ) {

                Hub::anonsort( $value, "-on=$on", "-modify=1" );

            }#if

        } else {

            $matched = 0;

        }#if

        $@ and Hub::lerr( "Tweak error ($tweak): " . chomp($@) );

    }#foreach

    return $matched;

}#tweaker

# ------------------------------------------------------------------------------
return 1;


'???';
