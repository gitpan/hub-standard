# NOTE: Changes made here will be lost when bulksplit is run again.
package Hub::Data::Meta;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Meta
#
# Called by the framework to invoke Autoloader::AUTOLOAD, in essence loading
# this file.
# ------------------------------------------------------------------------------
sub Meta {
}#Meta

#line 9

# ------------------------------------------------------------------------------
# refresh meta-data in the provided hashref.
#
# example:
#
#   $meta->touch( { this => "is", a => "hashref" } );
#
# will:
#
#   {
#       _created_by         => guest,
#       _last_modified_by   => guest,
#       _created            => 1071712178,
#       _last_modified      => 1071712178,
#       this                => "is",
#       a                   => "hashref",
#   }
# ------------------------------------------------------------------------------
sub touch {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $hash = shift || return;
    my $addr = shift || undef;
    my $username = shift || "guest";

    if( ref($hash) eq 'HASH' ) {

        $$hash{'_created_by'} ||= $username;

        $$hash{'_created'} ||= time;

        $$hash{'_last_modified_by'} = $username;

        $$hash{'_last_modified'} = time;

        if( $addr ) {

            $$hash{'_id'} = Hub::varname( $addr );

            $$hash{'_address'}  = $addr;

        }#if

    }#if

}#touch

# ------------------------------------------------------------------------------
# initialize meta-data for the provided hash
# ------------------------------------------------------------------------------

sub initHash {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $hash = shift || return;
    my $addr = shift;
    my $opts = shift;
    my $username = shift || "guest";

    if( ref($hash) eq 'HASH' ) {

        $$hash{'_created_by'} ||= $username;

        $$hash{'_created'} ||= time;

        $$hash{'_last_modified_by'} = $username;

        $$hash{'_last_modified'} = time;

        #
        # Providing an addr also triggers recursion
        #

        if( $addr ) {

            if( $opts =~ "--refresh" ) {

                # Only update existing metadata

                defined $$hash{'_id'} and $$hash{'_id'} = Hub::varname( $addr );

                defined $$hash{'_address'} and $$hash{'_address'} = $addr;

            } else {

                # Force the creation/upate

                $$hash{'_id'} = Hub::varname( $addr );

                $$hash{'_address'} = $addr;

            }#if

            for( keys %$hash ) {

                if( Hub::vartype( $_ ) && ($opts !~ "--refresh") ) {

                    Hub::lmsg( "refusing to recurse into: $_ ($opts)" );

                    next;

                }#if

                if( ref($$hash{$_}) eq "HASH" ) {

                    $self->initHash( $$hash{$_}, "$addr:$_", $opts );

                } elsif( ref($$hash{$_}) eq "ARRAY" ) {

                    my $arr_item_count = 0;

                    foreach my $arr_item ( @{$$hash{$_}} ) {

                        if( ref($arr_item) eq "HASH" ) {

                            my $name = Hub::varname( $$arr_item{'_id'} );

                            $name ||= $$arr_item{'name'};

                            $name ||= $arr_item_count;

                            $self->initHash( $arr_item, "$addr:$_:$name", $opts );

                            $arr_item_count++;

                        }#if

                    }#foreach

                }#if

            }#for

        }#if

    }#if

}#initHash

# ------------------------------------------------------------------------------
# return the stored id data, or create it with default values
#
# example:
#
#   $meta->get_id();
#   $meta->get_id('folsiz');
#
# returns a hash reference to:
#
#   the global id data
#   the id data for 'folsiz'
#
# ------------------------------------------------------------------------------
sub get_id {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $key = shift || "global";

    $key = Hub::dotaddr( $key );

    $self->{'_file'} = $self->{'_file'}->load();

    my $info = $self->{'_file'}->get("$key");

    unless( $info ) {

        Hub::lwarn( "Meta does not have definition: $key" );

        $info = {
            'format' => shift || '%d',
            'value' => shift || 0,
        };

        $self->{'_file'}->set($key, $info);

        $self->{'_file'}->save();

    }#unless

    return $info;

}#get_id

# ------------------------------------------------------------------------------
# define the format and initial value for an id
#
# example:
#
#   $meta->define_id('global', '%04d', 0);
#   $meta->define_id('folsiz', "p%d", 100);
#   $meta->define_id('bolmsk', "item%08d", 2000);
#
# will create ids of the form:
#
#   0164                where the value is 164 and starts at 0
#   p748                where the value is 748 and starts at 100
#   item00012148        where the value is 12148 and starts at 200
#
# ------------------------------------------------------------------------------
sub define_id {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $info = $self->get_id( @_ );

    my ($key, $format, $initial_value) = @_;

    my $dirty = 0;

    if( $format ) {

        if( $$info{'format'} ne $format ) {

            $$info{'format'} = $format;

            $dirty = 1;

        }#if

    }#if

    if( $initial_value ) {

        if( $$info{'value'} < $initial_value ) {
        
            $$info{'value'} = $initial_value;

            $dirty = 1;

        }#if

    }#if

    $dirty and $self->{'_file'}->save();

}#define_id

# ------------------------------------------------------------------------------
# gets the next number for an id and returns the formmatted value.  file storage
# is saved as 'meta.hf'.
#
# example:
#
#   a) $meta->create_id();
#   b) $meta->create_id();
#   ...
#
#   c) $meta->create_id('abc','%d',10);
#
# returns:
#
#   a) 1
#   b) 2
#   ...
#
#   c) 11 (presuming the id 'abc' wasn't defined, it is initialized)
#
# ------------------------------------------------------------------------------
sub create_id {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $info = $self->get_id( @_ );

    my $new_id = sprintf $$info{'format'}, ++$$info{'value'};

    $self->{'_file'}->save();

    return $new_id;

}#create_id

# ------------------------------------------------------------------------------
# order the anon hashes within an array according to some hash key
#
# order_items( $array_ref, 'hash_key', 'sort_key' );
#
# 1) The 'sort_key' arguement (or literally '_sort' if no arg is provided)
#    will be assigned in the anon hash with the 0 ... n index which indicates 
#    the correct sort order.
#
# 2) sorting will use a numeric comparison when the data of the key to sort on
#    is purely digits.
#
# ------------------------------------------------------------------------------
sub order_items {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my ($array, $key, $assign) = @_;

    $assign ||= '_sort';

    $SORT_KEY = $key;

    if( ref($array) eq "ARRAY" ) {

        my @sorted_values = sort { &smart_compare } @$array;

        my $index = 0;

        map { $$_{$assign} = $index++ } @sorted_values;

        return @sorted_values;

    } else {

        Hub::lerr( "$type could not order items in $array" );

    }#if

    return undef;

}#order_items

# ------------------------------------------------------------------------------
# use 'cmp' or '<=>' depending on the data.  missing values are pushed to the 
# end of the list
#
# ------------------------------------------------------------------------------
sub smart_compare {

    #
    # Missing values are pushed to the end of the list
    #

    return 1 unless defined $$a{$SORT_KEY};
    return -1 unless defined $$b{$SORT_KEY};

    #
    # Digits use <=>, and anything else uses cmp
    #

    if( ($$a{$SORT_KEY} . $$b{$SORT_KEY}) =~ /^\d+$/ ) {

        return $$a{$SORT_KEY} <=> $$b{$SORT_KEY};

    } else {

        return $$a{$SORT_KEY} cmp $$b{$SORT_KEY};

    }#if

}#smart_compare
 
#-------------------------------------------------------------------------------
sub new {

	my $self = shift;
	my $class = ref( $self ) || $self;

    my $filename = shift;

	$self = {
        '_file' => Hub::mkinst( 'HashFile', $filename ),
    };

	return bless $self, $class;

}#new

# ------------------------------------------------------------------------------
# initialize
#
# ------------------------------------------------------------------------------
sub init {

	my $self = shift;
	my $type = ref($self) || die "$self is not an object!";

    my $filename = shift || return;

    $self->{'_file'} = $self->{'_file'}->load( $filename );

}#init

# ------------------------------------------------------------------------------

1;
