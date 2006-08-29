# NOTE: Changes made here will be lost when bulksplit is run again.
package Hub::Data::Archive;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Archive
#
# Called by the framework to invoke Autoloader::AUTOLOAD, in essence loading
# this file.
# ------------------------------------------------------------------------------
sub Archive {
}#Archive

#line 11

use Archive::Tar;
use IO::Zlib;
use constant        COMPRESSION => 5;

# ------------------------------------------------------------------------------
# carch FILE, DIR, LIST
# 
# Create archive
#
# Where:
#
#   FILE            absolute path to the archive
#   DIR             perform in this directory
#   LIST            array reference of filenames (relative to DIR or absolute)
# ------------------------------------------------------------------------------

sub carch {

    my $file = shift;
    my $in = shift;
    my $files = shift;

    return _perform( "create", $file, $in, $files );

}#carch

# ------------------------------------------------------------------------------
# larch FILE
# 
# List archive
#
# Where:
#
#   FILE            absolute path to the archive
# ------------------------------------------------------------------------------

sub larch {

    my $file = shift;

    return _perform( "list", $file );

}#larch

# ------------------------------------------------------------------------------
# xarch FILE, DIR
# 
# Extract archive
#
# Where:
#
#   FILE            absolute path to the archive
#   DIR             perform in this directory
# ------------------------------------------------------------------------------

sub xarch {

    my $file = shift;
    my $in = shift;

    return _perform( "extract", $file, $in );

}#xarch

# ------------------------------------------------------------------------------
# _perform ACTION, FILE, DIR, [MORE]
# 
# Perform Archive::Tar class method events.
#
# Where:
#
#   ACTION          extract|create|list
#   FILE            absolute path to the archive
#   DIR             perform in this directory
#   MORE            for creating archives, this is an array reference
# ------------------------------------------------------------------------------

sub _perform {

    my $action = shift;
    my $file = shift;
    my $in = shift;

    my $owd = cwd();

    my $ret = ();

    $in ||= $owd;

    if( Hub::filetest( $in, '-d' ) ) {

        my $ok = 1;

        chdir $in;

        if( $action eq "extract" ) {

            @$ret = Archive::Tar->extract_archive( $file, COMPRESSION );

            $ok = 0 if( $#$ret < 0 );

            if( $ok ) {

                Hub::touch( @$ret );

            }#if

        } elsif( $action eq "create" ) {

            my $list = ();

            my $files = shift;

            if( ref($files) eq 'ARRAY' ) {

                $list = $files;

            } elsif( ref($files) eq 'HASH' ) {

                @$list = Hub::find( '.', $files );

            } elsif( $files ) {

                @$list = Hub::find( '.', -include => [ $files ] );

            } else {

                $ok = 0;

            }#if

            Archive::Tar->create_archive( $file, COMPRESSION, @$list );

            if( $Archive::Tar::error ) {
            
                $ok = 0;

            } else {

                $ret = $file;

            }#if

        } elsif( $action eq "list" ) {

            @$ret = Archive::Tar->list_archive( $file, COMPRESSION );

            $ok = 0 if( $#$ret < 0 );

        }#if

        unless( $ok ) {

            Hub::lerr( Archive::Tar->error() );

            $Archive::Tar::error = "";

        }#unless

        chdir $owd;

    }#if

    return $ret;

}#_perform

# ------------------------------------------------------------------------------

1;
