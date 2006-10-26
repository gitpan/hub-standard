package Hub::Data::Address;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2

use Hub qw/:lib/;

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/

    vartype
    varroot
    varname
    varparent
    dotaddr
    expand
    keydepth

/;

our $DELIMS         = ':/';

#!BulkSplit

# ------------------------------------------------------------------------------
# keydepth
# 
# For sorting parents and children, this simpley lets you know how deep the key
# is named.
# ------------------------------------------------------------------------------
#|test(match,4) keydepth( 'and:then:came:the:rain' )
# ------------------------------------------------------------------------------

sub keydepth {

    my $key = shift;

    return $key =~ tr':/'';

}#keydepth

# ------------------------------------------------------------------------------
# vartype VARADDR, [DEFAULT]
#
# Return a variables type (or a default value).
# ------------------------------------------------------------------------------
#|test(match)           vartype( );
#|test(match,clr)       vartype( "clr-bg" );
#|test(match,clr)       vartype( "clr-bg", "default" );
#|test(match,default)   vartype( "whatev", "default" );
#|test(match)           vartype( "whatev" );
#|test(match)           vartype( "a:b:c" );
#|test(match,x)         vartype( "x-a:b:c" );
#|test(match,x)         vartype( "a:b:x-c" );
# ------------------------------------------------------------------------------

sub vartype {
    
    my $str = defined $_[0] ? $_[0] : '';
    my $def = defined $_[1] ? $_[1] : '';

    my ($type) = $str =~ /[_]?([^-]+)-/;

    $type = '' unless defined $type;

    $type =~ s/.*://;

    return $type || $def;

}#vartype

#-------------------------------------------------------------------------------
# varroot VARADDR
#
# The root portion of the address.
#-------------------------------------------------------------------------------
#|test(match,p001)   varroot( "p001:items:1002:text-description" );
#|test(match,p001)   varroot( "p001" );
#-------------------------------------------------------------------------------

sub varroot {

    my $given = defined $_[0] ? $_[0] : '';

    my ($root) = ( $given =~ /([^$DELIMS]+)/ );

    return $root || '';

}#varroot

#-------------------------------------------------------------------------------
# varname VARADDR
#
#-------------------------------------------------------------------------------
#|test(match,text-desc)     varname( "p001:items:1002:text-desc" );
#|test(match,p001)          varname( "p001" );
#-------------------------------------------------------------------------------

sub varname {

    my $given = defined $_[0] ? $_[0] : '';

    my ($name,$end) = ( $given =~ /.*[$DELIMS]([^$DELIMS]+)([$DELIMS])?$/ );

    return defined $end ? '' : $name || $given;
    
}#varname

#-------------------------------------------------------------------------------
# varparent VARADDR
#
# Parent address.
#-------------------------------------------------------------------------------
#|test(match,p001:items:12)         varparent( "p001:items:12:1000" );
#|test(match,p001:items:10:subs)    varparent( "p001:items:10:subs:100" );
#|test(match)                       varparent( "p001" );
#-------------------------------------------------------------------------------

sub varparent {

    my $given = defined $_[0] ? $_[0] : '';

    my ($container) = ( $given =~ /(.*)[$DELIMS]/ );

    return $container || '';

}#varparent

# ------------------------------------------------------------------------------
# dotaddr VARADDR
# 
# Replace address separators with dots.  In essence, protecting the address
# from expansion.
# ------------------------------------------------------------------------------
#|test(match,p004.proj.1000)        dotaddr( "p004:proj:1000" );
#|test(match,p004.proj.1000.name)   dotaddr( "p004:proj:1000:name" );
#|test(match,p001)                  dotaddr( "p001" );
#|test(match)                       dotaddr( "" );
# ------------------------------------------------------------------------------

sub dotaddr {

    my $address = shift || return;

    $address =~ s/:/./g;

    return $address;

}#dotaddr

# ------------------------------------------------------------------------------
# expand HASHREF, [OPTIONS]
#
# Expands keys which are formatted as names (see naming.txt) into subhashes
# and subarrays as necessary.
#
# OPTIONS:
#
#   meta    => 1                # add '_address' and '_id' metadata to hashes
#   root    => SCALAR           # use this as a prefix for '_address'
# 
# Returns HASHREF
# ------------------------------------------------------------------------------

sub expand {

    my $src     = shift || return;      # source data
    my %ops     = @_;                   # options
    my $new     = {};                   # destination data
    my %meta    = ();                   # meta-data

    if( ref($src) eq 'HASH' ) {

        foreach my $k ( sort keydepthsort keys %$src ) {

            my $v = $$src{$k};

            my @addr = split /[$DELIMS]/, $k;
            
            my @nest = map { "->{'$_'}" } @addr;
            
            my $dest = "\$new@nest";

            eval( "$dest = \$v" );

            # Create metadata

            if( $ops{'meta'} ) {

                pop @addr; # remove field key

                if( @addr ) {

                    my $meta_addr = join ':', @addr;

                    unshift( @addr, $ops{'root'} ) if $ops{'root'};

                    my $meta_addr_val = join ':', @addr;

                    $meta{"$meta_addr:_address"} = $meta_addr_val;

                    $meta{"$meta_addr:_id"} = pop @addr;

                }#if

            }#if

        }#foreach

    }#if

    if( %meta ) {

        my $metadata = Hub::expand( \%meta );

        Hub::merge( $new, $metadata );

    }#if

    return $new;

}#expand


'???';
