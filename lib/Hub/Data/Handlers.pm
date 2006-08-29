package Hub::Data::Handlers;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;
use Hub qw/:lib/;

=pod:summary Nested data handlers

=pod:synopsis

    use Hub qw(:standard);
    my $h = {};
    hsetv( $h, "/user1/fname",  "Steve" );
    hsetv( $h, "/user2/fname",  "Mandy" );

=pod:description

See also L<hubaddr>

=cut

our @EXPORT         = qw//;

our @EXPORT_OK      = qw/

    hgetv
    hsetv
    happendv
    htakev

/;

our $DELIMS         = ':/';

our $ARRAYTAG       = '\[([0-9]+)\]';

# ------------------------------------------------------------------------------
# hgetv - Hash Get Value
#
# hgetv \%HASH, $ADDRESS, [OPTIONS]
# hgetv \%HASH, \@ADDRESSES, [OPTIONS]
#
# In its first form, hgetv will return the value specified by $ADDRESS.
#
# In its second form, an array of values is returned for each @ADDRESS.  In 
# scalar context the array is returned as a reference.
#
# OPTIONS:
#
#   -sdref=0    Do *not* de-reference scalar values.
# ------------------------------------------------------------------------------

sub hgetv {

    my ($opts,$hash,$addr) = Hub::opts( \@_, { 'sdref' => 1, } );

    if( ref($addr) eq 'ARRAY' ) {

        my @vals = ();

        foreach my $k ( @$addr ) {

            my $v = _hqueryv( $hash, $k );

            (ref($v) eq 'SCALAR') && $$opts{'sdref'} and $v = $$v;

            push @vals, $v;

        }#foreach

        return wantarray ? @vals : [@vals];

    } else {

        my $v = _hqueryv( $hash, $addr );

        (ref($v) eq 'SCALAR') && $$opts{'sdref'} and $v = $$v;

        return $v;

    }#if

}#hgetv

# ------------------------------------------------------------------------------
# hsetv - Hash Set Value
#
# hsetv \%HASH, $ADDRESS, $VALUE
# hsetv \%HASH, \%ADDRESS
#
# In its first form, VALUE is set in \%HASH at $ADDRESS.
#
# In its second form, \%ADDRESS is presumed to be ADDRESS/VALUE pairs, and each
# is set in turn.
# ------------------------------------------------------------------------------

sub hsetv {

    my ($hash,$addr,$val) = @_;

    if( ! ref($addr) ) {

        $addr = { $addr => $val };

    }#if

    keys %$addr; # reset

    while( my ($k,$v) = each %$addr ) {

        my $p = _hqueryv( $hash, $k, -av );

        croak "Cannot autovivify '$k'" unless defined $p;

        if( ref($p) eq 'ARRAY' ) {
        
            @$p = @$v;

        } else {

            $$p = $v;

        }#if

    }#foreach

}#hsetv

# ------------------------------------------------------------------------------
# htakev - Hash Take Value
#
# htakev \%HASH, $ADDRESS
# htakev \%HASH, \@ADDRESSES
# 
# Remove and return the value (like L<hgetv>.)
#
# In its second form, the removed values are returned as an array reference.
# ------------------------------------------------------------------------------

sub htakev {

    my ($hash,$addr) = @_;

    my $tmp = hgetv( $hash, $addr );

    foreach my $k ( ref($addr) eq 'ARRAY' ? @$addr : $addr ) {

        my @parts = Hub::dice( $k );

        $k = pop @parts;

        if( @parts ) {

            my $parent = _hqueryv( $hash, join( '/', @parts) );

            my ($select) = $k =~ /\A\{(.*)\}\Z/;

            my $indicies = _hselectv( $hash, $parent, $select );

            if( defined $indicies && @$indicies ) {

                for( my $offset = 0; $offset < @$indicies; $offset++ ) {

                    local $_ = $$indicies[$offset];

                    ref($parent) =~ /HASH|::/ and delete $$parent{$_};

                    ref($parent) eq 'ARRAY'
                        and splice @$parent, ($_ - $offset), 1;

                }#for

            }#if

        } else {

            my $node = Hub::varname( $k );

            my $parent = hgetv( $hash, Hub::varparent( $k ) );

            ref($parent) =~ /HASH|::/ and delete $$parent{$node};

            ref($parent) eq 'ARRAY' and
                splice @$parent, _lookup( $parent, $node, -asindex ), 1;

        }#if

    }#foreach

    return $tmp;

}#htakev

# ------------------------------------------------------------------------------
# happendv - Hash Append Value
#
# happendv \HASH, $ADDRESS, VALUE, OPTIONS*
# 
# Append to an existing value and return like L<hgetv>.
#
# OPTIONS:
#
#   -asa=1      Force value as array (transforms existing scalars.)
# ------------------------------------------------------------------------------

sub happendv {

    my ($opts,$hash,$key,$val) = Hub::opts( \@_ );

    my $tmp = hgetv( $hash, $key, '-sdref=0' );
    
    if( defined $tmp ) {

        if( ref($tmp) eq 'ARRAY' ) {

            push @$tmp, $val;

        } elsif( ref($tmp) eq 'SCALAR' ) {

            if( $$opts{'asa'} ) {

                $tmp = _appendvasa( $hash, $key, $val );

            } else {

                $$tmp .= $val;

            }#if

        } else {

            croak "Cannot append: " . $tmp;

        }#if

    } else {

        $tmp = _appendvasa( $hash, $key, $val );

    }#if

    return $tmp;

}#happendv

# ------------------------------------------------------------------------------
# _hseekv - Hash Seek Value (Seek to the specified address)
#
# _hseekv \%HASH, $ADDRESS, [OPTIONS]
#
# OPTIONS:
#
#   -av     Autovivify (contstucts necessary segments)
#
# This is an optimization and as such $ADDRESS may *not* contain selectors.
#
# Autovivification will return a SCALAR reference on nodes which are unkown.
# Such that calling:
#
#   my $c = _hseekv( \%hash, '/a/b/c', '-av' );
#
# May become an array by subsequently:
#
#   @$$c = qw/fourteen hair/;
#
# And seeking again will return an ARRAY reference:
#
#   my $c2 = _hseekv( \%hash, '/a/b/c' );
#
# Such that:
#
#   push @$c2, 'dryers';
#
# ------------------------------------------------------------------------------

sub _hseekv {

    my ($opts,$hash,$key) = Hub::opts( \@_, { 'av' => 0, } );

    $key =~ s/\A[$DELIMS]|[$DELIMS]\Z//g;

    my $ptr = $hash;

    my $tmp = $ptr;

    my $part_idx = 0;

    my @parts = split /[$DELIMS]/, $key;

    for( @parts ) {

        $tmp = ref($tmp) =~ /HASH|::/ ?

            defined $$tmp{$_} ? \$$tmp{$_} : undef
            
        : ref($tmp) eq 'ARRAY' ?

            /\A$ARRAYTAG\Z/ ?  

                defined $$tmp[$1] ? \$$tmp[$1] : undef

            : _lookup( $tmp, $_ )
            
        : undef;

        last unless defined $tmp;

        $part_idx++;

        $tmp = $$tmp if ref($tmp) eq 'REF';

        $ptr = $tmp;

    }#for

    if( defined $tmp ) {

        $tmp = $$tmp if( ref($tmp) eq 'REF' );

        return $tmp;

    } elsif( $$opts{'av'} ) {

        # Autovivify

        $tmp = $ptr;

        my ($val,$new,$subkey) = ();

        for( $part_idx .. $#parts ) {

            $subkey = $parts[$_] =~ /\A$ARRAYTAG\Z/ ? $1 : $parts[$_];

            $new = $_ eq $#parts ? $val : $parts[$_+1] =~ /\A$ARRAYTAG\Z/ ?
                [] : {};

            if( defined $new ) {

                ref($tmp) =~ /HASH|::/  and $$tmp{$subkey} = $new;

                ref($tmp) eq 'ARRAY'    and $$tmp[$subkey] = $new;

            }#if

            $tmp = $new if defined $new;

        }#for

        return  ref($tmp) =~ /HASH|::/  ? \$$tmp{$subkey} :
                ref($tmp) eq 'ARRAY'    ? \$$tmp[$subkey] : undef;

    }#if

    return undef;

}#_hseekv

# ------------------------------------------------------------------------------
# _hqueryv - Hash Query Value
#
# _hqueryv \%HASH, $ADDRESS, [OPTIONS]
#
# This method returns all resulting records in \HASH specified by $ADDRESS.
#
# OPTIONS:
#
#   -av     Autovivify (contstucts necessary segments)
# ------------------------------------------------------------------------------

sub _hqueryv {

    my ($opts,$hash,$addr) = Hub::opts( \@_, { 'av' => 0, } );

    my $ptr = $hash;

    my $tmp = undef;

    $addr =~ s/\A[$DELIMS]|[$DELIMS]\Z//g;

    if( $addr !~ /\/\{|\}\// ) {

        # Selectors are not used, we may seek to the value

        return _hseekv( $hash, $addr, -opts => $opts );

    } else {

        my @parts = Hub::dice( $addr );

        map ( s/\A[$DELIMS]|[$DELIMS]\Z//g, @parts );

        my $part = undef;

        while( @parts ) {

            # Each $part is a segment of the address which can be:
            #
            #   1) food/fruit           A seekable address
            #   2) {/diet/name}         A value from another place
            #   3) {name eq "apple"}    A selector

            $part = shift @parts;

            $ptr = $$ptr if( ref($ptr) eq 'REF' );

            my $tmp = undef;

            my ($select) = $part =~ /\A\{(.*)\}\Z/;

            if( !$select ) {

                # A seekable address

                $tmp = _hseekv( $ptr, $part, -opts => $opts );

            } elsif( $select =~ /\A\// ) {

                # A value from another place (inside $hash)

                my $val = _hqueryv( $hash, $select, -opts => $opts );

                if( ref($val) eq 'SCALAR' ) {
                
                    $tmp = _hseekv( $ptr, $$val, -opts => $opts );

                }#if

            } elsif( $select ) {

                # A selector

                my $indicies = _hselectv( $hash, $ptr, $select );

                if( defined $indicies ) {

                    if( @$indicies > 1 ) {

                        map { push @$tmp, ref($ptr) =~ /HASH|::/
                            ? $$ptr{$_} : $$ptr[$_]; } @$indicies;

                    } elsif( @$indicies ) {

                        $tmp = ref($ptr) =~ /HASH|::/
                            ? $$ptr{$$indicies[0]} : $$ptr[$$indicies[0]];

                    }#if

                }#if

            }#if

            if( defined $tmp ) {

                $ptr = $tmp;

            } else {

                if( !@parts && $$opts{'av'} ) {

                    # Autovivify

                    my $subkey = $part =~ /\A$ARRAYTAG\Z/ ? $1 : $part;

                    $ptr = ref($ptr) =~ /HASH|::/ ? \$$ptr{$subkey} : \$$ptr[$subkey];

                } else {

                    undef $ptr;

                    last;

                }#if

            }#if

        }#while

    }#if

    return $ptr;

}#_hqueryv

# ------------------------------------------------------------------------------
# _hselectv - Hash Select Value
#
# _hselectv \%HASH, \%ROOT_HASH, $SELECTOR, [OPTIONS]
#
# This method interprets SELECTOR and returns the matching record(s).
#
# Where:
#
#   \%HASH          Look for SELECTOR in this hash
#   \%ROOT_HASH     Used when SELECTOR contains a reference
#   $SELECTOR       The select clause
#
# OPTIONS:
#
#   -av             Autovivify (contstucts necessary segments)
# ------------------------------------------------------------------------------

sub _hselectv {

    my ($opts,$hash,$ptr,$select) = Hub::opts( \@_ );

    my $tmp = $ptr;

    my $matches = undef;

    my @clauses = split /\s*;\s*/, $select;

    while( @clauses ) {

        local $_ = shift @clauses;

        my ($member,$cmp,$crit) =
            /([^\s=]+)\s+([!=]=|[!=]~|eq|ne|lt|gt|le|ge)\s+(.*)/;

        croak "Cannot compare '$_'" unless $cmp;

        if( $crit =~ /\A\// ) {

            my $val = _hqueryv( $hash, $crit, -opts => $opts );

            if( ref($val) eq 'SCALAR' ) {
            
                $crit = $$val;

            } else {

                last;

            }#if

        }#if
            
        $crit =~ s/\A['"]|['"]\Z//g;

        $crit =~ s/\\\//\//g;

        if( ref($tmp) eq 'ARRAY' ) {

            if( @clauses ) {

                $tmp = _lookup( $tmp, $crit, "-by=$member", "-cmp=$cmp", "-first=0" );

            } else {

                $matches = _lookup( $tmp, $crit, "-by=$member", "-cmp=$cmp", 
                    -asindex, "-first=0" );

            }#if

        } elsif( ref($tmp) =~ /HASH|::/ ) {

            if( defined $$tmp{$member} && !ref($$tmp{$member}) ) {

                if( Hub::compare( $cmp, $$tmp{$member}, $crit ) ) {

                    if( !@clauses ) {

                        $matches = $member;

                    }#if

                } else {

                    last;

                }#if

            }#if

        }#if

    }#for

    return  !defined $matches           ? undef     :
            ref($matches) eq 'ARRAY'    ? $matches  : [$matches];

}#_hselectv

# ------------------------------------------------------------------------------
# _lookup - Lookup array item (must be a hash) by member value.
#
# _lookup \@ARRAY, $VALUE, [OPTIONS]
#
# OPTIONS:
#
#   Name        Type        Default                 Description
#   ----------- ----------- ----------------------- ----------------------------
#   -by         \@ARRAY     \['_id','id','name']    Fields to search by
#   -cmp        eq|ne|...   eq                      Comparator
#   -asindex    0|1         0                       Return the array index(s)
#   -first      0|1         1                       Return first match
# 
# VALUE:
#
#   Regarless of the '-by' option, if value is formatted as: \[\d\], then it 
#   is considered an index into the array.
# ------------------------------------------------------------------------------

sub _lookup {

    my $opts = Hub::opts( \@_, { 'first' => 1 } );

    my $a = shift || return;        # The list to search

    my $v = shift || '';            # The value we're looking for

    my $by = Hub::bestof( $$opts{'by'}, [ '_id', 'id', 'name' ] );

    my $cmp = Hub::bestof( $$opts{'cmp'}, 'eq' );

    my ($idx) = ($v =~ /^$ARRAYTAG$/);

    return $$a[$idx] if( defined $idx );

    my @items = ();

    # Search the list starting from both ends.
    #
    #   i1  index starting at zero, moving forward
    #   h1  item at that index
    #
    #   i2  index starting at the end, moving backward
    #   h2  item at that index

    for( my ($i1,$i2) = (0,$#$a); $i1 <= $i2; ($i1++,$i2--) ) {
    
        my ($h1,$h2) = ( $$a[$i1], $$a[$i2] );

        if (ref($h1) =~ /HASH|::/) {

            for( Hub::asa( $by ) ) {

                if( defined $$h1{$_} && Hub::compare( $cmp, $$h1{$_}, $v ) ) {

                    push @items, $$opts{'asindex'} ? $i1 : $h1;

                    last;

                }#if

            }#for

            @items and last if $$opts{'first'};

        }#if

        if( ($i2 != $i1) && (ref($h2) =~ /HASH|::/) ) {

            for( Hub::asa( $by ) ) {

                if( defined $$h2{$_} && Hub::compare( $cmp, $$h2{$_}, $v ) ) {

                    push @items, $$opts{'asindex'} ? $i2 : $h2;

                    last;

                }#if

            }#for

            @items and last if $$opts{'first'};

        }#if

    }#for

    return undef unless @items;

    $$opts{'first'} and return $items[0];

    return \@items;

}#_lookup

# ------------------------------------------------------------------------------
# _appendvasa - Append value as array.
#
# _appendvasa \%HASH, $ADDRESS, $VALUE
# 
# Append value onto the array at $key.  If the value at $key exists as a scalar,
# transform it into an ARRAY, whos first element is its current value.
# ------------------------------------------------------------------------------

sub _appendvasa {

    my ($opts,$hash,$key,$val) = Hub::opts( \@_ );

    my $tmp = hgetv( $hash, $key );
    
    if( defined $tmp ) {

        if( ref($tmp) eq 'ARRAY' ) {

            push @{$tmp}, $val;

        } else {

            my $orig = Hub::cpref( $tmp );

            my $parent = Hub::varparent( $key );

            my $node = Hub::varname( $key );

            $tmp = hgetv( $hash, $parent );

            Hub::expect( HASH => $tmp );

            $$tmp{$node} = [ $orig, $val ];

        }#if

    } else {

        $tmp = hsetv( $hash, $key, [ $val ] );

    }#if

    return $tmp;

}#_appendvasa



'???';
