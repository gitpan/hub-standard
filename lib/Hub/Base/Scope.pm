package Hub::Base::Scope;

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
our @EXPORT_OK      = qw//;

our $HANDLERS       = qq/get|take|set|append/;

our %NSMAP = (
    'i', 'var',     # Instance (reset at end of callback)
    'c', 'sys',     # Configuration
    'p', 'etc',     # Persistent instance (not reset)
    'o', 'obj',     # Persistent objects (->refresh supported)
    'u', 'usr',     # session->getmeta() *webapp*
);

#!BulkSplit

# ------------------------------------------------------------------------------
# new
# 
# Constructor
# ------------------------------------------------------------------------------

sub new {

	my $self        = shift;
	my $classname   = ref( $self ) || $self;
    my $ns          = shift or die "Namespace required";

	$self = bless $ns, $classname;

    tie %$self, 'Hub::Knots::TiedObject', 'Hub::Knots::Addressable';

    return $self;

}#new

# ------------------------------------------------------------------------------
# run SUB
# 
# Main action method
# ------------------------------------------------------------------------------

sub run {

    my $self = shift;
    croak "Method unavailable outside of callback" unless ref($self);

    my $sub = shift;

    unless( defined &$sub ) {

        Hub::lflush();

        croak "$0: Callback subroutine ($sub) not defined";

    }#unless

    $self->prepare();

    my $ret = &$sub( @_ );

    my $err = $@;

    $self->finish();

    croak $err if $err;

    return $ret;

}#run

# ------------------------------------------------------------------------------
# comptv ADDRESS, TEMPLATE, VALUEHASH
# 
# Aka: Compose data value.
# ------------------------------------------------------------------------------

sub comptv {

    my ($self,$opts) = Hub::objopts( \@_ );

    my ($k,$t) = (shift,shift);

    my $template = Hub::mkinst( 'Template', $t, @_ );

    $self->appendiv( $k, $template, '-asa=1' );

}#comptv

# ------------------------------------------------------------------------------
# compdv - Compose data value
#
# compdv ADDRESS, VALUE...
# ------------------------------------------------------------------------------

sub compdv {

    my ($self,$opts) = Hub::objopts( \@_ );

    my $k = shift;

    map { $self->appendiv( $k, $_, '-asa=1' ) } @_;

}#compdv

# ------------------------------------------------------------------------------
# AUTOLOAD
# 
# Data handlers:
#
#   get?v take?v set?v append?v
#
# where ? can be i|p|c|o
#
# Object calls: (anything that isn't a data-handler).
# ------------------------------------------------------------------------------

sub AUTOLOAD {

    my $self = shift;
    my ($name) = $AUTOLOAD =~ /::(\w+)$/;

    croak "Method unavailable outside of callback" unless ref($self);

    if( $name =~ /($HANDLERS)([ipc])v$/ ) {

        my $action = 'Hub::h' . $1 . 'v';

        my $top = $NSMAP{$2};

        croak "No such data handler: $name" unless $top;

        my $key = shift;

        my $addr = ();

        ref($key) eq 'ARRAY' and @$addr = map { "$top/$_" } @$key;

        ref($key) eq 'HASH'  and %$addr = map { +"$top/$_", $$key{$_} } keys %$key;

        !ref($key) and $addr = $key eq '/' ? $top : "$top/$key";

        unshift @_, $self->{'*tied'}, $addr;

        goto &$action;

    } elsif( $name =~ /^(get|set|append|take)$/ ) {

        my $action = 'Hub::h' . $name . 'v';

        unshift @_, $self->{'*tied'};

        goto &$action;

    } else {

        return $self->obj( $name );

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
# mkobj ADDRESS, CLASS, [ARGS...]
# 
# Make (register or create) a new object.
# Returns like 'obj'.
# ------------------------------------------------------------------------------

sub mkobj {

    my $self = shift;
    croak "Method unavailable outside of callback" unless ref($self);

    my $key = shift;

    my $aka = shift;

    my $classname = $Hub::OBJECTMAP{$aka} or croak "Module not loaded: $aka";

    croak "Classname and key required" unless $classname && $key;

    if( $$self{"$NSMAP{'o'}/$key"} ) {

        $self->obj($key)->refresh() if( defined &$classname::refresh );

        return $self->obj($key);

    } else {

        my $obj = Hub::mkinst( $aka, @_ );

        return $$self{"$NSMAP{'o'}/$key"} = $obj;

    }#if

}#mkobj

# ------------------------------------------------------------------------------
# rmobj ADDRESS
# 
# Remove (unregister or release) an object.
# ------------------------------------------------------------------------------

sub rmobj {

    my $self = shift;
    croak "Method unavailable outside of callback" unless ref($self);

    return delete $$self{"$NSMAP{'o'}/$_[0]"};

}#rmobj

# ------------------------------------------------------------------------------
# obj ADDRESS
# 
# Access a registered object.
# If the object isn't registered, silently log the error via NoOp.
# ------------------------------------------------------------------------------

sub obj {

    my $self = shift;
    croak "Method unavailable outside of callback" unless ref($self);

    my $obj = $$self{"$NSMAP{'o'}/$_[0]"};

#   The idea behind NoOp was to aid in refactoring... but I don't think this is
#   such a good idea, as there are tests which expect it to be undefined...
#
#   return defined $obj ? $obj : Hub::mkinst( 'NoOp', $_[0] );

    return $obj;

}#obj

# ------------------------------------------------------------------------------
# prepare
# 
# The system is about to invoke the caller's script.
# Prepare the instance by creating, refreshing, or initializing data.
# ------------------------------------------------------------------------------

sub prepare {

    my $self = shift;
    croak "Method unavailable outside of callback" unless ref($self);

    $self->mkobj( 'logger',   'Logger' );
    $self->mkobj( 'path',     'Path' );
    $self->mkobj( 'config',   'Config' );

#   $self->mkobj( 'db',       'Data' );
#   $self->mkobj( 'pd',       'PageData' );
#   $self->mkobj( 'ws',       'WebSite' );     # will make 'md'
#   $self->mkobj( 'session',  'Client' );

    $self->_loadconf();

    map { $$self{"/$_"} ||= {} } values %NSMAP;

}#prepare

# ------------------------------------------------------------------------------
# finish
# 
# The caller's script has completed.
# Commit, flush, synchronize, delete temporaries, etc...
# ------------------------------------------------------------------------------

sub finish {

    my $self = shift;
    croak "Method unavailable outside of callback" unless ref($self);

    if( $$self{'/sys/DEBUG'} ) {

        $$self{'/ENV'} = Hub::cpref( \%ENV );

        my $fn = "$$Hub{'/sys/proc/zname'}.stackdump.hf";

        Hub::writefile( $fn, Hub::hffmt( $self ), 0640 );

        delete $$self{'/ENV'};

    }#if

    my $opts = Hub::opts( \@_ );

    # write out log messages
    Hub::lflush( -tstamp => $$opts{'tstamp'} );

    # save 'writebehind' hashfiles to disk
    Hub::hfsync();

    # remove instance variables
    delete $$self{$NSMAP{'i'}};

}#finish

# ------------------------------------------------------------------------------
# _loadconf - Load configuration for script
# 
# Files are loaded in this order (where the script name is 'myscript.pl'):
#
#   .conf               # Always read (Shared by all scrips in same directory)
#   <#server_conf>      # If .conf (above) defines server_conf, it is read here
#   .myscript.hf        # Dot plus name of script, in the script's directory   
#   myscript.hf         # Same name as script, in the script's directory
#   conf/myscript.hf    # Same name as script, in the scripts's 'conf' subdirectory
#
# The intention is that the hidden configuration files:
#
#   '.conf' and '.myscript.hf'
#
# are owned by the 'installer'.  When distributing upgrades of these files are 
# the proper place to make include configuration changes.  While the consumer 
# should make changes in:
#
#   <#server_conf>, myscript.hf, or conf/myscript.hf
#
# Notes:
#
# 1) <#server_conf> is the place to override '.conf' for all scripts in the
# same directory.
#
# 2) 'myscript.hf' and 'conf/myscript.hf' should be used exclusively, where
# conf/myscript.hf is chosen for a cleaner file structure.
# 
# ------------------------------------------------------------------------------

sub _loadconf {

    my $self = shift;
    croak "Method unavailable outside of callback" unless ref($self);

    my $script_path = Hub::abspath( Hub::getpath($0) ) || '.';

    #
    # Load base configuration
    #

    my $hf = Hub::mkinst( 'HashFile', "$script_path/.conf" );

    $self->setcv( '/', Hub::cpref($hf->getv('/')) );

    #
    # Load custom configuration
    #

    my $script_conf = Hub::subst( Hub::getname($0), '\.\w+$', '.hf' );

    my @conf_files = ();

    $$self{'path/conf'} and
        push @conf_files, "$$self{'path/conf'}/$script_conf";
    
    $script_path and
        push @conf_files, Hub::fixpath("$script_path/$script_conf"),
            Hub::fixpath("$script_path/conf/$script_conf");

    foreach my $conf_fn ( @conf_files ) {

        if( $conf_fn && Hub::filetest( $conf_fn  ) ) {

            $hf = Hub::mkinst( 'HashFile', $conf_fn );

            Hub::merge( $self->getcv('/'), Hub::cpref($hf->getv('/')), '--overwrite' );

        }#if

    }#foreach

    #
    # Set source path
    #

    my $srcpaths = [ 'path/source', 'path/runtime' ];

    $self->obj('path')->pushsp( $self->getcv( $srcpaths ) );

    #
    # Convienence constants
    #

    $self->setcv( {
    
        'proc/zname'     => Hub::getname($0),
        'proc/tstamp'    => time,

    } );

    #
    # Set logger options
    #

    my $logkeys = [
        'log/level',
        'log/stack_depth',
        'log/max_size',
        'log/show_source',
        'log/tee',
        'log/disable',
    ];

    my @logopts = $self->getcv( $logkeys, '' );

    Hub::lshow( split /,\s*/, $logopts[0] ) if defined $logopts[0];

    Hub::lopt( 'show_stack',    $logopts[1] ) if defined $logopts[1];
    Hub::lopt( 'max_size',      $logopts[2] ) if defined $logopts[2];
    Hub::lopt( 'show_source',   $logopts[3] ) if defined $logopts[3];
    Hub::lopt( 'tee',           $logopts[4] ) if defined $logopts[4];
    Hub::lopt( 'oppressed',     $logopts[5] ) if defined $logopts[5];

}#_loadconf

# ------------------------------------------------------------------------------

'???';
