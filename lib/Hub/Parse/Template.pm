package Hub::Parse::Template;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our $VERSION        = '3.01048';
our @ISA            = qw/Hub::Base::Object/;
our @EXPORT         = qw//;
our @EXPORT_OK      = qw//;

# ------------------------------------------------------------------------------
# refresh - Reset to initial state (persistent object method)
#
# refresh FILESPEC
# ------------------------------------------------------------------------------

sub refresh {

    my ($self,$opts) = Hub::objopts( \@_ );

    my $spec = shift;

    $self->{'parser'} = mkinst( 'FileParser', $spec );

    Hub::merge( $self->{'public:'}, @_ ) if @_;

}#refresh

# ------------------------------------------------------------------------------
# comptv - Compose template value
#
# comptv ADDRESS, FILESPEC, [VALUE]
# ------------------------------------------------------------------------------

sub comptv {

    my ($self,$opts) = Hub::objopts( \@_ );

    my ($k,$template) = (shift,shift);

    map {

        my $template = Hub::mkinst( 'Template', $template, $_ );

        Hub::happendv( $self->{'public:'}, $k, $template, '-asa=1' );

    } @_;

}#comptv

# ------------------------------------------------------------------------------
# compfv - Compose formatted value
#
# compfv ADDRESS, FORMAT, [VALUE]
# ------------------------------------------------------------------------------

sub compfv {

    my ($self,$opts) = Hub::objopts( \@_ );

    my ($k,$format) = (shift,shift);

    map {

        my $template = {

            'text'  => $format,
            'value' => $_,
        };

        Hub::happendv( $self->{'public:'}, $k, $template, '-asa=1' );

    } @_;

}#compfv

# ------------------------------------------------------------------------------
# compdv - Compose data value
#
# compdv ADDRESS, VALUE...
# ------------------------------------------------------------------------------

sub compdv {

    my ($self,$opts) = Hub::objopts( \@_ );

    my $k = shift;

    map { Hub::happendv( $self->{'public:'}, $k, $_, '-asa=1' ) } @_;

}#compdv

# ------------------------------------------------------------------------------
# populate - Return a populated version of this template.
#
# populate [\HASH]...
# ------------------------------------------------------------------------------

sub populate {

    my ($self,$opts) = Hub::objopts( \@_ );

    return $self->{'parser'}->populate(
        $self->{'public:'}, @_, -opts => $opts );

}#populate

# ------------------------------------------------------------------------------

'???';
