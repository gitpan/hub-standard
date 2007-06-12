package Hub::Parse::FileParser;
use strict;

use Hub qw/:lib/;

push our @ISA, qw/Hub::Parse::StandardParser/;

our $VERSION        = '4.00012';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw//;

# ------------------------------------------------------------------------------
# new - Construct (or retrieve) an instance of this class.
# new $filespec
# 
# This is a singleton per physical file.
# $filespec is an absolute path or a relative runtime path.
# ------------------------------------------------------------------------------

sub new {
  my ($opts,$self,$spec) = Hub::opts( \@_ );
	my $class = ref( $self ) || $self;
  croak 'File spec required' unless $spec;
  my $fn = Hub::srcpath( $spec ) or croak "$!: $spec";
  my $obj = Hub::fhandler( $fn, $class );
  unless( $obj ) {
    $obj = $self->SUPER::new( -opts => $opts );
    Hub::fattach( $fn, $obj );
  }
  return $obj;
}#new

# ------------------------------------------------------------------------------
# reload - Callback from L<FileCache>
# Called when instantiating the first instance or the file has changed on disk.
# ------------------------------------------------------------------------------

sub reload {
  my ($self,$opts,$file) = Hub::objopts(\@_);
  $self->{'template'} = \$file->{'contents'};
}#reload

1;
