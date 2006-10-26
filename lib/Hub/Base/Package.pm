package Hub::Base::Package;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our ($AUTOLOAD);

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/modexec/;

#!BulkSplit

# ------------------------------------------------------------------------------
# modexec - Execute runtime module
# ------------------------------------------------------------------------------

sub modexec {

    my $opts = Hub::opts( \@_ );

    my $name = shift or confess 'Runtime module expected';

    my $args = shift || [];

    my $spec = $$opts{'in'} ? $$opts{'in'} . '/' : '';

    $spec .= $name . '/module.pm';

    my $path = Hub::spath( $spec );

    if( $path ) {

        my $pkg = mkinst( 'Package', $path );

        return $pkg->call( 'run', @$args );

    } else {

        Hub::lwarn( "Module not found: $spec");

    }#if

}#modexec

# ------------------------------------------------------------------------------
# new FILENAME
# 
# Constructor
# This is a singleton
# ------------------------------------------------------------------------------

sub new {

	my $self        = shift;
    my $filename    = Hub::abspath( shift ) or confess "Filename required";
	my $classname   = ref( $self ) || $self;

    my $object = Hub::fhandler( $filename, $classname );

    unless( $object ) {

        my $package = my $workdir = Hub::getpath( $filename );

        $package =~ s/[\s\W]/_/g;

        $self = {
            'filename' => $filename,
            'package'  => $package,
            'workdir'  => $workdir,
        };

        $object = bless $self, $classname;

        Hub::fattach( $filename, $object );

    }#unless

    return $object;

}#new

# ------------------------------------------------------------------------------
# call METHOD, [ARGS]
# 
# Call a method in the representing package
# Note that AUTOLOAD methods do not pass the 'defined' test
# ------------------------------------------------------------------------------

sub call {

    my $self = shift;
    my $classname = ref($self) or croak "Illegal call to instance method";
    my $method = shift or croak "Method required";

    my $sub = $$self{'package'} . '::' . $method;

    no strict 'refs';

    $Hub->path->pushwp( $$self{'workdir'} ) if( defined $Hub->path );

    my $result = &$sub( @_ );

    $Hub->path->popwp() if( defined $Hub->path );

    return $result;

}#call

# ------------------------------------------------------------------------------
# AUTOLOAD
# 
# Call a method in the representing package
# Note! Use the subroutine 'call' to access methods which are already 
# implemented in this class (new|call|parsefile).
# ------------------------------------------------------------------------------

sub AUTOLOAD {

    my $self = shift;
    my $classname = ref($self) or croak "Illegal call to instance method";
    my $name = $AUTOLOAD;

    if( $name =~ /::(\w+)$/ ) {

        return $self->call( $1, @_ );

    } else {

        die "Unhandled AUTOLOAD name";

    }#if

}#AUTOLOAD

# ------------------------------------------------------------------------------
# DESTROY
# 
# Defining this function prevents it from being searched in AUTOLOAD
# ------------------------------------------------------------------------------

sub DESTROY {

}#DESTROY

# ------------------------------------------------------------------------------
# parsefile INSTANCE
# 
# Called implicty on the first attachment or when the file has been modified
# on disk.
# ------------------------------------------------------------------------------

sub parsefile {

    my $self = shift;
    my $classname = ref($self) or croak "Illegal call to instance method";

    my $instance = shift or croak "Class instance required";
    my $contents = $$instance{'contents'};
    $contents =~ s/\bPACKAGE\b/$self->{'package'}/mg;

    local $!;
    eval $contents;

    if( $@ ) {
        my $error = $@;
        my ($eval_number) = $error =~ s/\(eval (\d+)\)/$$instance{'filename'}/;
        die $error;
    }#if

}#parsefile

# ------------------------------------------------------------------------------

'???';
