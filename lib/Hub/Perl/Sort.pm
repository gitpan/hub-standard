package Hub::Perl::Sort;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub             qw/:lib/;

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/

    anonsort
    keydepthsort

/;

# ------------------------------------------------------------------------------
# anonsort - Anonymous value sort
#
# anonsort [OPTIONS], \ARRAY
#
# OPTIONS:
#
#   -on     keyname         Only sort subhashes with this keyname.
#   -cmp    (<=>|cmp)       Comparison type (default is 'cmp'.)
#   -asr    (0|1)           Return a reference to the result array.
#   -modify (0|1)           Modify the provided array.
#
# ------------------------------------------------------------------------------
=test(match) # Simple (alphabetical) sort
    my @months = qw/Jan Feb Mar/;
    my @sorted = anonsort( \@months );
    return join ',', @sorted;
=result
    Feb,Jan,Mar
=cut
# ------------------------------------------------------------------------------

sub anonsort {

    my $opts = {
        'cmp'       => 'cmp',
        'on'        => '',
        'asr'       => 0,
        'modify'    => 0,
    };

    Hub::opts( \@_, $opts );

    my @all = ();

    while( @_ ) {

        my @result = ();

        my $x = shift;

        Hub::expect( ARRAY => $x, '-back=2' );

        my $list = [];

        if( $$opts{'on'} ) {

           map { Hub::check( '-ref=HASH', $_ ) and push @$list, $_ } @$x;

        } else {

           $list = $x;

        }#if

        if( $$opts{'on'} ) {

            @result = sort {

                Hub::compare( $$opts{'cmp'}, 
                    Hub::hgetv( $a, $$opts{"on"} ), Hub::hgetv( $b, $$opts{"on"} ) );

            } @$list;

        } else {

            @result = sort {

                Hub::compare( $$opts{'cmp'}, 
                    Hub::bestof( $a, -1 ), Hub::bestof( $b, -1 ) );

            } @$list;

        }#if

        if( $$opts{'modify'} ) {
        
            @$x = @result;

        } else {

            push @all, \@result;

        }#if

    }#while

    @all == 1 and @all = @{ pop @all };

    return $$opts{'asr'} ? \@all : @all;

}#anonsort

# ------------------------------------------------------------------------------
# keydepthsort
# 
# Sort by keydepth (for processing hashes and making sure parents don't smuther
# their children.)
# ------------------------------------------------------------------------------

sub keydepthsort {

    return Hub::keydepth($a) <=> Hub::keydepth($b);

}#keydepthsort

# ------------------------------------------------------------------------------

'???';
