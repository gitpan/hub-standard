# NOTE: Changes made here will be lost when bulksplit is run again.
package Hub::Base::Instance;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Instance
#
# Called by the framework to invoke Autoloader::AUTOLOAD, in essence loading
# this file.
# ------------------------------------------------------------------------------
sub Instance {
}#Instance

#line 21

# ------------------------------------------------------------------------------
# Add our aliases (autoload functions)
# ------------------------------------------------------------------------------

#map { push @EXPORT_OK, "${_}gv" } split '|', $HANDLERS; # global
#map { push @EXPORT_OK, "${_}cv" } split '|', $HANDLERS; # config
#map { push @EXPORT_OK, "${_}pv" } split '|', $HANDLERS; # persistent
#map { push @EXPORT_OK, "${_}iv" } split '|', $HANDLERS; # instance

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
# where ? can be i|p|c
#
# Object calls: (anything that isn't a data-handler).
# ------------------------------------------------------------------------------

sub AUTOLOAD {

    my $self = shift;
    my $name = $AUTOLOAD;

    croak "Method unavailable outside of callback" unless ref($self);

    if( $name =~ /::($HANDLERS)([ipc])v$/ ) {

        my $action = 'Hub::h' . $1 . 'v';

        my $top = $NSMAP{$2};

        croak "No such data handler: $name" unless $top;

        my $key = shift;

        my $addr = ();

        ref($key) eq 'ARRAY' and @$addr = map { "$top/$_" } @$key;

        ref($key) eq 'HASH'  and %$addr = map { +"$top/$_", $$key{$_} } keys %$key;

        !ref($key) and $addr = $key eq '/' ? $top : "$top/$key";

        unshift @_, $self, $addr;

        goto &$action;

    } else {

        if( $name =~ /::(\w+)$/ ) {

            return $self->obj( $1 );

        }#if

        croak "Unknown instance call: $name";

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

    if( Hub::hgetv( $self, "$NSMAP{'o'}/$key" ) ) {

        $self->obj($key)->refresh() if( defined &$classname::refresh );

        return $self->obj($key);

    } else {

        my $obj = Hub::mkinst( $aka, @_ );

        return Hub::hsetv( $self, "$NSMAP{'o'}/$key", $obj );

    }#if

}#mkobj

# ------------------------------------------------------------------------------
# rmobj ADDRESS
# 
# Remove (unregister or release) an object.
# Returns like 'obj'.
# ------------------------------------------------------------------------------

sub rmobj {

    my $self = shift;
    croak "Method unavailable outside of callback" unless ref($self);

    return Hub::htakev( $self, "$NSMAP{'o'}/$_[0]" );

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

    my $obj = Hub::hgetv( $self, "$NSMAP{'o'}/$_[0]" );

    return defined $obj ? $obj : Hub::mkinst( 'NoOp', $_[0] );

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

}#prepare

# ------------------------------------------------------------------------------
# finish
# 
# The caller's script has completed.
# Commit, flush, synchronize, delete temporaries, etc...
# ------------------------------------------------------------------------------

sub finish {

    my $self = shift;
    Hub::expect( '-blessed' => $self );
    my $opts = Hub::opts( \@_ );

    # write out log messages
    Hub::lflush( -tstamp => $$opts{'tstamp'} );

    # save 'writebehind' hashfiles to disk
    Hub::hfsync();

    # remove instance variables
    Hub::htakev( $self, $NSMAP{'i'} );

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

    #
    # Load base configuration
    #

    my $hf = Hub::mkinst( 'HashFile', '.conf' );

    $self->setcv( '/', $hf->data() );

    #
    # Load custom configuration
    #

    my $script_conf = Hub::subst( Hub::getname($0), '\.\w+$', '.hf' );

    my $script_path = Hub::abspath( Hub::getpath($0) . '/' );

    my @conf_files = (

     $self->getcv( 'path/conf' ) . '/' . $script_conf,

     $script_path . '/' . $script_conf,

     $script_path . '/conf/' . $script_conf,

    );

    foreach my $conf_fn ( @conf_files ) {

        if( $conf_fn && Hub::filetest( $conf_fn  ) ) {

            $hf = Hub::mkinst( 'HashFile', $conf_fn );

            Hub::merge( $self->getcv('/'), $hf->data(), '--overwrite' );

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
    
        'sys/zname'     => Hub::getname($0),
        'sys/tstamp'    => time,

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

1;
