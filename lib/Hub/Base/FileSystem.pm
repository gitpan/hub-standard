package Hub::Base::FileSystem;
use strict;
use IO::File;
use IO::Dir;
use IO::Handle;
use Fcntl qw/:flock/;
use File::Copy qw/copy/;
use Hub qw/:lib/;
our $VERSION = '4.00012';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
  SEPARATOR
  META_FILENAME
  $MODE_TO_MASK
  fileopen
  fileclose
  filetime
  find
  cpdir
  cpfile
  mvfile
  rmdirrec
  rmfile
  chperm
  mkdiras
  getcrown
  readdir
  sort_dir_list
  readfile
  writefile
  parsefile
  pushwp
  popwp
  srcpath
  fixpath
  getaddr
  getpath
  getspec
  getname
  getext
  abspath
  realpath
  relpath
  mkabsdir
/;

# Win32 modules are installed
eval("use Win32::FileSecurity");
our $HAS_WIN32 = $@ ? 0 : 1;

# Character to use as the file and directory separator
use constant SEPARATOR => '/';

# Filename for metadata
use constant META_FILENAME => '.metadata';

# ------------------------------------------------------------------------------
# $MODE_TO_MASK - Translations for Win32::FileSecurity::MakeMask
# ------------------------------------------------------------------------------

our $MODE_TO_MASK = {

  '7' => {
    'FILE'  => ["FULL"],
    'DIR'   => ["FULL", "GENERIC_ALL"],
  },

  '6' => {
    'FILE'  => ["CHANGE"],
    'DIR'   => ["ADD", "CHANGE", "GENERIC_WRITE", "GENERIC_READ", "GENERIC_EXECUTE"],
  },

  '5' => {
    'FILE'  => ["READ", "STANDARD_RIGHTS_EXECUTE"],
    'DIR'   => ["GENERIC_READ", "GENERIC_EXECUTE"],
  },

  '4' => {
    'FILE'  => ["READ"],
    'DIR'   => ["GENERIC_READ", "GENERIC_EXECUTE"],
  },

  '3' => {
    'FILE'  => ["STANDARD_RIGHTS_WRITE", "STANDARD_RIGHTS_EXECUTE"],
    'DIR'   => ["GENERIC_READ", "GENERIC_EXECUTE"],
  },

  '2' => {
    'FILE'  => ["STANDARD_RIGHTS_WRITE"],
    'DIR'   => ["GENERIC_READ", "GENERIC_EXECUTE"],
  },

  '1' => {
    'FILE'  => ["STANDARD_RIGHTS_EXECUTE"],
    'DIR'   => ["GENERIC_EXECUTE"],
  },

  '0' => {
    'FILE'  => [""],
    'DIR'   => [""],
  },

};

#-------------------------------------------------------------------------------
# fileopen FILENAME [PARAMS]
#
# For platforms which don't flock, create a lockfile for a specified
# filename.  Waits for #winlock_timeout seconds if a lockfile exists (unless
# READONLY is specified).
#-------------------------------------------------------------------------------

sub fileopen {
  my $filename = shift || return;
  my $readonly = $filename !~ /^>/;
  my $handle = IO::File->new($filename);
  croak "$!: $filename" unless defined $handle;
  my $flockopr = $readonly ? LOCK_SH : LOCK_EX;
  my $flocked = flock($handle,$flockopr);
  if( $@ or not $flocked ) {
    my $path = Hub::getpath( $filename );
    my $name = Hub::getname( $filename );
    my $lock_filename = "$path/.lock-$name";
    my $timeout = $$Hub{'/conf/timeout/lockfile'} || 1;
    $timeout *= 2; # because we only sleep for 1/2 second each loop
    for( 0 .. $timeout ) {
      last unless -e $lock_filename;
      last if $readonly;
      warn( "Waiting for lock on: $filename" );
      sleep .5;
    }#for
    if( open( LOCKFILE, ">$lock_filename" ) ) {
      print LOCKFILE "Lock file";
      close LOCKFILE;
    } else {
      die( "$!: $lock_filename" ) unless $readonly;
    }#if
  }#if
  return $handle;
}#fileopen

#-------------------------------------------------------------------------------
# fileclose HANDLE, [FILENAME]
#
# Unlock and close the file.
# Always remove the lockfile for a specified filename.
#-------------------------------------------------------------------------------

sub fileclose {
    my $handle = shift;
    my $filename = shift;
    if( defined $handle ) {
        flock($handle,LOCK_UN);
        close $handle;
    }#if
    if( $filename ) {
        my $path = Hub::getpath( $filename );
        my $name = Hub::getname( $filename );
        my $lock_filename = "$path/.lock-$name";
        unlink $lock_filename if -e $lock_filename;
    }#if
}#fileclose

# ------------------------------------------------------------------------------
# filetime - Return file's timestamp
#
# filetime LIST, [OPTIONS]
#
# Where:
#
#   LIST                A list of valid path names or file handles
#   OPTIONS -mtime      Return last-modified time (default)
#           -atime       last-accessed time
#           -ctime       creation time
#   OPTIONS -max        Return greatest value (default)
#           -min         least value
# ------------------------------------------------------------------------------

sub filetime {
  my $opts = Hub::opts( \@_, { mtime => 1, max => 1 } );
  my $result = -1;
  foreach my $file ( @_ ) {
    my $time = -1;
    my $fh = new IO::File;
    if($fh->open($file)) {
      my $stats = stat($fh);
      $$opts{'mtime'} and $time = $stats->mtime();
      $$opts{'atime'} and $time = $stats->mtime();
      $$opts{'ctime'} and $time = $stats->mtime();
      $fh->close();
    }#if
    $result = $$opts{'max'} ? Hub::max( $result, $time ) :
      Hub::min( $result, $time );
  }#foreach
  return $result;
}#filetime

# ------------------------------------------------------------------------------
# find - Find files on disk
# find $directory, [options]
#
# The directory entries '.' and '..' are always suppressed.
#
# No sorting is done here, entries appear in directory order with the directory 
# listing coming before its sub-directory's listings.
#
# Options:
#
#   -name         => \@list|$list   Filename patterns to include
#   -include      => \@list|$list   Path patterns to include
#   -exclude      => \@list|$list   Path patterns to ignore.
#   -ignore       => \@list|$list   Path patterns to ignore
#   -filesonly    => 0|1            Omit directory entries from the result
#   -dirsonly     => 0|1            Omit file entries from the result
#
# Examples:
#
#   # Return the whole mess
#   find('/var/www/html');
#
#   # Wild-card search
#   my @list = find('/var/www/html/*.css');
#
#   # Find by filename
#   my @list = find('/var/www/html', -name => '\.htaccess;\.htpasswd');
#
#   # Ignore these paths
#   my @list = find('/var/www/html', -ignore => ".bak;.swp");
#
#   # Ignore these paths AND do not recurse into them
#   my @list = find('/var/www/html', -exclude => "CVS;.svn");
#
#   # Just find these paths
#   # This would also match a directories named ".gif"!
#   my @list = find('/var/www/html', -include => ".gif;.jp?g;.png");
#
#   # Omit directory entries from the result
#   my @list = find('/var/www/html', -filesonly => 1);
#
#   # Omit file entries from the result
#   my @list = find('/var/www/html', -dirsonly => 1);
#
# The options:
#
#   -name
#   -include
#   -exclude
#   -ignore
#
# Can be provided as array references, meaning:
#
#   my @patterns = qw(1024x768.gif 800x600.jpe?g)
#   my @list = find('/var/www/html', -include => \@patterns);
#
# is equivelent to:
#
#   my @list = find('/var/www/html', -include => "1024x768.gif;800x600.jpe?g");
# ------------------------------------------------------------------------------

sub find {
  my $opts = Hub::opts(\@_, {
    'include'   => [],
    'ignore'    => [],
    'exclude'   => [],
    'name'      => [],
  });
  my $dir = shift || croak "Provide a directory";
  my $opt_hash = shift;
  for (qw/name exclude ignore include/) {
    defined $$opts{$_} && ref($$opts{$_}) ne 'ARRAY'
      and $$opts{$_} = [split /\s*;\s*/, $$opts{$_}];
  }
  # Options, for backwards compatablity, can also be provided in a single hash
  if( defined $opt_hash ) {
    if( ref($opt_hash) eq 'HASH' ) {
      Hub::merge($opts, $opt_hash);
    } else {
      croak "Unknown option: $opt_hash";
    }#if
  }#if

  # Global exludes
  push @{$$opts{'ignore'}}, split(/\s*;\s*/, $$Hub{'/sys/ENV/GLOBAL_IGNORE'})
    if defined $$Hub{'/sys/ENV/GLOBAL_IGNORE'};
  push @{$$opts{'exclude'}}, split(/\s*;\s*/, $$Hub{'/sys/ENV/GLOBAL_EXCLUDE'})
    if defined $$Hub{'/sys/ENV/GLOBAL_EXCLUDE'};

  # Single argument such as '/var/www/html/*.html'
  unless(-d $dir) {
    my $path = Hub::getpath($dir);
    if(-d $path) {
      my $name = Hub::getname($dir);
      $dir = $path;
      $opts->{'include'} = [ $name ];
      $opts->{'filesonly'} = 1;
    }#if
  }

  # Translate path patterns like (*.txt or *.*) into regex patterns
  foreach my $k (qw/include exclude ignore/) {
    map {
      $_ =~ s/^\*/.*/;
      $_ =~ s/(?<!\\)\.([\w\?]+)$/\\.$1\$/;
    } @{$opts->{$k}};
  }

  # Implementation
  $dir = Hub::fixpath($dir);
  my $found = _find($dir, $opts);
  return defined $found ? @$found : ();

}

sub _find {
  my ($dir, $opts) = @_;

  # Read directory
  my @all = ();
  my $d = IO::Dir->new($dir);
  die "$!: '$dir' in '" . cwd() . "'" unless defined $d;
  while (defined($_ = $d->read)) {
    push @all, $_ unless /^\.+$/;
  }
  undef $d;

  # Find matches
  my $list = ();
  my @subdirs = ();
  foreach my $name ( @all ) {
    my $i = "$dir/$name";
    my $ok = 1;

    # Entire path rule
    if (@{$opts->{'include'}}) {
      $ok = 0;
      for (@{$opts->{'include'}}) {
        if ($i =~ $_) {
          $ok = 1;
          last;
        }
      }
    }

    # Filename rule
    if (@{$opts->{'name'}}) {
      $ok = 0;
      for (@{$opts->{'name'}}) {
        if ($name =~ $_) {
          $ok = 1;
          last;
        }
      }
    }

    # Exclusion rules
    for (@{$opts->{'ignore'}}, @{$opts->{'exclude'}}) {
      if ($i =~ $_) {
        $ok = 0;
        last;
      }
    }

    # Looking for just files (or directories?)
    if( -d $i ) {
      $ok = 0 if $opts->{'filesonly'};
      # Regardless, shall we recurse?
      my $recurse = 1;
      for (@{$opts->{'exclude'}}) {
        if( $i =~ $_ ) {
          $recurse = 0;
          last;
        }
      }
      if( $recurse ) {
        push @subdirs, $i;
      }
    } else {
      $ok = 0 if $opts->{'dirsonly'};
    }

    # If it passed all the rules
    if( $ok ) {
        push @$list, $i;
    }
  }

  # Recurse into subdirectories
  foreach my $subdir ( @subdirs ) {
      my $found = _find($subdir, $opts);
      ref($found) eq 'ARRAY' and push @$list, @$found;
  }

  return $list;
}#find

# ------------------------------------------------------------------------------
# cpdir - Copy a directory
# cpdir $source_dir, $target_dir, [filters], [permissions], [options]
# 
# B<WARNING> this function does *not* behave like your shell's C<cp -r> command!
# It differs in that when the target directory exists, the *contents* of the
# source directory are copied.  This is done so that the default operation is:
#
#   # don't create /home/$username/newuser!
#   cpdir('templates/newuser', "/home/$username");
#
# To get the same behavior as C<cp -r>, use the '-as_subdir' flag.
#
# Files are only copied when the source file's modified time is newer
# (unless the 'force' option is set).
#
# C<filters>: See L<find>
#
# C<permissions>: See L<chperm|chperm>
#
# C<options>:
#
#   -force => 1               # Always perform the copy
#   -as_subdir => 1           # Copy as a sub-directory of $target
#   -peers => 1               # The $source and $target are peers (may be
#                               different names)
#
#   -peers and -as_subdir are mutually exclusive
#
# ------------------------------------------------------------------------------

sub cpdir {
  my ($opts, $source_dir, $target_dir, $perms) = Hub::opts(\@_);
  Hub::merge($opts, $perms) if isa($perms, 'HASH'); # backward compatibility
  my $target_parent = Hub::getpath($target_dir) || '.';
  croak "Provide an existing source: $source_dir" unless -d $source_dir;
  croak "Provide an existing target: $target_parent" unless -d $target_parent;
  if ($$opts{'as_subdir'}) {
    $target_dir .= SEPARATOR if $target_dir;
    $target_dir .= Hub::getname($source_dir);
    mkabsdir($target_dir, -opts => $opts);
  } elsif ($$opts{'peers'}) {
    mkabsdir($target_dir, -opts => $opts);
  }
  my @items = Hub::find($source_dir, -opts => $opts);
  foreach my $item (@items) {
    my $target = $item;
    $target =~ s/^$source_dir/$target_dir/;
    if( -d $item ) {
      if ((! -d $target) || $opts->{'force'}) {
        Hub::mkdiras($target, -opts => $opts);
      }
    } else {
      Hub::cpfile($item, $target, -opts => $opts);
    }
  }
  return @items ? $#items+1 : 0;
}#cpdir

# ------------------------------------------------------------------------------
# cpfile - Copy a file and apply permissions and mode
#
# cpfile $SOURCE, $TARGET, [\%PERMISSIONS], [OPTIONS]
#
# Where:
#
#   $SOURCE         File to be copied
#   $TARGET         Target path (file or directory)
#   \%PERMISSIONS   Permission hash (see Hub::chperm)
#   OPTIONS         -newer      Only copy when the source is newer (mtime) than 
#                               the target
#
# See also: L<chperm|chperm>
# ------------------------------------------------------------------------------

sub cpfile {
  my ($opts, $source, $dest, $perms) = Hub::opts(\@_);
  Hub::merge($opts, $perms) if isa($perms, 'HASH'); # backward compatibility
  my @result  = ();
  foreach my $file (-f $source
      ? $source
      : ref($source) eq 'HASH'
        ? Hub::find('.', $source)
        : Hub::find($source)) {
    return unless -f $file;
    my $target = $dest;
    if(-d $target) {
      my $fn = Hub::getname( $file );
      $target .= "/$fn";
    }
    my $copy = $$opts{'force'};
    if( !$copy ) {
      my $source_stats = stat( $file );
      my $target_stats = stat( $target );
      if( !$target_stats || $source_stats->mtime() > $target_stats->mtime() ) {
        $copy = 1;
      }
    }
    if( $copy ) {
      my $fpath = Hub::getpath( $target );
      Hub::mkabsdir($fpath, -opts => $opts);
      if( copy( $file, $target ) ) {
        Hub::chperm($target, -opts => $opts);
      } else {
        die( "$!: $target" );
      }
    }
    push @result, $target;
  }
  return Hub::sizeof(\@result) == 1
    ? shift @result
    : wantarray
      ? @result
      : \@result;
}#cpfile

# ------------------------------------------------------------------------------
# rmfile - Remove file
# ------------------------------------------------------------------------------

sub rmfile {
  unlink @_;
}#rmfile

# ------------------------------------------------------------------------------
# mvfile - Move (rename) a file
# ------------------------------------------------------------------------------

sub mvfile {
  my ($f1,$f2) = @_;
  rename $f1, $f2;
  Hub::touch($f2);
}#mvfile

# ------------------------------------------------------------------------------
# rmdirrec TARGET_DIR
# 
# Recursively remove a directory.
# ------------------------------------------------------------------------------

sub rmdirrec {
  my $dir = shift || die "Provide a directory";
  my $fh  = IO::Handle->new();
  $dir = Hub::abspath( $dir );
  return unless defined $dir && -d $dir;
  my @list = ();
  if( opendir $fh, $dir ) {
    my @subdirs = ();
    my @all = grep ! /^\.+$/, readdir $fh;
    closedir $fh;
    foreach my $name ( @all ) {
      my $i = "$dir/$name";
      if( -f $i ) {
        Hub::rmfile( $i );
      } elsif( -d $i ) {
        Hub::rmdirrec( $i );
      }#if
    }#foreach
    rmdir $dir;
  }#if
}#rmdirrec

# ------------------------------------------------------------------------------
# chperm - Change permissions of a file or directory
# chperm $path, [filters], [permissions], [options]
#
# options:
#
#   recperms=1        # will recurse if  is a directory
#
# filters: Used when recperms is set.  See L<find|find>.
#
# permissions:
#
#   uid     => Hub::getuid( "username" ),    # user id
#   gid     => Hub::getgid( "username" ),    # group id
#   dmode   => 0775,
#   fmode   => {            # fmode can ref a hash of extensions
#       '*'     => 0644,    # '*' is used for unmatched
#       'cgi'   => 0755,    # specific cgi file extension
#       'dll'   => 'SKIP',  # do not update dll files
#   }
#   fmode   => 0655,        # or, fmode can be used for all files
#
# ------------------------------------------------------------------------------

sub chperm {
  my ($opts,$path,$perms) = Hub::opts(\@_, {
    'recperms'  => 0,
    'fmode'     => 0644,
  });
  Hub::merge($opts, $perms) if isa($perms, 'HASH'); # backward compatibility
  my @items = $$opts{'recperms'} ? Hub::find($path, $opts) : $path;
  foreach my $target ( @items ) {
    if (-d $target) {
      my $mode = $$opts{'dmode'} || 0755;
       _chperm($$opts{'uid'}, $$opts{'gid'}, $mode, $target);
    } else {
      my $mode = undef;
      if (isa($$opts{'fmode'}, 'HASH')) {
        my $ext = Hub::getext($target);
        if( $$opts{'fmode'}->{$ext} ) {
          $mode = $$opts{'fmode'}->{$ext};
        } else {
          $mode = $$opts{'fmode'}->{'*'} if $$opts{'fmode'}->{'*'};
        }
      } else {
        $mode = $$opts{'fmode'};
      }
      $mode and
        _chperm($$opts{'uid'}, $$opts{'gid'}, $mode, $target);
    }
  }
}#chperm

# ------------------------------------------------------------------------------
# _chperm - Change permission proxy (splits between Win32 and normal routines)
# _chperm $user, $group, $mode, @targets
#
# C<$user> may be either the numeric uid, or the user name
#
# C<$group> may be either the numeric gid, or the group name
#
# C<$mode> may be either the octal value (such as 0755) or the string value 
# (such as '755')
#
# On win32, default permissions are taken from the configuration file (by 
# default, '.conf' in the current directory):
#
#   group = /conf/win32/group_name
#   owner = /conf/win32/owner_name
#   other = /conf/win32/other_name
#
# When not specified in the configuration, these values will be
#
#   group = Win32::LoginName
#   owner = the same as 'other'
#   other = Everyone
# ------------------------------------------------------------------------------

sub _chperm {
  my $owner   = shift;
  my $group   = shift;
  my $mode    = shift;
  foreach my $target ( @_ ) {
    if( $HAS_WIN32 && ($mode ne 'SKIP') ) {
      $target = Hub::abspath( $target );
      my $mode_str = sprintf( "%o", $mode );
      my $other = $$Hub{'/conf/win32/other_name'} || 'Everyone';
      $group ||= $$Hub{'/conf/win32/group_name'} || 'Win32::LoginName';
      $owner ||= $$Hub{'/conf/win32/owner_name'};
      unless($owner) { $owner = $other; $other = ""; }
      my $owner_flag = substr( $mode_str, 0, 1 );
      my $group_flag = substr( $mode_str, 1, 1 );
      my $other_flag = substr( $mode_str, 2, 1 );
      my $passed = 1;
      $owner and $passed &= _chperm_win32( $owner, $owner_flag, $target, 
        "WRITE_OWNER", "WRITE_DAC" );
      $group and $passed &= _chperm_win32( $group, $group_flag, $target );
      $other and $passed &= _chperm_win32( $other, $other_flag, $target );
      _chperm_normal($owner, $group, $mode, $target) unless $passed;
    } else {
      _chperm_normal($owner, $group, $mode, $target);
    }
  }
}

# ------------------------------------------------------------------------------
# _chperm_normal - Use chmod and chown to change permissions
# _chperm_normal $user, $group, $mode, $target
#
# See L<_chperm> for $user, $group, and $mode settings
# ------------------------------------------------------------------------------

sub _chperm_normal {
  my $owner   = shift;
  my $group   = shift;
  my $mode    = shift;
  my $target  = shift;
  # Change owner first
  if (defined $owner) {
    unless (chown Hub::getuid($owner), Hub::getgid($group), $target) {
      warn "$!: chown $owner:$group $target";
    }
  }
  # Convert string of octal digits
  $mode = length(sprintf('%o',$mode)) > 3 ? oct($mode) : $mode;
  if ($mode ne 'SKIP') {
    unless (chmod $mode, $target) {
      warn "$!: chmod $mode $target";
    }
  }
}#_chperm_normal

# ------------------------------------------------------------------------------
# _chperm_win32 - Change permissions on Win32
#
# On Win32, we still don't "really" change the owner (Anybody know how?)
# ------------------------------------------------------------------------------

sub _chperm_win32 {
  my $user    = shift;
  my $flag    = shift;
  my $target  = shift;
  my $index   = -d $target ? "DIR" : "FILE";
  my $mmargs  = $MODE_TO_MASK->{$flag}->{$index};
  my $retval  = 0;
  my @mmargs  = @_;
  push @mmargs, @$mmargs if ref($mmargs) eq 'ARRAY';
  if( @mmargs ) {
    $retval = 1;
    my $mask = Win32::FileSecurity::MakeMask( @mmargs );
    my $privHash = {};
    # If there isn't an ACL, we receive: Error handling error: 3, 
    # GetFileSecurity
    eval( "Win32::FileSecurity::Get( \$target, \$privHash )" );
    $@ and do { chomp $@; warn( "$target: $@" ); $retval = 0; };
    return $retval unless $retval;
    if( $flag ) {
      $privHash->{$user} = $mask;
    } else {
      delete $privHash->{$user};
    }#if
    eval( "Win32::FileSecurity::Set( \$target, \$privHash )" );
    $@ and do { chomp $@; warn( "$target: $@" ); $retval = 0; };
  }#if
  return $retval;
}#_chperm_win32

# ------------------------------------------------------------------------------
# mkdiras - Make a directy with specified permissions
# mkdiras $path, [permissions]
#
# permissions: See L<chperm>
# ------------------------------------------------------------------------------

sub mkdiras {
  my ($opts, $path, $perms) = Hub::opts(\@_);
  croak "Provide a path" unless defined $path;
  return if -d $path;
  if (mkdir $path) {
    Hub::chperm($path, $opts) if %$opts;
  } else {
    croak("$!: $path");
  }
}#mkdiras

# ------------------------------------------------------------------------------
# getcrown - Return the first line of a file
# getcrown $file_path
#
# Returns empty-string when $file_path does not exist
# ------------------------------------------------------------------------------

sub getcrown {
  my $filepath = shift or croak "Provide a file path";
  my $crown = '';
  if (open FILE, $filepath) {
    $crown = <FILE>;
    close FILE;
  }
  return $crown;
}#getcrown

# ------------------------------------------------------------------------------
# readdir - Read a directory in proper order
# readdir $dir
# ------------------------------------------------------------------------------

sub readdir {
  my $dir = shift;
  return () unless -d $dir;
  opendir (DIR, $dir) or die "$!: $dir";
  my @list = sort grep {!/^\.+/} readdir DIR;
  closedir DIR;
  # Sort entries
  Hub::sort_dir_list($dir, \@list);
# my $md_filename = $dir.SEPARATOR.META_FILENAME;
# if (-f $md_filename) {
#   my $md = Hub::mkinst('HashFile', $md_filename);
#   my $order = $$md{'sort_order'};
#   if (isa($order, 'ARRAY')) {
#     my $idx = 0;
#     my %sort_values = map {$_, $idx++} @$order;
#     @list = sort {
#       Hub::compare('<=>', $sort_values{$a}, $sort_values{$b})
#     } @list;
#   }
# }
  return @list;
}#readdir

# ------------------------------------------------------------------------------
# sort_dir_list - Sort the provided directory listing
# sort_dir_list $dir, \@listing
# ------------------------------------------------------------------------------

sub sort_dir_list {
  my ($opts, $dir, $list) = Hub::opts(\@_);
  my $md_filename = $dir.SEPARATOR.META_FILENAME;
  if (-f $md_filename) {
    Hub::frefresh($md_filename);
    my $md = Hub::mkinst('HashFile', $md_filename);
    # Sort entries
    my $order = $$md{'sort_order'};
    if (isa($order, 'ARRAY')) {
      my $idx = 0;
      my %sort_values = map {$_, $idx++} @$order;
      @$list = sort {
        Hub::sort_compare('<=>', $sort_values{$a}, $sort_values{$b})
      } @$list;
    }
  }
}#sort_dir_list

# ------------------------------------------------------------------------------
# readfile PATH
# 
# Read and return the contents of a file.
# ------------------------------------------------------------------------------

sub readfile {
  my $path = shift || return;
  my $opts = Hub::opts(\@_) if @_;
  local $_;
  my @contents = ();
  my $fh = Hub::fileopen($path);
  if( $fh ) {
    @contents = <$fh>;
    Hub::fileclose($fh, $path);
  }#if
  defined $$opts{'asa'} and return @contents;
  my $contents = '';
  map { $contents .= $_ } @contents;
  return $contents;
}#readfile

# ------------------------------------------------------------------------------
# writefile - Write $contents to $path
# writefile $path, \$contents, [options]
# writefile $path, $contents, [options]
#
# options:
#
#   -mode   => 0644     Set/update file's mode
#   -flags  => >|>>     Flags used to open the file
#
# Returns 1 if the file could be openned and written to, otherwise 0.
# ------------------------------------------------------------------------------

sub writefile {
  my ($opts,$filepath,$contents) = Hub::opts(\@_, {'flags' => '>'});
  croak "Provide a file" unless $filepath;
  croak "Provide file contents" unless defined $contents;
  my $perms = ();
  my $ret = 0;
  my $fh = Hub::fileopen("$$opts{'flags'}$filepath");
  if( $fh ) {
    print $fh ref($contents) eq 'SCALAR' ? $$contents : $contents;
    Hub::fileclose($fh, $filepath);
    if( defined($$opts{'perms'}) ) {
      Hub::chperm($filepath, $$opts{'perms'});
    }
    $ret = 1;
  }
  return $ret;
}

# ------------------------------------------------------------------------------
# parsefile - Populate a file with runtime data.
# parsefile $filename, [options]
# parsefile $filename, \%data, [\%more_data..], [options]
#
# parameters:
#
#   $filename   File to parse as a template.
#   \%data      Hashref of name/value pairs.
#
# options:
#
#   -as_ref=1   Return a scalar reference
#   -alone      Do not include configuration and instance values
#   -inline     Update the file on disk!
# ------------------------------------------------------------------------------

sub parsefile {
  my ($opts) = Hub::opts(\@_, {'as_ref' => 0});
  my $file = shift;
  my @values = @_ ? ( @_ ) : ();
  push @values, $$Hub{+SEPARATOR} unless $$opts{'alone'};
  my $contents = Hub::readfile( $file );
  my $parser = Hub::mkinst( 'StandardParser', -template => \$contents,
    -opts => $opts );
  my $results = $parser->populate( @values );
  Hub::expect( SCALAR => $results );
  $$opts{'inline'} and Hub::writefile( $file, $results );
  return $$opts{'as_ref'} ? $results : $$results;
}#parsefile

# ------------------------------------------------------------------------------
# pushwp - Push path onto working directory stack
# ------------------------------------------------------------------------------

sub pushwp {
  $$Hub{'/sys/PATH'} ||= [];
  push @{$$Hub{'/sys/PATH'}}, @_;
}#pushwp

# ------------------------------------------------------------------------------
# popwp - Pop path from working directory stack
# ------------------------------------------------------------------------------

sub popwp {
  return pop @{$$Hub{'/sys/PATH'}};
}#popwp

# ------------------------------------------------------------------------------
# srcpath - Search the working path for $file
# srcpath $file
# ------------------------------------------------------------------------------

sub srcpath {
  my $unknown = shift || return;
  -e $unknown and return $unknown;
  for (
    @{$$Hub{'/sys/PATH'}},
    $$Hub{'/sys/ENV/WORKING_DIR'}
  ) {
    next unless defined && $_;
    my $spec = Hub::fixpath( "$_/$unknown" );
    if(-e $spec) {
      return $spec;
    }
  }
}#srcpath

#-------------------------------------------------------------------------------
# fixpath - Clean up malformed paths (usually due to concatenation logic).
# fixpath $path
#-------------------------------------------------------------------------------
#|test(match)   fixpath( "../../../users/newuser/web/bin/../src/screens" );
#~              ../../../users/newuser/web/src/screens
#~
#|test(match)   fixpath( "users/newuser/web/" );
#~              users/newuser/web
#~
#|test(match)   fixpath( "users/../web/bin/../src" );
#~              web/src
#~
#|test(match)   fixpath( "users//newuser" );
#~              users/newuser
#~
#|test(match)   fixpath( "users//newuser/./files" );
#~              users/newuser/files
#~
#|test(match)   fixpath( "http://site/users//newuser" );
#~              http://site/users/newuser
#|test(match)   fixpath( '/home/hub/build/../../../out/doc/pod' );
#~              /out/doc/pod
#-------------------------------------------------------------------------------

sub fixpath {
  my $path = shift || return;
  # correct solidus
  $path =~ s/\\/\//g;
  # remove empty dirs, ie: // (unless it looks like protocol '://')
  $path =~ s/(?<!:)\/+/\//g;
  # remove pointless dirs, ie: /./
  $path =~ s/\/\.\//\//g;
  # condense relative subdirs
  while( $path =~ s/[^\/\.]+\/\.\.\/?//g ) {
    # remove empty dirs (again)
    $path =~ s/(?<!:)\/+/\//g;
  }#while
  # remove trailing /
  $path =~ s/\/\z//;
  return $path;
}#fixpath

# ------------------------------------------------------------------------------
# getaddr - Get the Hub address for a file
# getaddr $filename
#
# C<$filename> may be relative to the running module (see L<Hub::modexec>)
#
# For the inverse, see L<Hub::realpath>
# ------------------------------------------------------------------------------

sub getaddr {
  my $path = Hub::srcpath(@_) || $_[0];
  return unless defined $path;
  $path =~ s#^$$Hub{'/sys/ENV/WORKING_DIR'}##;
  return $path;
}#getaddr

# ------------------------------------------------------------------------------
# getpath - Exract the parent from the given filepath
# ------------------------------------------------------------------------------
#|test(match,/etc)        getpath( "/etc/passwd" )
#|test(match,/usr/local)  getpath( "/usr/local/bin" )
# ------------------------------------------------------------------------------

sub getpath {
  my $orig = Hub::fixpath( shift ) || '';
  my ($path) = $orig =~ /(.*)\//;
  return $path || '';
}#sub

# ------------------------------------------------------------------------------
# getspec - Given a path to a file, return (directory, filename, extension)
# getspec $path
# ------------------------------------------------------------------------------

sub getspec {
  my $path = shift;
  my $name  = Hub::getname( $path )  || "";
  my $ext   = Hub::getext( $path )   || "";
  my $dir   = Hub::getpath( $path )  || "";
  $name =~ s/\.$ext$//; # return the name w/o extension
  return ($dir,$name,$ext);
}#getspec

#-------------------------------------------------------------------------------
# getname Return the file name (last element) of given path
# getname $path
# Note, if the given path is a full directory path, the last directory is
# still considerred a filename.
#-------------------------------------------------------------------------------
#|test(match) getname("../../../users/newuser/web/data/p001/batman-small.jpg");
#=batman-small.jpg
#|test(match) getname("../../../users/newuser/web/data/p001");
#=p001
#|test(match) getname("/var/log/*.log");
#=*.log
#-------------------------------------------------------------------------------

sub getname {
  return unless defined $_[0];
  return pop @{[split(SEPARATOR, $_[0])]};
}

# ------------------------------------------------------------------------------
# getext - Return the file extension at the given path
# getext $path
# ------------------------------------------------------------------------------
#|test(match) getext( "/foo/bar/filename.ext" )
#=ext
#|test(match) getext( "filename.cgi" )
#=cgi
# ------------------------------------------------------------------------------

sub getext {
  my $orig = shift;
  my $fn = getname($orig) || '';
  my $tmp = reverse($fn);
  $tmp =~ s/\..*//;
  my $ret = reverse $tmp;
  return $ret eq $fn ? '' : $ret;
}#getext

# ------------------------------------------------------------------------------
# realpath - Resolve the address to it's real file on disk.
# realpath $address
# 
# Used to translate our Hub system addresses into real filesystem paths.
# When /foo/bar.txt is really cwd().'/foo/bar.txt', we strip the beginning /.
# When using mounts, return the file's real path.
#
# For the inverse, see L<Hub::getaddr>
# ------------------------------------------------------------------------------

sub realpath {
  my $real_path = shift;
  $real_path =~ s/^\///;
  # TODO implement mounts
  return $real_path ? $real_path : '.';
}#realpath

#-------------------------------------------------------------------------------
# abspath - Return the absolute path
# abspath $node, [options]
# options:
#   -must_exist=0   Allow paths which don't exist
#-------------------------------------------------------------------------------

sub abspath {
  my $path = shift; # important to shift (filenames can start with a dash)
  my ($opts) = Hub::opts(\@_, {must_exist => 0,});
  my $result = _find_abspath($path);
  die "$!: $result" if $$opts{'must_exist'} && ! -e $result;
  return $result;
}#abspath

# ------------------------------------------------------------------------------
# _find_abspath - Get the absolute path (may or may not exist)
# _find_abspath $node
# ------------------------------------------------------------------------------

sub _find_abspath {
  my $relative_path = shift || return;
# $relative_path =~ s/\\/\//g;
  return $relative_path if $relative_path =~ /^\/|^[A-Za-z]:\//;
  my $base_dir = Hub::bestof($$Hub{'/sys/ENV/WORKING_DIR'},Hub::getpath($0));
  $base_dir = cwd() unless $base_dir =~ /^\/|^[A-Za-z]:\//;
# $base_dir =~ s/\\/\//g;
  return fixpath("$base_dir/$relative_path");
}#_find_abspath

# ------------------------------------------------------------------------------
# relpath - Relative path
# relpath $path, $from_dir
# ------------------------------------------------------------------------------
#|test(match,..)    relpath("/home/docs", "/home/docs/install");
#|test(match)       relpath("/home/src", "/home/docs/install");
#~                  ../../src
#|test(match)       relpath("/home/docs/README.txt", "/home/docs");
#~                  README.txt
#|test(match)       relpath("README.txt", "/DEBUG");
#~                  README.txt
# ------------------------------------------------------------------------------

sub relpath {
  my $path = Hub::fixpath(shift) || '';
  my $from = Hub::fixpath(shift) || '';
  return $path unless $path =~ SEPARATOR;
  my @from_parts = split SEPARATOR, $from;
  my @path_parts = split SEPARATOR, $path;
  my @relpath = ();
  my $begin_idx = 0;
  for (my $idx = 0; $idx < @from_parts; $idx++) {
    last unless defined $path_parts[$idx];
    last if $from_parts[$idx] ne $path_parts[$idx];
    $begin_idx++;
  }
  for (my $idx = $begin_idx; $idx < @from_parts; $idx++) {
    push @relpath, '..';
  }
  for (my $idx = $begin_idx; $idx < @path_parts; $idx++) {
    push @relpath, $path_parts[$idx];
  }
  return join SEPARATOR, grep {$_} @relpath;
}#relpath

# ------------------------------------------------------------------------------
# mkabsdir - Create the directory specified, including parent directories.
# mkabsdir $dir, [permissions]
# See L<hubperms>
# ------------------------------------------------------------------------------

sub mkabsdir {
  my ($opts, $dir) = Hub::opts(\@_);
  my $abs_path = _find_abspath($dir);
  return unless $abs_path;
  return $abs_path if -e $abs_path;
  my $build_path = '';
  foreach my $part ( split SEPARATOR, $abs_path ) {
    $build_path .= "$part/";
    -d $build_path and next;
    Hub::mkdiras($build_path, -opts => $opts);
  }
  return $abs_path;
}#makeAbsoluteDir

# ------------------------------------------------------------------------------
1;

__END__

=pod:summary Utility methods for working with the file system

=pod:synopsis

  use Hub qw(:standard);

=pod:description

=head2 Intention

=cut
