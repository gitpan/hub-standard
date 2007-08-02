package Hub::Data::Address;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
  keydepth
  vartype
  varroot
  varname
  varparent
  dotaddr
  expand
  collapse
/;
our $DELIMS         = ':/';

# ------------------------------------------------------------------------------
# keydepth
# 
# For sorting parents and children, this simply lets you know how deep the key
# is named.
# ------------------------------------------------------------------------------
#|test(match,4) keydepth( 'and:then:came:the:rain' )
# ------------------------------------------------------------------------------

sub keydepth {
  defined $_[0] ? $_[0] =~ tr':/'' : 0;
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
#|test(match,p004.proj.1000)        dotaddr("p004:proj:1000");
#|test(match,p004.proj.1000.name)   dotaddr("p004:proj:1000:name");
#|test(match,p001)                  dotaddr("p001");
#|test(!defined)                    dotaddr("");
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
#   meta    => 1                # add '.address' and '.id' metadata to hashes
#   root    => SCALAR           # use this as a prefix for '.address'
# 
# Returns HASHREF
# ------------------------------------------------------------------------------

sub expand {
  my $src = shift || return; # source data
  my $new = {}; # destination data
  my %ops = @_;
  my %meta = ();
  if( ref($src) eq 'HASH' ) {
    foreach my $k ( sort Hub::keydepth_sort keys %$src ) {
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
          $meta{"$meta_addr:.address"} = $meta_addr_val;
          $meta{"$meta_addr:.id"} = pop @addr;
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

# ------------------------------------------------------------------------------
# collapse - Collapse a nested structure into key/value pairs
# collapse ?ref, [options]
#
# options
#
#   -containers=1        Just return containers
#
# Returns a hash reference.
# ------------------------------------------------------------------------------

sub collapse {
  my ($opts, $ref, $addr, $result) = Hub::opts(\@_, {'containers'=>0});
  croak "Provide a reference" unless ref($ref);
# my $addr = shift || '';
# my $result = shift;
  $addr ||= '';
  unless (defined $result) {
    my %sh; tie %sh, 'Hub::Knots::SortedHash';
    $result = \%sh;
  }
  if (isa($ref, 'HASH')) {
    $addr .= '/' if $addr;
    foreach my $k (keys %$ref) {
      if (ref($$ref{$k})) {
        $$result{$addr.$k} = $ref if $$opts{'containers'};
        collapse($$ref{$k}, $addr.$k, $result, -opts => $opts);
      } else {
        $$result{$addr.$k} = $$ref{$k}
          unless $$opts{'containers'};
      }
    }
  } elsif (isa($ref, 'ARRAY')) {
    for (my $idx = 0; $idx <= @$ref; $idx++) {
      if (ref($$ref[$idx])) {
        $$result{"$addr/$idx"} = $ref if $$opts{'containers'};
        collapse($$ref[$idx], "$addr/$idx", $result, -opts => $opts);
      } else {
        $$result{"$addr/$idx"} = $$ref[$idx]
          unless $$opts{'containers'};
      }
    }
  } elsif (isa($ref, 'SCALAR')) {
      $$result{$addr} = $$ref
        unless $$opts{'containers'};
  } else {
    die "Cannot collapse: $ref";
  }
  return $result;
}

1;
