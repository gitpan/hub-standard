package Hub;
use strict;

our @ISA            = qw/Exporter/;
our @EXPORT         = qw/$Hub/;
our @EXPORT_OK      = qw/mkinst regns getns trace callback $Hub/;
our $VERSION        = '4.00043';

our %METHODMAP      = (); # Maps method names to their implementing package
our %OBJECTMAP      = (); # Maps object short names to full package name
our %KNOTMAP        = (); # Maps tie-package short names to their full name

# ------------------------------------------------------------------------------
# TAG_MAP - Specify virtual tags per directory
#
# Symbols exported by modules under the specified directory will be added to
# each virtual-tag.  Virtual tags are the elements of the array.
#
# Note: by default, each directory name (lower-cased) is a tag, and should not 
# be listed here.  As in, all EXPORT_OK methods in the 'Knots' subdirectory are 
# exposed with the ':knots' tag.
# ------------------------------------------------------------------------------

our %TAG_MAP = (
    'Base'      => [ 'standard', ],
    'Config'    => [ 'standard', ],
    'Data'      => [ 'standard', ],
    'Knots'     => [ 'standard', ],
    'Parse'     => [ 'standard', ],
    'Perl'      => [ 'standard', ],
    'Misc'      => [ 'standard', ],
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

_load_internal_libs(keys %TAG_MAP);

push @EXPORT_OK, keys %METHODMAP;

# ------------------------------------------------------------------------------
# Runtime variables
# ------------------------------------------------------------------------------

our $Hub = (); # Hub instance for this thread
our $REGISTRY = {}; # The root symbol for all variables
$Hub = mkinst('Registry', regns('LIBRARY'));
$Hub->bootstrap();

# ------------------------------------------------------------------------------
# import - Get symbols from this library
# This adapter method allows us to look at the requested tags before Exporter
# gets ahold of it.  We want to dynamically load internal libraries based
# on the requested tag.  In this way, you can create a new set of modules:
#
#   /path/to/lib/Hub/Mystuff/Peak.pm
#                           /Crescendo.pm
#
# and use them in a file as:
#
#   use Hub(:mystuff);
#
# and you get the same facilities as this library itself.  Meaning you can 
# call EXPORT_OK subroutines of Peak.pm and Crescendo.pm as 
# C<Hub::subroutine()> or just C<subroutine()>.
#
# Inside Peak.pm and Crescendo.pm, you should:
#
#   use Hub(:lib);
#
# So you get the standard set of external symbols, like C<import, carp, croak, 
# cluck, confess, blessed, time, gettimeofday, tv_interval and cwd()>.  See
# L<_load_external_libs>.
#
# If you would like Crescendo.pm to use methods from Peak.pm, you should:
#
#   use Hub(:lib :mystuff);
#
# And then reference those methods as C<Hub::methodname()>.  This is not a
# requirement by any means, but half of the reasons for doing all this in
# the first place is to make refactoring simple.  If you follow this route
# (note you should also be using Hub::mkinst('Peak') to create your objects) 
# than you can move code around without changing the API.
# ------------------------------------------------------------------------------

sub import {
  map {
    if (/^:([\w\d]+)/) {
      my $tagname = $1;
      if ($tagname eq 'all') {
        @{$EXPORT_TAGS{'all'}} = keys %METHODMAP;
        _load_internal_libs($tagname);
      }
      unless (grep /^$tagname$/i, keys %EXPORT_TAGS) {
        $EXPORT_TAGS{$tagname} = [];
#warn "Tag: $tagname\n";
        _load_internal_libs($tagname);
#warn "Got internals\n";
#       if ($tagname eq 'all') {
#         @{$EXPORT_TAGS{'all'}} = keys %METHODMAP;
#warn "OK: ", join(',', @EXPORT_OK), "\n";
#       } else {
          push @{$EXPORT_TAGS{'all'}}, @{$EXPORT_TAGS{$tagname}};
#       }
      }
    }
  } @_;
#warn "Onward then\n";
  goto &Exporter::import;
}

# ------------------------------------------------------------------------------
# _load_external_libs - Load external modules.
#
# Share minimal list of standard functions which every module in its right mind
# would use.
# ------------------------------------------------------------------------------

sub _load_external_libs {
  use UNIVERSAL       qw/isa can/;
  use Exporter        qw//;
  use Carp            qw/carp croak cluck confess/;
  use Scalar::Util    qw/blessed/;
  use Time::HiRes     qw/time gettimeofday tv_interval/;
  use Cwd;
  use IO::File;
  use File::stat;
  return qw/
    isa
    can
    import
    carp
    croak
    cluck
    confess
    blessed
    time
    gettimeofday
    tv_interval
    stat
  /, @Cwd::EXPORT;
}#_load_external_libs

# ------------------------------------------------------------------------------
# _load_internal_libs - We want to import all EXPORT_OK methods from packages.
# _load_internal_libs @list
# _load_internal_libs 'all'
#
# Where each item in @list is the name of a directory beneath 'Hub'.
# ------------------------------------------------------------------------------

sub _load_internal_libs {

  # Find all perl modules under the Hub library directory
  my ($libdir) = $INC{'Hub.pm'} =~ /(.*)\.pm$/;
  my @libq = ();
#warn ">>\n";
  for (@_) {
    if ($_ eq 'all') {
      # All directories which we have yet to process
      my $h = IO::Handle->new();
      opendir $h, $libdir or die "$!: $libdir";
      my @all = grep { !/^(\.+|\.svn|auto|CVS)$/
        && -d "$libdir/$_" } readdir $h;
      closedir $h;
      foreach my $dir (@all) {
#warn " Should we load $dir?\n";
        if (!grep {$_ eq $dir} keys %TAG_MAP) {
#warn "  -yes ($libdir/$dir)\n";
          $TAG_MAP{$dir} = [];
          push @libq, map { _tagname($_), $_ }
            _findmodules( "$libdir/$dir", "Hub::$dir" );
        }
      }
#   } elsif ($_ eq 'reload') {
#     @libq = map { _tagname($_), $_ } _findmodules( $libdir, "Hub" );
    } else {
      my $dir = ucfirst;
      $TAG_MAP{$dir} ||= [];
      push @libq, map { _tagname($_), $_ }
        _findmodules( "$libdir/$dir", "Hub::$dir" );
    }
  }
#warn "<<\n";

  # Load (require) all packages and parse their exported methods.
  my @package_names = ();
  no strict 'refs';
  while( @libq ) {
    my ($tag_names,$pkgname) = (shift @libq, shift @libq);
    push @package_names, $pkgname;
#warn "$pkgname\n";
    my $pkgpath = $pkgname;
    $pkgpath =~ s/::/\//g;
    $pkgpath .= '.pm';
    if( $INC{$pkgpath} ) {
# commented out to suppress subroutine redefined warnings (added Config dir)
#     do $pkgpath;
    } else {
      require $pkgpath;
    }
    my $names = \@{"${pkgname}::EXPORT_OK"};
    foreach my $name ( @$names ) {
      if( $METHODMAP{$name} || grep /^$name$/, @EXPORT_OK ) {
        next if $pkgname eq $METHODMAP{$name};
        warn 'Duplicate name on import: '
            . "$name defined in '$pkgname' and '$METHODMAP{$name}'";
        next;
      }#if
#warn " set: $name\n";
      $METHODMAP{$name} = $pkgname;
      foreach my $tag_name ( @$tag_names ) {
        push @EXPORT_OK, $name;
#warn "   $tag_name/$name\n";
        push @{$EXPORT_TAGS{$tag_name}}, $name;
      }#for
      # All exported names in capital characters and underscore
      # are constants by convention
      if ($name =~ /^[A-Z_]+$/) {
        push @{$EXPORT_TAGS{'const'}}, $name;
        push @{$EXPORT_TAGS{'lib'}}, $name;
      }
    }
    my $import = \&{"${pkgname}::import"};
    &$import( $pkgname, @$names ) if @$names && ref($import) eq 'CODE';
  }

  # Find the packages which are classes.  This is done outside of the above
  # loop so that base classes have had a chance to load.
  foreach my $pkgname (@package_names) {
    if (UNIVERSAL::can($pkgname, 'new')) {
      my ($aka) = $pkgname =~ /.*:(\w+)/;
      if( $OBJECTMAP{$aka} ) {
        die 'Duplicate object package on import: '
            . "$aka represents '$pkgname' and '$OBJECTMAP{$aka}'";
      }
      $OBJECTMAP{$aka} = $pkgname;
    } elsif (UNIVERSAL::can($pkgname, 'TIEHASH')
        || UNIVERSAL::can($pkgname, 'TIEARRAY')
        || UNIVERSAL::can($pkgname, 'TIESCALAR')) {
      my ($aka) = $pkgname =~ /.*:(\w+)/;
      if ($KNOTMAP{$aka}) {
        die 'Duplicate tie package on import: '
            . "$aka represents '$pkgname' and '$KNOTMAP{$aka}'";
      }
      $KNOTMAP{$aka} = $pkgname;
    }
  }

}#_load_internal_libs

# ------------------------------------------------------------------------------
# _findmodules - Recursively get module names
# _findmodules $directory, $package_name
# 
# Searches in the sub-directory of this top-level-module for all library files
# to represent.  $package_name is the package (directory) name which
# corresponds to the given $directory.
#
# Recursive.
# ------------------------------------------------------------------------------

sub _findmodules {

    # List directory
    my ($dir,$pkg) = @_;
    my @libs = ();
    my $fh  = IO::Handle->new();
    opendir $fh, $dir or die "$!: $dir";
    my @all = grep ! /^(\.+|\.svn|auto|CVS)$/, readdir $fh;
    closedir $fh;

    # Extract package names and paths, and exusively process sub-directories
    foreach my $name ( @all ) {
        if( -d "$dir/$name" ) {
#warn "  -gather $dir/$name\n";
            push @libs, map { $pkg . '::' . $_ }
              _findmodules( "$dir/$name", $name );
        } else {
            $name =~ s/\.pm$// and push @libs, $pkg . '::' . $name;
        }
    }
    
    return @libs;

}#_findmodules

# ------------------------------------------------------------------------------
# _tagname - Return which EXPORT_TAGS key to which a module should belong.
# _tagname $module_name
# ------------------------------------------------------------------------------

sub _tagname {
    my ($dir) = $_[0] =~ /[0-9A-Za-z]+::([0-9A-Za-z]+)::.*/;
    my @tags = defined $TAG_MAP{$dir} ? @{$TAG_MAP{$dir}} : ();
#warn "tags for: $dir: " . join(";",@tags), "\n";
    return [ lc($dir), @tags ];
}#_tagname

# ------------------------------------------------------------------------------
# mkinst - Create an instance (object) by its short name.
# mkinst $short_name
#
# See also L<hubuse>.
# ------------------------------------------------------------------------------
#|test(true)    ref(mkinst('Object')) eq 'Hub::Base::Object';
#|test(abort)   mkinst('DoesNotExist');
# ------------------------------------------------------------------------------

sub mkinst {
  my $aka = shift;
  croak "Module not loaded: $aka" unless $OBJECTMAP{$aka};
  local $_;
  return $OBJECTMAP{$aka}->new( @_ );
}#mkinst

# ------------------------------------------------------------------------------
# knot - Return the implementing package (full name) for the given knot
# knot $short_name
#
# See also L<hubuse>.
# ------------------------------------------------------------------------------

sub knot {
  croak "Module not loaded: $_[0]" unless $KNOTMAP{$_[0]};
  return $KNOTMAP{$_[0]};
}#knot

#-------------------------------------------------------------------------------
# callback - Invocation method for persistent applications
# callback \&subroutine
# 
# Intended usage:
#
#   #!/usr/bin/perl -w
#   use strict;
#   use Hub qw(:standard);
#   while( my $req = ??? ) {
#       callback( &main, $req );
#   }
#   sub main {
#       my $req = shift;
#       # your code here
#   }
#
# The callback method wraps your code with the necessary initialization and
# destruction code required to isolate this instance (run) from others.
#-------------------------------------------------------------------------------

sub callback {
  my $instance_key = Hub::bestof($ENV{'WORKING_DIR'}, Hub::getpath($0));
  $instance_key .= '/' . Hub::getname($0);
  $Hub = getns($instance_key);
  unless (defined $Hub) {
    $Hub = mkinst('Registry');
    regns($instance_key, $Hub);
  }
  my $ret = $Hub->run( @_ );
  return $ret;
}#callback

# ------------------------------------------------------------------------------
# regns - Register namespace.
# regns $name, [\%value]
#
# I<Intended for Hub library modules only.>
# ------------------------------------------------------------------------------

sub regns {
  my $ns = shift or return;
  my $val = shift || {};
  $REGISTRY->{$ns} ||= $val;
  return $REGISTRY->{$ns};
}#regns

# ------------------------------------------------------------------------------
# getns - Get namespace
# getns $name, [$address]
# 
# I<Intended for Hub library modules only.>
# ------------------------------------------------------------------------------

sub getns {
  my $ns = shift or return;
  return hgetv($REGISTRY->{$ns}, @_) if @_;
  return $REGISTRY->{$ns};
}#getns

# ------------------------------------------------------------------------------
# trace - Warn with a stack trace
# trace @messages
# ------------------------------------------------------------------------------

sub trace {
  warn @_;
  for my $i (0 .. 8) {
    my @caller = caller($i);
    last unless @caller;
    last if $caller[2] == 0;
    print STDERR "[stack-$i] $caller[0] line $caller[2]\n";
  }
}#trace

# ------------------------------------------------------------------------------
# about - Return an about message regarding this library
# about
# ------------------------------------------------------------------------------

sub about {
return <<_end_print;
Hub Library Version $VERSION

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

* The origin of this software must not be misrepresented; you must not 
claim that you wrote the original software. If you use this software in a 
product, an acknowledgment in the product documentation would be 
appreciated but is not required.

* Altered source versions must be plainly marked as such, and must not be 
misrepresented as being the original software.

* The name of the author may not be used to endorse or promote products 
derived from this software without specific prior written permission.

Copyright (C) 2006-2007 by Livesite Networks, LLC. All rights reserved.

Copyright (C) 2000-2005 by Ryan Gies. All rights reserved.

_end_print
}#about

# ------------------------------------------------------------------------------
# version - Return the library version number
# version
# ------------------------------------------------------------------------------

sub version { return $VERSION; }#version

# ------------------------------------------------------------------------------
# END - Finish library wheel.
# ------------------------------------------------------------------------------

sub END {
    if( Hub::check( '-test=blessed', $Hub ) ) {
        $Hub->finish();
    }#if
}#END

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Hub Library Interface

=pod:synopsis

We pollute our symbol table with all of our internal libraries' EXPORT_OK symbols
so you don't have to.

    use Hub; # nothing imported
    print 'Why hello there, mister ', Hub::getname($0), "\n";

    use Hub ':standard';
    print 'Excuse me, mister ', getname($0), "\n";

In both cases, C<Hub::Data::File::getname(...)> is the called method.

=test(abort)   Hub::blahblahblah();

=cut
