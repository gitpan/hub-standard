package Hub::Knots::Defined;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/playnice/;

=test(match)

    my $h = {};

    playnice( $h );

    $$h{'foo'} = 'bar';

    $$h{'foo'};

=result

    bar

=cut

sub playnice {

    my $h = shift;

    Hub::expect( HASH => $h );

    my $copy = Hub::cpref( $h );

    tie %$h, 'Hub::Knots::Defined', $copy;

}

sub TIEHASH {

    my $self = shift;

    my $real = shift || {};

    my $obj = bless { '__DATA__' => $real }, $self;

    return $obj;

}

sub FETCH {

    my $self = shift;

    my $index = shift;

    if( defined $self->{'__DATA__'}->{$index} ) {

        return $self->{'__DATA__'}->{$index};

    } else {

        return '';

    }#if

}

sub STORE {

    my $self    = shift;

    my $index   = shift;

    my $value   = shift;

    $self->{'__DATA__'}->{$index} = $value;

}

sub DELETE {

    my $self = shift;

    my $index = shift;

    if( ref($self->{'__DATA__'}->{$index}) eq 'HASH' ) {

        foreach my $sub_index ( keys %{$self->{'__DATA__'}->{$index}} ) {

            delete  $self->{'__DATA__'}->{$index}->{$sub_index};

        }

    } elsif( ref($self->{'__DATA__'}->{$index}) eq 'ARRAY' ) {

        @{$self->{'__DATA__'}->{$index}} = ();

    }

    delete $self->{'__DATA__'}->{$index};
}

sub CLEAR {

    my $self = shift;

    map { delete $self->{'__DATA__'}->{$_} } keys %{$self};

}

sub EXISTS {

    my $self = shift;

    my $index = shift;

    exists $self->{'__DATA__'}->{$index};

}

sub FIRSTKEY {

    my $self = shift;

    my @reset = keys %{$self};

    each %{$self->{'__DATA__'}};

}

sub NEXTKEY {

    my $self = shift;

    my $lastindex = shift;

    each %{$self->{'__DATA__'}};

}

sub SCALAR {

    my $self = shift;

    scalar %{$self->{'__DATA__'}};

}

sub UNTIE {

    my $self = shift;

    my $count = shift || 0;

}

# ------------------------------------------------------------------------------

'???';
