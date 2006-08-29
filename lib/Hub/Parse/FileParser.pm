package Hub::Parse::FileParser;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our @ISA        = qw/Hub::Parse::Parser/;
our @EXPORT     = qw//;
our @EXPORT_OK  = qw//;

# ------------------------------------------------------------------------------
# new - Constructor
#
# new FILESPEC
# 
# This is a singleton.
# FILESPEC is an absolute path or a relative runtime path.
# ------------------------------------------------------------------------------

sub new {

    my ($opts,$self,$spec) = Hub::opts( \@_ );

	my $class = ref( $self ) || $self;

    croak 'File spec required' unless $spec;

    my $fn = Hub::spath( $spec ) or croak "$!: $spec";

    my $obj = Hub::fhandler( $fn, $class );

    unless( $obj ) {

        $obj = $self->SUPER::new( -opts => $opts );

        Hub::fattach( $fn, $obj );

    }#unless

    return $obj;

}#new

# ------------------------------------------------------------------------------
# parsefile - Parse template file
#
# Supports the FileCache interface.
# ------------------------------------------------------------------------------

sub parsefile {

    my ($self,$opts,$file) = Hub::objopts( \@_ );

    $self->{'template'} = \$file->{'contents'};

}#parsefile



'???';
