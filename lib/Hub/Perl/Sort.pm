package Hub::Perl::Sort;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
    anon_sort
    keydepth_sort
/;

# ------------------------------------------------------------------------------
# anon_sort - Anonymous value sort
#
# anon_sort [OPTIONS], \ARRAY
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
    my @sorted = anon_sort( \@months );
    return join ',', @sorted;
=result
    Feb,Jan,Mar
=cut
# ------------------------------------------------------------------------------

sub anon_sort {
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
          Hub::getv($a, $$opts{"on"}), Hub::getv($b, $$opts{"on"}));
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
}#anon_sort

# ------------------------------------------------------------------------------
# keydepth_sort - Sort by number of semicolons
# keydepth_sort
# 
# Sort by keydepth (for processing hashes and making sure parents don't smuther
# their children.)
# ------------------------------------------------------------------------------

sub keydepth_sort {
  return Hub::keydepth($a) <=> Hub::keydepth($b);
}#keydepth_sort

# ------------------------------------------------------------------------------
1;
