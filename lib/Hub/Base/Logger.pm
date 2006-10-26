package Hub::Base::Logger;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

our $VERSION        = '3.01048';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw//;

sub new;

use Hub             qw/:lib/;

our $NAMESPACE      = Hub::regns( 'logfiles' );

# ------------------------------------------------------------------------------
# Display constants

use constant SEPARATOR_CHAR => '-';
use constant WIDTH_SEVERITY => 1;
use constant WIDTH_DATETIME => 14;
use constant WIDTH_MSGTYPE  => 5;
use constant WIDTH_CTXINFO  => WIDTH_SEVERITY + WIDTH_DATETIME + WIDTH_MSGTYPE + 1;

our %TEE_FORMATS = (
        'none'      => 0,
        'html'      => 1,
        'stdout'    => 2,
        'stderr'    => 3,
        );

#!BulkSplit

# ------------------------------------------------------------------------------
# 'all' will display all messages.  Otherwise, specify the message level
# (see 'msg' below.)

sub show {

    my $self = shift;
    my $class = ref( $self ) || die "$self is not an object";

    if( @_ ) {

        $self->{'oppressed'} = 0;

        push @{$self->{'show'}}, @_;

    }#if

}#show

# ------------------------------------------------------------------------------
# Toggle output options

sub set {

    my $self = shift;
    my $class = ref( $self ) || die "$self is not an object";

    my $option = shift;
    my $value = shift;

    return unless $option;

    $self->{$option} = $value;

}#set

# ------------------------------------------------------------------------------
# No logging

sub disable {

    my $self = shift;
    my $class = ref( $self ) || die "$self is not an object";

    $self->{'oppressed'} = 1;

}#disable

# ------------------------------------------------------------------------------
# Append messages to stdout (0=no, 1=html, 2=raw)

sub tee {

    my $self = shift;
    my $class = ref( $self ) || die "$self is not an object";

    my $value = 2;

    @_ and $value = shift;

    $self->{'tee'} = $value;

}#tee

# ------------------------------------------------------------------------------
# Log a message at a specific level

sub msg {

    my $self = shift;
    my $class = ref( $self ) || die "$self is not an object";

    $self->{'oppressed'} and return;

    my ($msg,$msgtype) = @_;

    if( !$msgtype || (grep /^all$/, @{$self->{'show'}}) ||
            (grep /^$msgtype$/, ('----', 'err', @{$self->{'show'}})) ) {

        &logRaw( $self, "", $msg, $msgtype );

    }#if

}#msg

# ------------------------------------------------------------------------------
# write directly to standard out
sub out {

    my $self = shift;
    my $class = ref( $self ) || die "$self is not an object";

    my ($msg,$level) = @_;

    my $displayDate = Hub::datetime(gettimeofday, 'noyear');

    printf "%s%s %s %s\n",  Hub::fw(  WIDTH_SEVERITY, " " ),
           Hub::fw( WIDTH_DATETIME, $displayDate ),
           Hub::fw( WIDTH_MSGTYPE, $level ),
           $msg;

}#out

# ------------------------------------------------------------------------------
sub err {

    my $self = shift;
    my $class = ref( $self ) || die "$self is not an object";

    my $msg = shift;

    my $msgtype = shift || "err";

    logRaw( $self, "!", $msg, $msgtype );

}#err

# ------------------------------------------------------------------------------
# dump [MESSAGE], ?REF, [LEVEL]
#
# Where:
#
#   MESSAGE     An optional message to prefix the output
#   ?REF        A reference to the value which will be dumped
#   LEVEL       The level passed as a flag, -verb for example.
# 
# Dump hash|array values.  ?REF? may not be a HASH or ARRAY reference, since 
# this method is used to inspect variables.  In that case, it will treated like 
# a scalar.
# ------------------------------------------------------------------------------

sub dump {

    my $self = shift;

    my $opts = Hub::opts( \@_ );

    my $class = ref( $self ) || die "$self is not an object";

    my $n = 0;

    my $out = '';

    while( my $arg = shift @_ ) {

        $arg = 'undef'  unless defined $arg;

        $arg = Hub::hffmt( $arg ) if ref( $arg );

        $arg .= "\n" if $arg !~ /\n$/;

        $arg = Hub::indenttext( WIDTH_CTXINFO + 1, $arg ) if $n;

        $out .= $arg;

        $n++;

    }#while

    my $level = $$opts{'level'} || '';

    chomp $out;

    $self->msg( $out, $level );

}#dump

# ------------------------------------------------------------------------------
# morte
# 
# Log the message as an error, flush the log file, and die with the message.
# ------------------------------------------------------------------------------

sub morte {

    my $self = shift;
    my $class = ref( $self ) || die "$self is not an object";

    $self->err( @_ );

    $self->flush();

    die @_;

}#morte

# ------------------------------------------------------------------------------
sub measurefrom {

    my $self    = shift;
    my $class   = ref( $self ) || die "$self is not an object";
    my $alias   = shift || return;

    return unless( grep /meas/, @{$self->{'show'}} );

    my $tstamp  = [gettimeofday];
    my $elapsed = 0;

    $self->{'measures'}->{$alias} ||= {};

    my $m = $self->{'measures'}->{$alias};

    push @{$m->{'from'}}, $tstamp;

}#measurefrom

# ------------------------------------------------------------------------------
sub measureto {

    my $self    = shift;
    my $class   = ref( $self ) || die "$self is not an object";
    my $alias   = shift || return;

    return unless( grep /meas/, @{$self->{'show'}} );

    my $tstamp  = [gettimeofday];
    my $elapsed = 0;

    my $m = $self->{'measures'}->{$alias};

    return unless $m;

    my $from = pop @{$m->{'from'}};

    $elapsed = tv_interval( $from, $tstamp ) if defined $from;

    $m->{'total'} += $elapsed;
    $m->{'count'}++;

}#measureto

# ------------------------------------------------------------------------------

sub logRaw {

    my $self = shift;
    my $class = ref( $self ) || die "$self is not an object";
    my ($severity, $message, $msgtype) = @_;

    my $call_stack = [];
    my $filemark = {};

    if( $self->{'show_stack'} ) {

        my $i = 0;

        # Tracing this package is clutter, so we strip it.  So, if there
        # is another package named "Logger" they will be stripped too.

        while( my @caller_info = caller( $i++ ) ) {

            push @$call_stack, \@caller_info unless
                $caller_info[0] =~ /::Logger$/;

        }#while

    } elsif( $self->{'show_source'} ) {

        my @call_info = caller( 1 );

        $call_info[1] =~ /Logger/ and @call_info = caller( 2 );

        $filemark = {
            filepath    => $call_info[1],
            filename    => Hub::getname($call_info[1]),
            line        => $call_info[2],
        };

    }#if

    push @{$self->{'messageList'}}, {   severity    => $severity,
        tstamp      => [gettimeofday],
        message     => $message,
        msgtype     => $msgtype,
        call_stack  => $call_stack,
        filemark    => $filemark,
    };

}#logRaw

#-------------------------------------------------------------------------------
# keep the logfile below a certian size

sub trim_file {

    my $self = shift;
    my $type = ref($self) || die "$self is not an object!";

    return unless $self->{'max_size'} > 0;

    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
            $atime,$mtime,$ctime,$blksize,$blocks)
        = stat($self->{'filename'});

    if( defined $size && ($size > $self->{'max_size'}) ) {

        rename $self->{'filename'}, $self->{'filename'} . ".bak";

    }#if

    return 0;

}#

# ------------------------------------------------------------------------------
# flush
# flush -tstamp => TIMESTAMP
# flush -tee    => none|html|stdout|stderr
# 
# Write log messages to disk.
#
# Optionally tee these messages (to stdout or stderr or stdout wrapped with 
# HTML comments).
#
# TIMESTAMP as from Time::HiRes::gettimeofday.
# ------------------------------------------------------------------------------

sub flush {

    my $self = shift;

    Hub::expect( -blessed => $self );

    my $opts = Hub::opts( \@_ );

    my $tee = shift || $$opts{'tee'} || $self->{'tee'};

    my $tstamp = $$opts{'tstamp'} || $self->{'tstamp'};

    $tee = $tee && defined $TEE_FORMATS{$tee} ? $TEE_FORMATS{$tee} : $tee;

    $self->{'oppressed'} and return;

    $self->{'haveflushed'} and return unless @{$self->{'messageList'}};

    my $sep_msgwidth = 79 - WIDTH_CTXINFO;

    my $sep_msg =
        Hub::fw( $sep_msgwidth, Hub::abspath($0).' ', -clip => 0,
                'padding:'. SEPARATOR_CHAR, 'right' );

    my $sep_mtchar = SEPARATOR_CHAR;

    unshift @{$self->{'messageList'}}, {
        severity    => "#",
        tstamp      => $tstamp,
        message     => $sep_msg,
        msgtype     => Hub::fw(WIDTH_MSGTYPE, tv_interval($tstamp)),
        filemark    => {},
        call_stack  => [],
    };

    my $preDate         = ();
    my $displayDate     = ();
    my $first_tstamp    = ();
    my $prev_tstamp     = ();
    my $logLine         = ();
    my $cumTime         = ();

    my $out = *STDOUT;

    if( $tee !~ /^\d+$/ ) {

        $self->err( "Unknown tee format '$tee' use: "
            . join( '|', keys %TEE_FORMATS ) );

        $tee = 0;

    }#if

    $tee == 1 and print $out "<!--\n\n";    # HTML output
    $tee == 2 and print $out "\n";          # console output
    $tee == 3 and $out = *STDERR;           # console output to STDERR

    my $open_flag = $self->trim_file() ? ">" : ">>";

    my $canWriteToLogfile = 0;

    if( open LOGFILE, $open_flag . $self->{'filename'} ) {

        $canWriteToLogfile = 1;

    } else {

        my $ts = localtime(time);

        warn "[$ts] [Logger] $!: $self->{'filename'}\n";

    }#if

    foreach my $hash ( @{$self->{'messageList'}} ) {

        if( $prev_tstamp ) {

            my $interval = tv_interval( $prev_tstamp, $$hash{'tstamp'} );

            $cumTime += $interval;
            
            $displayDate = sprintf( "%.3f %f", $cumTime, $interval );

        } else {

            my $sec = $$hash{'tstamp'}[0];

            $displayDate = Hub::datetime($sec, 'noyear');

            $first_tstamp = $$hash{'tstamp'} unless defined $first_tstamp;

        }#if

        $$hash{'message'} =~ s/%/\%\%/g;

        if( ($self->{'show_source'}) && ($$hash{'filemark'}->{'filename'}) ) {

            $logLine = sprintf "%s%s %s %s (%s:%s)\n",
                Hub::fw( WIDTH_SEVERITY, $$hash{'severity'} ),
                Hub::fw( WIDTH_DATETIME, $displayDate ),
                Hub::fw( WIDTH_MSGTYPE, $$hash{'msgtype'} ),
                $$hash{'message'},
                $$hash{'filemark'}->{'filename'},
                $$hash{'filemark'}->{'line'},
                ;

        } else {

            $logLine = sprintf "%s%s %s %s\n",
                Hub::fw( WIDTH_SEVERITY, $$hash{'severity'} ),
                Hub::fw( WIDTH_DATETIME, $displayDate ),
                Hub::fw( WIDTH_MSGTYPE, $$hash{'msgtype'} ),
                $$hash{'message'},
                ;

        }#if

        my $call_stack = $$hash{'call_stack'};

        my $stack_size =
            $self->{'show_stack'} =~ /^\d+$/ ? ($self->{'show_stack'} - 1) : 0;

        foreach my $stack_frame ( 0 .. $stack_size ) {

            my $frame = shift @$call_stack;

            last unless defined $frame;

            my ($pack, $file, $line, $subname, $hasargs, $wantarray) = @$frame;

            my $frame_info = sprintf( "%s %s %s\n", $pack, $file, $line );

            $logLine .= Hub::fw( WIDTH_CTXINFO,
                "[$stack_frame]", "right" ) . " $frame_info";

        }#foreach

        printf LOGFILE $logLine if $canWriteToLogfile;

        $tee and print $out "$logLine";

        $prev_tstamp = $$hash{'tstamp'};

    }#foreach
    
    $self->{'messageList'} = [];

    #
    # Measurements
    #

    foreach my $meas ( reverse Hub::asarray( $self->{'measures'}, "total" ) ) {

        my $alias = $meas->{'_id'};
        my $totaltime = $meas->{'total'};
        my $count = $meas->{'count'};
        my $average = $count ? sprintf( "%.6f", $totaltime/$count ) : "0.0";
        my $timespent = sprintf( "%.6f", $totaltime );

        $logLine = sprintf "%s%s %s %s %s %s %s\n",
            Hub::fw( WIDTH_SEVERITY, "" ),
            Hub::fw( WIDTH_DATETIME, "" ),
            Hub::fw( WIDTH_MSGTYPE, "meas" ),
            Hub::fw( 10, $timespent ),
            Hub::fw(  6, $count ),
            Hub::fw( 10, $average ),
            $alias,
            ;

        printf LOGFILE $logLine if $canWriteToLogfile;

        $tee and print $out "$logLine";

    }#foreach

    $self->{'measures'} = {};

    close LOGFILE if $canWriteToLogfile;

    Hub::chperm( $self->{'filename'}, { fmode => 0660 } ) if $canWriteToLogfile;

    $tee == 1 and print $out "\n-->\n";

    $self->{'haveflushed'} = 1;

}#flush

#-------------------------------------------------------------------------------

sub new {

    my $self = shift;
    my $filename = shift || '.logfile';
    my $classname = ref( $self ) || $self;

    $filename = Hub::abspath( $filename, '-nocheck=1' ),

    my $object = $$NAMESPACE{$filename};

    if( $object ) {

        $object->refresh();

    } else {

        $self = {
            filename    => $filename,
            oppressed   => 1,
            tee         => 0,
            show_stack  => 0,
            show_source => 0,
            show        => [],
            max_size    => 5000,
            tstamp      => '',
            messageList => [],
            measures    => {},
            haveflushed => 0,
        };

        $self->{'tstamp'} = [gettimeofday];

        $object = bless $self, $classname;

        $$NAMESPACE{$filename} = $object;

    }#if

    return $object;

}#new

#-------------------------------------------------------------------------------
sub refresh {

    my $self = shift;
    my $type = ref($self) || die "$self is not an object!";

    $self->flush() unless $self->{'haveflushed'};

    $self->{'tstamp'} = [gettimeofday];
    $self->{'show'} = [];
    $self->{'haveflushed'} = 0;
    # DO NOT DO THIS # $self->{'messageList'} = [];

}#refresh

#-------------------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    my $type = ref($self) || die "$self is not an object!";
    $self->flush(0) if @{$self->{'messageList'}};
}

#-------------------------------------------------------------------------------
return 1;

=pod:synopsis Record log messages, write them to file and append to stdout.

=pod:summary

    use Hub;
    my $log = Hub::mkinst( 'Logger', "/var/log/service.log" );
    $log->show( "warn, info, foo" );

    $log->msg( "I will print b/c level 'info' is specified", 'info' );
    $log->msg( "I will print b/c there is no type" );
    $log->err( "$!: $filename" );
    $log->msg( "I will not print", "kmfdm" );

    $log->flush(); # write to file (also called on DESTROY)

=pod:description

This logger is used by this library.  Logging levels are not standardized,
but you can specify show( 'all' ) to see what gets used.

Always available:

          Unspecified messages

  err     Error, fatal errors such as configuration issues. (always 
          print, unless 'opressed' is set)

These are used by this library, and may also server as examples:

  info    Informational, users will set this as the default to get a warm
          fuzzy of program flow.

  warn    Warning, non-fatal errors such as configuration issues.

  verb    Verbose, programmers will look at this output to determine where to 
          start debugging an error.

  dbg     Debug, these messages are useless unless you know what you're
          looking for.

=cut

'???';
