package Hub::Data::FileCache;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/fattach fhandler frefresh/;
our $NAMESPACE      = Hub::regns( 'filecache' );

#!BulkSplit

# ------------------------------------------------------------------------------
# fattach FILENAME, CLASS
# 
# Attach an instance of a class (which has a corresponding 'parsefile' method)
# to a file.
#
# Returns an instance, which is a hash with members:
#
#   lastread    # mod time last time we read it
#   filename    # name
#   lines       # ARRAY of lines in the file
#   handlers    # HASH of attached classes
#
# The instance is a singleton.
# ------------------------------------------------------------------------------

sub fattach {

    my $opts = Hub::opts( \@_ );
    my $filename = shift or croak "Filename required";
    my $handler = shift;

    croak "Object expected" unless ref($handler);

    $filename = Hub::abspath( $filename );

    my $instance = $$NAMESPACE{$filename};

    if( defined $instance ) {

        if( $instance->{'handlers'}{$handler} ) {

            croak "Already attached";

        } else {

            $instance->{'handlers'}{$handler} = $handler;

            $handler->parsefile( $instance );

        }#if

    } else {

        $instance = {

            'filename'  => $filename,
            'handlers'  => { $handler => $handler, },

        };

        _read_from_disk( $instance );

    }#unless

    return $instance;

}#fattach

# ------------------------------------------------------------------------------
# fhandler FILENAME, CLASSNAME
# 
# Find the instance of a particular class which is attached to the file
# ------------------------------------------------------------------------------

sub fhandler {

    my $filename = shift or croak "Filename required";
    my $classname = shift or croak "Classname required";
    my @handlers = ();
    my $instance = $$NAMESPACE{Hub::abspath($filename)};

    if( defined $instance ) {

        map { push @handlers, $_ if ref($_) eq $classname }
            values %{$instance->{'handlers'}};

    }#if

    wantarray and return @handlers;

    return pop @handlers;

}#fhandler

# ------------------------------------------------------------------------------
# frefresh
# 
# Signal all instances to check to see if their file on disk has been modified.
# If so, re-read the file and tell all your handlers to reparse themselves.
# ------------------------------------------------------------------------------

sub frefresh {

    foreach my $instance ( values %$NAMESPACE ) {

        my @stats = stat $instance->{'filename'};

        if( $stats[9] == 0 ) {

            # file no longer exists

            delete $NAMESPACE->{$instance->{'filename'}};

        } elsif( $stats[9] > $instance->{'lastread'} ) {

            _read_from_disk( $instance );

        }#if

    }#foreach

}#frefresh

# ------------------------------------------------------------------------------
# _read_from_disk
# 
# Modify the provided instance to reflect what is on disk.
# ------------------------------------------------------------------------------

sub _read_from_disk {

    my $instance    = shift;
    my $filename    = $instance->{'filename'};
    my @contents    = Hub::readfile( $filename, '-asa=1' );
    my @stats       = stat $filename;

    $instance->{'lastread'} = $stats[9];
    $instance->{'filename'} = $filename;
    $instance->{'lines'}    = [ @contents ];
    $instance->{'contents'} = '';

    map { $instance->{'contents'} .= $_ } @contents;

    map { $_->parsefile( $instance ); } values %{$instance->{'handlers'}};

    $$NAMESPACE{$filename} = $instance;
    
}#_read_from_disk

# ------------------------------------------------------------------------------

'???';
