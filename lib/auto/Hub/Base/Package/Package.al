# NOTE: Changes made here will be lost when bulksplit is run again.
package Hub::Base::Package;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Package
#
# Called by the framework to invoke Autoloader::AUTOLOAD, in essence loading
# this file.
# ------------------------------------------------------------------------------
sub Package {
}#Package

#line 12

# ------------------------------------------------------------------------------
# modexec - Execute runtime module
# ------------------------------------------------------------------------------

sub modexec {

    my $opts = Hub::opts( \@_ );

    my $name = shift or confess 'Runtime module expected';

    my $args = shift || [];

    my $path = 'run/';

    $$opts{'in'} and $path .= $$opts{'in'} . '/';

    $path .= $name . '/module.pm';

    $path = Hub::spath( $path );

    my $pkg = mkinst( 'Package', $path );

    return $pkg->call( 'run', @$args );

}#modexec

# ------------------------------------------------------------------------------
# new FILENAME
# 
# Constructor
# This is a singleton
# ------------------------------------------------------------------------------

sub new {

	my $self        = shift;
    my $filename    = Hub::abspath( shift ) or croak "Filename required";
	my $classname   = ref( $self ) || $self;

    my $object = Hub::fhandler( $filename, $classname );

    unless( $object ) {

        my $package = Hub::getpath( $filename );

        $package =~ s/[\s\W]/_/g;

        $self = {
            'filename' => $filename,
            'package'  => $package,
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

    return &$sub( @_ );

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

    my $instance = shift or croak "Instance required";
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

1;
