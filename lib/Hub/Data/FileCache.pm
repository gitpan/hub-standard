package Hub::Data::FileCache;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/fattach fhandler finstance frefresh fread/;
our $NAMESPACE = Hub::regns('filecache');
our $COUNT = 0;

# ------------------------------------------------------------------------------
# fattach - Attach an instance of a class to a file.
# fattach $filename, $class
#
# C<$class> must implement the method C<reload>
#
# Returns a hash of:
#
#   lastread    # mod time last time we read it
#   filename    # name
#   lines       # ARRAY of lines in the file
#   handlers    # HASH of attached classes
#
# The instance is a singleton.
# ------------------------------------------------------------------------------

sub fattach {
    my $param_filename = shift or croak "Provide a filename";
    my $handler = shift;
    croak "Provide a reloadable object" unless can($handler, 'reload');
    my $filename = Hub::abspath($param_filename);
    my $instance = $$NAMESPACE{$filename};
    if( defined $instance ) {
      if( $instance->{'handlers'}{$handler} ) {
        croak "Already attached";
      } else {
        $instance->{'handlers'}{$handler} = $handler;
        if ($$instance{'lastread'}) {
          $handler->reload( $instance );
        } else {
          Hub::fread($instance);
        }
      }#if
    } else {
      $instance = {
        'filename'  => $filename,
        'lastread'  => 0,
        'handlers'  => { $handler => $handler, },
      };
      $$NAMESPACE{$filename} = $instance;
      Hub::fread($instance);
    }#unless
    return $instance;
}#fattach

# ------------------------------------------------------------------------------
# fhandler - Get the file handler for a given file
# fhandler $filename, $classname
# fhandler $filename
# In its first form, we will return the handler for the given class name.
# In its second form, we will return all handlers for the given file.
# ------------------------------------------------------------------------------

sub fhandler {
  my $filename = shift or croak "Provide a filename";
  my $classname = shift;
  my @handlers = ();
  my $filepath = Hub::abspath($filename);
  return unless $filepath;
  my $instance = $$NAMESPACE{$filepath};
  if( defined $instance ) {
    if (defined $classname) {
      map { push @handlers, $_ if ref($_) eq $classname }
        values %{$instance->{'handlers'}};
    } else {
      @handlers = values %{$instance->{'handlers'}};
    }
  }
  wantarray and return @handlers;
  return pop @handlers;
}

# ------------------------------------------------------------------------------
# finstance - Get the cache instance for a specific file
# finstance - $filename
# ------------------------------------------------------------------------------

sub finstance {
  my $filename = shift or croak "Provide a filename";
  my $path = Hub::abspath($filename);
  return defined $path ? $$NAMESPACE{$path} : undef;
}

# ------------------------------------------------------------------------------
# frefresh - Signal handlers to reparse
# frefresh [$filename], [options]
#
# options:
#
#   -force=>1         Force re-reading all
#   -force_dirs=>1    Force re-reading of directories
#
# Without a $filename, B<all> file instances are checked for disk modifications.
# If the file has been modified, re-read the file and tell all your handlers to 
# reparse themselves via the C<reload> method.
#
# With a $filename, only handlers for the specific filename are signaled to 
# reparse.
# ------------------------------------------------------------------------------

sub frefresh {
  my ($opts, $fn) = Hub::opts(\@_);
  my $filepath = defined $fn ? Hub::abspath($fn) : undef;
  my @instances = defined $fn
    ? grep { $_->{'filename'} eq $filepath } values %$NAMESPACE
    : values %$NAMESPACE;
  foreach my $instance (@instances) {
    my $stats = defined $instance->{'filename'}
      ? stat $instance->{'filename'}
      : undef;
    if (defined $stats) {
#warn "Refresh ", $instance->{'filename'}, "? ", $stats->mtime(), " -vs- ", $instance->{'lastread'}, "\n";
    }
    if (!defined $stats || ($stats->mtime() == 0)) {
      # file no longer exists
      delete $$Hub{Hub::getaddr($instance->{'filename'})};
      delete $NAMESPACE->{$instance->{'filename'}};
      next;
    }
    if (($$opts{'force'} || ($stats->mtime() > $instance->{'lastread'}))
        || ($$opts{'force_dirs'} && -d $instance->{'filename'})) {
#warn " Read \n";
      Hub::fread($instance);
    } elsif (-d $instance->{'filename'}) {
      my $md_filename = $instance->{'filename'}
          . Hub::SEPARATOR . Hub::META_FILENAME;
      if (-e $md_filename) {
        my $md_stats = stat $md_filename;
        if ($md_stats->mtime() > $instance->{'lastread'}) {
#warn " -fread b/c of meta\n";
          Hub::fread($instance);
#warn " -done fread\n";
        }
      }
    }
  }
}

# ------------------------------------------------------------------------------
# fread - Modify the provided instance to reflect what is on disk.
# fread $instance
#
# C<$instance> must be the special hash returned by L<finstance>
# If all handling classes implement the C<delay_reading> function, and they all
# return a true value, we will not read file.
# ------------------------------------------------------------------------------

sub fread {
  my $instance = shift;
  my $filename = $instance->{'filename'};
  # Do not continue if all handlers want to delay reading
  my $delay_reading = 1;
  map { 
    $delay_reading &= UNIVERSAL::can($_, 'delay_reading') ?
      $_->delay_reading($instance) : 0;
  } values %{$instance->{'handlers'}};
  return if $delay_reading;
  # Read file from disk
  my $stats = stat $filename;
  if (defined $stats) {
#warn " -reading: $filename\n";
    $instance->{'lastread'} = $stats->mtime();
#   $instance->{'lastread'} = time;
    if (-f $filename) {
      my @contents = Hub::readfile($filename, '-asa=1');
      $instance->{'lines'}    = [ @contents ];
      $instance->{'contents'} = '';
      map { $instance->{'contents'} .= $_ } @contents;
    } elsif (-d $filename) {
      if (opendir (DIR, $filename)) {
        $instance->{'contents'} = [grep {!/^\.+$/} readdir DIR];
        closedir DIR;
      } else {
        warn "$!: $filename (deleting from cache)";
        delete $$NAMESPACE{$filename};
      }
    }
    # Signal all handlers to re-parse
    for (values %{$instance->{'handlers'}}) {
#warn "reload: $$instance{'filename'}: $_\n";
      $_->reload($instance) if $_;
    }
  }
}#fread

# ------------------------------------------------------------------------------
1;
