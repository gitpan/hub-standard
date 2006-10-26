package Hub;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Time::HiRes     qw/time gettimeofday tv_interval/;

our $LIB_START_TIME = [gettimeofday];

$SIG{__WARN__}      = \&_sigwarn; # note this is NOT declared local

our @ISA            = qw/Exporter/;
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/mkinst regns getns callback $Hub/;
our $VERSION        = '3.01048';

our %METHODMAP      = (); # Maps method names to their implementing package
our %OBJECTMAP      = (); # Maps package short names to full name

# ------------------------------------------------------------------------------
# TAG_MAP - Specify virtual tags per directory
#
# Symbols exported by modules under the specified directory will be added to
# each virtual-tag.  Virtual tags are the elements of the array.
#
# Note: by default, each directory name (lower-cased) is a tag, and should not 
# be listed here.  As in, all modules in the 'Knots' subdirectory are exposed 
# with the ':knots' tag.
# ------------------------------------------------------------------------------

our %TAG_MAP = (

    'Base'      => [ 'standard', ],
    'Data'      => [ 'standard', ],
    'Knots'     => [ 'standard', ],
    'Parse'     => [ 'standard', ],
    'Perl'      => [ 'standard', ],

);

# ------------------------------------------------------------------------------
# Gather symbols
#
# Here we load internal and external modules, adding their exports to our
# export arrays.
#
# External modules (like Carp) are exported for our internal modules' 
# convienence under the ':lib' tag.
#
# Internal modules are tagged according to the directory the reside in, and 
# also any additional tags defined in %TAG_MAP.
#
# By default, nothing exported from this or any other internal or external
# module.
# ------------------------------------------------------------------------------

map { $METHODMAP{$_} = 'Hub' } @EXPORT_OK;

push @EXPORT_OK, _load_external_libs();

our %EXPORT_TAGS = (

    'lib'       => [ @EXPORT_OK ],
    'standard'  => [ @EXPORT_OK ],

);

_load_internal_libs();

push @EXPORT_OK, keys %METHODMAP;

push @{$EXPORT_TAGS{'all'}}, @EXPORT_OK;

# ------------------------------------------------------------------------------
# Runtime variables
# ------------------------------------------------------------------------------

our $Hub            = (); # Hub instance for this thread
our $REGISTRY       = {}; # The root symbol for all variables
our $HUBSTACK       = regns( 'HUBSTACK', [] ); # Nested instance calls

$Hub = mkinst( 'Scope', regns('LIBRARY') );

$Hub->prepare();

# ------------------------------------------------------------------------------
# _sigwarn
# 
# Warning handler.  Supresses annoyances.
# ------------------------------------------------------------------------------

sub _sigwarn {

    my $msg = shift || return;

    chomp $msg if $msg;

    if( $msg =~ "^Use of uninitialized value in" ) {

        if( defined $Hub && Hub::check( -blessed => $Hub ) ) {

            Hub::lwarn( $msg ) if $msg;

            return;

        }#if

    }#if

    print STDERR $msg, "\n";

}#_sigwarn

# ------------------------------------------------------------------------------
# _load_external_libs - Load external modules.
#
# Share minimal list of standard functions which every module in its right mind
# would use.
# ------------------------------------------------------------------------------

sub _load_external_libs {

    use Exporter        qw/import/;
    use Carp            qw/carp croak cluck confess/;
    use Scalar::Util    qw/blessed/;
    use Cwd;
    use IO::File;

    # Time::HiRes is included earlier (to capture a truer start-time)

    return qw/

        import
        carp
        croak
        cluck
        confess
        blessed
        time
        gettimeofday
        tv_interval

    /, @Cwd::EXPORT;

}#_load_external_libs

# ------------------------------------------------------------------------------
# _load_internal_libs
# 
# We want to import all EXPORT_OK methods from packages.
# ------------------------------------------------------------------------------

sub _load_internal_libs {

    my ($libdir) = $INC{'Hub.pm'} =~ /(.*)\.pm$/;

    my @libq = map { _tagname($_), $_ } _findmodules( $libdir, 'Hub' );

    no strict 'refs';

    while( @libq ) {

        my ($tag_names,$pkgname) = (shift @libq, shift @libq);

        my $pkgpath = $pkgname;

        $pkgpath =~ s/::/\//g;

        $pkgpath .= '.pm';

        if( $INC{$pkgpath} ) {
        
            do $pkgpath;

        } else {

             require $pkgpath;

        }#if

        my $names = \@{"${pkgname}::EXPORT_OK"};

        foreach my $name ( @$names ) {

            if( $METHODMAP{$name} || grep /^$name$/, @EXPORT_OK ) {

                die 'Duplicate name on import: '
                    . "$name defined in '$pkgname' and '$METHODMAP{$name}'";

            }#if

            $METHODMAP{$name} = $pkgname;

            foreach my $tag_name ( @$tag_names ) {

                push @{$EXPORT_TAGS{$tag_name}}, $name;

            }#for

            # All exported names in capital characters and underscore
            # are constants by convention

            push @{$EXPORT_TAGS{'const'}}, $name if( $name =~ /^[A-Z_]+$/ );

        }#foreach

        my $import = \&{"${pkgname}::import"};

        &$import( $pkgname, @$names ) if @$names && ref($import) eq 'CODE';

        if( UNIVERSAL::can( $pkgname, 'new' ) ) {

            my ($aka) = $pkgname =~ /.*:(\w+)/;

            if( $OBJECTMAP{$aka} ) {

                die 'Duplicate object package on import: '
                    . "$aka represents '$pkgname' and '$OBJECTMAP{$aka}'";

            }#if

            $OBJECTMAP{$aka} = $pkgname;

        }#if

    }#while

}#_load_internal_libs

# ------------------------------------------------------------------------------
# _findmodules DIRECTORY, PACKAGENAME
# 
# Searches in the sub-directory of this top-level-module for all library files
# to represent.
#
# Recursive.
# ------------------------------------------------------------------------------

sub _findmodules {

    my ($dir,$pkg) = @_;

    my @libs = ();

    my $fh  = IO::File->new();

    opendir $fh, $dir or die "$!: $dir";

    my @all = grep ! /^(\.+|auto|CVS)$/, readdir $fh;

    closedir $fh;

    foreach my $name ( @all ) {

        if( -d "$dir/$name" ) {

            push @libs, map { $pkg . '::' . $_ } _findmodules( "$dir/$name", $name );

        } else {

            $name =~ s/\.pm$// and push @libs, $pkg . '::' . $name;

        }#if

    }#foreach
    
    return @libs;

}#_findmodules

# ------------------------------------------------------------------------------
# _tagname MODULENAME
# 
# Control which EXPORT_TAGS tag is used depending on module location.
# ------------------------------------------------------------------------------

sub _tagname {

    my ($dir) = $_[0] =~ /[A-Za-z]+::([A-Za-z]+)::.*/;

    my @tags = defined $TAG_MAP{$dir} ? @{$TAG_MAP{$dir}} : ();

    return [ lc($dir), @tags ];

}#_tagname

# ------------------------------------------------------------------------------
# mkinst SHORTNAME
#
# Create an instance (object) by its short name.
# See also L<hubuse>.
# ------------------------------------------------------------------------------
#|test(true)    ref( mkinst( 'Logger' ) ) eq 'Hub::Base::Logger';
#|test(abort)   mkinst( 'DoesNotExist' );
# ------------------------------------------------------------------------------

sub mkinst {

    my $aka = shift;

    croak "Module not loaded: $aka" unless $OBJECTMAP{$aka};

    local $_;

    return $OBJECTMAP{$aka}->new( @_ );

}#mkinst

#-------------------------------------------------------------------------------
# callback SUB
#
# Main invocation method.
#-------------------------------------------------------------------------------

sub callback {

    push @$HUBSTACK, $Hub;

    $Hub = mkinst( 'Scope', regns(Hub::abspath($0)) );

    my $ret = $Hub->run( @_ );

    $Hub = pop @$HUBSTACK;

    return $ret;

}#callback

# ------------------------------------------------------------------------------
# regns NAME, [VALUE]
# 
# Register namespace.
# Intended for Hub library modules only.>
# ------------------------------------------------------------------------------

sub regns {

    my $ns = shift or return;

    my $val = shift || {};

    $REGISTRY->{$ns} ||= $val;

    return $REGISTRY->{$ns};

}#regns

# ------------------------------------------------------------------------------
# getns NAME, [ADDRESS]
# 
# Get namespace.
# I<Intended for Hub library modules only.>
# ------------------------------------------------------------------------------

sub getns {

    my $ns = shift or return;

    return hgetv( $REGISTRY->{$ns}, @_ ) if( @_ );

    return $REGISTRY->{$ns};

}#getns

# ------------------------------------------------------------------------------
# END
# 
# Finish library wheel.
# ------------------------------------------------------------------------------

sub END {

    ref($Hub) and $Hub->finish( -tstamp => $LIB_START_TIME );

}#END

# ------------------------------------------------------------------------------

'???';
