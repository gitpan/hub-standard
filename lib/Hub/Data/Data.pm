package Hub::Data::Data;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw//;

#!BulkSplit

# ------------------------------------------------------------------------------
# store information in the embedded hashfile
#
# examples
#
#   1)  store( { _id => 'user1', name => 'Ryan', height => '5\'9\"', } );
#
#       %user1{
#           name == Ryan
#           height == 5'9"
#       }
#
#   2)  store( { name => "Ryan", height => "5\'9\"", } );
#
#       name == Ryan
#       height == 5'9"
#
#   2)  store( { user1:name => "Ryan", user1:height => "5\'9\"", } );
#
#       name == Ryan
#       height == 5'9"
#
sub store {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $data = shift;

    # we will not modify the original hash
    my $hash = Hub::cpref( $data );

    if( Hub::check( '-ref=HASH', $hash ) ) {

        my $id = $$hash{'_id'};

        if( $id ) {

            my $id_ref = $self->{'_file'}->get( $id );

            if( ref( $id_ref ) eq 'ARRAY' ) {

                my $metaid = Hub::dotaddr($id);

                $$hash{'_id'} = $self->{'_meta'}->create_id( $metaid );

                my $maxloop = 0;

                while( $self->get( "$id:$$hash{'_id'}" ) && ($maxloop++ < 10000) ) {

                    Hub::lwarn( "Metadata out of sync: $metaid: $$hash{'_id'}" );

                    $$hash{'_id'} = $self->{'_meta'}->create_id( $metaid );

                }#while

                $self->{'_meta'}->initHash( $hash, "$id:$$hash{'_id'}" );

            }#if

            $self->store_at( $id, $hash );

            return $$hash{'_id'};

        } else {

            my @reset_itr = keys %$hash; # reset the iterator!

            while( my ($k,$v) = each %$hash ) {

                $self->store_at( $k, $v );

            }#while

        }#if

    } else {

        Hub::lerr( "Hash required: $hash" );

        return undef;

    }#if

}#store

# ------------------------------------------------------------------------------
# store information at the specified address
#
sub store_at {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $address = shift;
    my $item    = shift;
    my $options = shift;

    die "Use set_root if you don't have an address!" unless $address;

    my $record = $self->{'_file'}->get( $address );

    $self->{'resort'} = [];

    if( ref($item) eq 'HASH' ) {

        # we will not modify the original hash
        $item = Hub::cpref( $item );

        # converts colon-delimited keys into subhashes
        $item = Hub::expand( $item, meta => 1, root => $address );

        # pack data
        $self->packdata( $item, $address );

        # update meta-data
        if( $record ) {

            $self->touch( $record, $address ) unless $options =~ /--notouch/;

        } else {

            $self->{'_meta'}->initHash( $item, $address ) unless $options =~ /--notouch/;

        }#if

    }#if

    if( $record ) {

        if( (ref($record) eq 'HASH') && (ref($item) eq 'HASH') ) {

            # do not overwrite the id we found the record with
            delete $item->{'_id'};

            # copy data members
            Hub::merge( $record, $item, "--overwrite", "--keeparrays" );

        } elsif( (ref($record) eq 'ARRAY') && (ref($item) eq 'HASH') ) {

            $self->{'_meta'}->initHash( $item ) unless $item->{'_created'};

            $item->{'_sort'} ||= 9999999;

            push @$record, $item;

            $self->resort( $address, "_sort" );

        } else {

            $self->{'_file'}->set($address, $item);

            $self->touch( Hub::varparent( $address ) )
                unless $options =~ /--notouch/;

        }#if

    } else {

        $self->{'_file'}->set($address, $item);

        my $box = $self->{'_file'}->get( Hub::varparent( $address ) );

        if( ref($box) eq 'ARRAY' ) {

            $self->touch( $address )
                unless $options =~ /--notouch/;

        } else {

            $self->touch( Hub::varparent( $address ) )
                unless $options =~ /--notouch/;

        }#if

    }#if

    foreach my $x ( @{$self->{'resort'}} ) {

        $self->resort( $x->{'id'}, $x->{'key'}, $x->{'filter'} );

    }#foreach

    return $address; # for convienence

}#store_at

# ------------------------------------------------------------------------------
# packdata HASHREF
# 
# From the bottom up, pack each variable's data.
# ------------------------------------------------------------------------------

sub packdata {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $data = shift;

    my $id = shift;

    return unless ref($data) eq 'HASH';

    my $slices = Hub::digout( $data, $id );

    foreach my $slice ( reverse @$slices ) {

        if( Hub::vartype( $slice->{'key'} ) ) {

            my $props = {

                'id'    => $slice->{'id'},
                'value' => $slice->{'val'},

            };

            my $class = ref($slice->{'val'});

            if( $class eq 'SCALAR' ) {

                # Dereference value and modify original

                $props->{'value'} = ${$slice->{'val'}};

                ${$slice->{'val'}} = Hub::packval( $props, $slice->{'key'} );
            
            } else {

                $slice->{'val'} = Hub::packval( $props, $slice->{'key'} );

            }#if

        } elsif( $slice->{'key'} =~ /([_]?sort)/ ) {

            my $sortkey = $1;

            my $pid = Hub::varparent( $slice->{'id'} );

            my $p = $self->get( $pid );

            if( ref($p) eq 'HASH' ) {

                if( ${$slice->{'val'}} ne $p->{$sortkey} ) {

                    my $filter = "";

                    if( defined $$p{'type'} ) {

                        $filter = "--filter:type=" . $$p{'type'};

                    }#if

                    push @{$self->{'resort'}}, {
                        'id'        => Hub::varparent( $pid ),
                        'key'       => $sortkey,
                        'filter'    => $filter,
                    };

                    $p->{$sortkey."2"} = $p->{$sortkey};

                }#if

            }#if

        }#if

    }#foreach

    return $data; # for convienence

}#packdata

# ------------------------------------------------------------------------------
# touch($hashref)
# touch($address)
#
# Update meta-data.  See touch() in Meta.pm for what gets modified.
#
#   Example:
#
#       touch( { a => "aye", b => "bee" } )
#       touch( "file:data" )
#
#   Will:
#
#       update the hash provided
#       update the item at address 'file:data' if it is a hash
#
# ------------------------------------------------------------------------------

sub touch {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $item = shift || return;
    my $addr = shift || undef;

    if( ref($item) eq 'HASH' ) {

        $self->{'_meta'}->touch( $item, $addr );

    } elsif( !ref($item) ) {

        my $data = $self->{'_file'}->get( $item );

        if( ref( $data ) eq 'HASH' ) {

            $self->{'_meta'}->touch( $data, $addr );

        }#if

    }#if

}#touch

# ------------------------------------------------------------------------------
# refreshmeta ID
# 
# Refresh the meta variables (which already exist) at point ID
# ------------------------------------------------------------------------------

sub refreshmeta {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $id = shift;

    my $item = $self->get( $id );

    ref($item) and $self->{'_meta'}->initHash( $item, $id, "--refresh" );

}#refreshmeta

# ------------------------------------------------------------------------------
# resort( $address )
#
# Before calling this method, set '_sort2' to a *number* on the 
# subhashes which have priority.  This method will clear that property.
#
# Resorts the items which are peers at the given address.  If no address is
# given, we will resort all root items.  The sort value is stored in the
# subkey: '_sort'.
#
sub resort {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $address = shift;
    my $key     = shift;
    my $filter  = shift;

    Hub::lmsg( "Resort $key [$filter] at: $address", "sort" );

    my $target  = $address ? $self->get( $address ) : $self->get();

    return unless ref($target);

    my @list = Hub::asarray( $target, $key, $filter );

    my $i = 1; # do not use a zero value for sort

    foreach my $item ( @list ) {

        if( ref($item) eq "HASH" ) {
        
            delete $$item{$key."2"};

            $item->{$key} = $i++;

        }#if

    }#foreach

}#resort

# ------------------------------------------------------------------------------
# remove data
#
sub delete_at {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $address = shift || return 0;

    my $pid    = Hub::varparent($address);

    my $id     = Hub::varname($address);

    my $parent = ();

    if( $pid ) {

        $parent = $self->{'_file'}->get( $pid );

    } else {

        $parent = $self->{'_file'}->data();

    }#if

    if( $parent ) {

        if( ref($parent) eq 'ARRAY' ) {

            my $index = 0;

            foreach my $subhash ( @$parent ) {

                if( ref($subhash) eq 'HASH' && ($$subhash{'_id'} eq $id) ) {

                    splice( @$parent, $index, 1 );

                    last;

                }#if

                $index++;

            }#foreach

        } elsif( ref($parent) ) {

            $$parent{$id} and delete $$parent{$id};

        }#if

    } else {

        Hub::lerr( "Cannot delete: $address with: $pid." );

    }#if

}#delete_at

# ------------------------------------------------------------------------------
# get information
#
sub get {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    return $self->get_root() unless @_;

    return $self->{'_file'}->get( @_ );

}#get

# ------------------------------------------------------------------------------
# get (return a copy) information
#
sub cp {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    return Hub::cpref( $self->get( @_ ) );

}#cp

# ------------------------------------------------------------------------------
# set information
#
sub set {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    return $self->{'_file'}->set( @_ );

}#set

# ------------------------------------------------------------------------------
# get_root
# 
# Get the root of the data
# ------------------------------------------------------------------------------

sub get_root {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    return $self->{'_file'}->data();

}#get_root

# ------------------------------------------------------------------------------
# set_root HASH
# 
# Set the root of the data!
# ------------------------------------------------------------------------------

sub set_root {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    return $self->{'_file'}->setRoot( @_ );

}#set_root

# ------------------------------------------------------------------------------
# write to disk
#
sub commit {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    $self->{'_file'}->save(@_);

}#commit

# ------------------------------------------------------------------------------
# define id
#
sub define_id {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    $self->{'_meta'}->define_id(@_);

}#define_id

# ------------------------------------------------------------------------------
# create id
#
sub create_id {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $id = $self->{'_meta'}->create_id(@_);

    my $maxloop = 0;

    while( $self->{'_file'}->get($id) && ($maxloop++ < 10000) ) {

        $id = $self->{'_meta'}->create_id(@_);

    }#while

    return $id;

}#create_id

#-------------------------------------------------------------------------------
# constructor
#
sub new {

	my $self = shift;
	my $class = ref( $self ) || $self;

	$self = {
        '_file' => Hub::mkinst( 'HashFile' ),
        '_meta' => Hub::mkinst( 'Meta' ),
        '_uses_global_meta' => 0,
    };

    &init( $self, @_ );

	return bless $self, $class;

}#new

# ------------------------------------------------------------------------------
# initialize myself and load the disk files
#
sub init {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my ($filepath,$metapath) = @_;

    return unless $filepath;

    $self->{'_file'} = Hub::mkinst( 'HashFile', $filepath );

    if( $metapath ) {

        $self->{'_meta'} = Hub::mkinst( 'Meta', $metapath );

    } else {

        if( ref( $Hub->md ) ) {

            $self->{'_meta'} = $Hub->md;

            $self->{'_uses_global_meta'} = 1;

        } else {

            $self->{'_meta'} = Hub::mkinst( 'Meta','.meta.hf');

        }#if

    }#if

}#init

# ------------------------------------------------------------------------------
# attach this data object to an existing HashFile instance
#
sub attach {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $hf_ref = shift;

    $self->{'_file'} = $hf_ref;
    $self->{'_meta'} = $Hub->md;

}#attach

# ------------------------------------------------------------------------------
# reload from disk and reset any instance data
#
sub refresh {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    $self->{'_file'} and $self->{'_file'} = $self->{'_file'}->load();

    if( $self->{'_uses_global_meta'} ) {

        $self->{'_meta'} and $self->{'_meta'} = $Hub->md;

    }#if

}#refresh

# ------------------------------------------------------------------------------

'???';
