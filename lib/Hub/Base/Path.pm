package Hub::Base::Path;

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

# ------------------------------------------------------------------------------
# pushwp
# 
# Push path onto working directory stack
# ------------------------------------------------------------------------------

sub pushwp {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    push @{$$self{'workpath'}}, @_;

}#pushwp

# ------------------------------------------------------------------------------
# popwp
# 
# Pop path from working directory stack
# ------------------------------------------------------------------------------

sub popwp {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    return pop @{$$self{'workpath'}};

}#popwp

# ------------------------------------------------------------------------------
# pushsp
# 
# Push path onto source directory stack
# ------------------------------------------------------------------------------

sub pushsp {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    map {

        if( $_ ) {

            my $spec = Hub::fixpath( Hub::abspath("$_") );

            $spec and push @{$$self{'srcpath'}}, $spec;

        }#if

    } @_;


}#pushsp

# ------------------------------------------------------------------------------
# popsp
# 
# Pop path from source directory stack
# ------------------------------------------------------------------------------

sub popsp {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    return pop @{$$self{'srcpath'}};

}#popsp

# ------------------------------------------------------------------------------
# srcpath - Source path
#
# srcpath $FILE
#
# Return the source path to $FILE.
# ------------------------------------------------------------------------------

sub srcpath {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";
    my $opts        = Hub::opts( \@_ );

    my $unknown     = shift || return;

    Hub::lmsg( "? $unknown", "path" );

    # it is already a valid path?
    Hub::filetest( $unknown ) and return $unknown;

    for( @{$$self{'workpath'}}, @{$$self{'srcpath'}} ) {

        next unless $_;

        my $spec = Hub::fixpath( "$_/$unknown" );

        Hub::lmsg( " - $spec", "path" );

        if( Hub::filetest( $spec ) ) {

            return $spec;

        }#if

    }#for

}#srcpath

# ------------------------------------------------------------------------------
# respath
# 
# Resource file
# ------------------------------------------------------------------------------

sub respath {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

}#respath

# ------------------------------------------------------------------------------
# resdir
# 
# Resource directory
# ------------------------------------------------------------------------------

sub resdir {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

}#resdir

# ------------------------------------------------------------------------------
# new
# 
# Constructor
# ------------------------------------------------------------------------------

sub new {

	my $self    = shift;
	my $class   = ref( $self ) || $self;
	my $obj     = bless {}, $class;

    $obj->refresh( @_ );

    return $obj;

}#new

# ------------------------------------------------------------------------------
# refresh
# 
# Initialize
# ------------------------------------------------------------------------------

sub refresh {

    my $self        = shift;
    my $classname   = ref($self) or die "Illegal call to instance method";

    $self->{'srcpath'}  = [ Hub::getpath($0), ];
    $self->{'workpath'} = [ Hub::getpath($0), ];
    $self->{'respath'}  = [ Hub::getpath($0), ];

}#refresh


'???';
