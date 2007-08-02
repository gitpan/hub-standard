package Hub::Parse::TextTemplate;
use strict;

use Hub qw/:lib/;

push our @ISA, qw/Hub::Parse::Template/;

our $VERSION        = '4.00043';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw//;

# ------------------------------------------------------------------------------
# refresh - Reset to initial state (persistent object method)
# refresh $text
# ------------------------------------------------------------------------------

sub refresh {
    my ($self,$opts) = Hub::objopts( \@_ );
    my $template = shift or croak "template text required";
    $self->{'parser'} = mkinst( 'StandardParser', $template );
    Hub::merge( $self->{'public:'}, @_ ) if @_;
}#refresh

# ------------------------------------------------------------------------------
1;
