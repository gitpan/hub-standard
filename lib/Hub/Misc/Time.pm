package Hub::Misc::Time;
use strict;
use Hub qw/:lib/;
our $VERSION        = '4.00043';
our @EXPORT         = qw//;
our @EXPORT_OK      = qw/
    datetime
    dhms
/;

our @MONTH_NAMES    = (
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December"
);

our @MONTH_ABBRS    = (
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec"
);

our @DAY_NAMES      = (
  "Sunday",
  "Monday",
  "Tueday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday"
);

our @DAY_ABBRS      = (
  "Sun",
  "Mon",
  "Tue",
  "Wed",
  "Thr",
  "Fri",
  "Sat"
);

# ------------------------------------------------------------------------------
# datetime - Friendly date-time formats of seconds-since-the-epoch timestamps.
# datetime [$timestamp], [options]
#
# Default is the current time formatted as: MM/DD/YYYY hh:mm:ss.
# The decimal portion of HiRest time is truncated.
# Uses `localtime` to localize.
# ------------------------------------------------------------------------------
#|test(true)                                datetime( );
#|test(regex,02\/..\/2003 ..:..:24)         datetime( 1045837284 );
#|test(regex,02\/..\/2003 ..:..)            datetime( 1045837284, -nosec );
#|test(regex,02\/.. ..:..:24)               datetime( 1045837284, -noyear );
#|test(regex,02\/..\/2003 ..:..:24am)       datetime( 1045837284, -ampm );
#|test(regex,2\/..\/2003 .:..:24)           datetime( 1045837284, -nozeros );
#|test(regex,02\/..\/2003)                  datetime( 1045837284, -notime );
#|test(regex,..:..:24)                      datetime( 1045837284, -nodate );
#|test(regex,February .., 2003 ..:..:24)    datetime( 1045837284, -letter );
#
# Combining options
#
#|test(regex)   datetime( 1045837284, -ampm, -nosec );              
#~              02\/..\/2003 ..:..am
#
#|test(regex)   datetime( 1045837284, -nosec, -nozeros, -noyear );
#~              2\/.. .:..
# ------------------------------------------------------------------------------

sub datetime {
  my ($opts, $timestamp) = Hub::opts(\@_);
  $timestamp ||= time;
  # Get fields for requested time
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($timestamp);
  # Aquire logical values
  my $ampm = "";
  if( $$opts{'ampm'} ) {
    $ampm = $hour > 12 ? "pm" : "am";
    $hour = $hour > 12 ? $hour - 12 : $hour;
  }#if
  my $digit_format = $$opts{'nozeros'} ? '%d' : '%02d';
  my $props = {
    day     => sprintf( $digit_format, $mday ),
    month   => sprintf( $digit_format, $mon+1 ),
    year    => $year + 1900,
    hour    => sprintf( $digit_format, $hour ),
    minute  => sprintf( '%02d', $min ),
    second  => sprintf( '%02d', $sec ),
    ampm    => $ampm,
  };
  my $names = {
    MONTH   => $MONTH_NAMES[$mon],
    MM      => $MONTH_ABBRS[$mon],
    DAY     => $DAY_NAMES[$wday],
    DD      => $DAY_ABBRS[$wday],
  };
  # Default formats
  my $date = "[#month]/[#day]/[#year]";
  my $time = "[#hour]:[#minute]:[#second][#ampm]";
  # Apply formatting options
  $$opts{'nosec'}     and $time = "[#hour]:[#minute][#ampm]";
  $$opts{'noyear'}    and $date = "[#month]/[#day]";
  $$opts{'letter'}    and $date = "[#MONTH] [#day], [#year]";
  $$opts{'mysql'}     and $date = "[#year]-[#month]-[#day]";
  my $format = "$date $time";
  $$opts{'apache'}    and $format =
    "[#DD] [#MM] [#day] [#hour]:[#minute]:[#second] [#year]";
  $$opts{'notime'}    and $format = $date;
  $$opts{'nodate'}    and $format = $time;
  # Populate template format with data and time
  return Hub::populate(\$format, $props, $names);
}#dateTime

# ------------------------------------------------------------------------------
# Hub::dhms( $seconds, $options, $format )
#
# Format the provided number of seconds in days, hours, minutes, and seconds.
#
#   Examples:                                               Returns:
#   ------------------------------------------------------- --------------------
#   Hub::dhms( 10 )                                              00d:00h:00m:10s
#   Hub::dhms( 60 )                                              00d:00h:01m:00s
#   Hub::dhms( 3600 )                                            00d:01h:00m:00s
#   Hub::dhms( 86400 )                                           01d:00h:00m:00s
#   Hub::dhms( 11 )                                              00d:00h:00m:11s
#   Hub::dhms( 71 )                                              00d:00h:01m:11s
#   Hub::dhms( 3671 )                                            00d:01h:01m:11s
#   Hub::dhms( 90071 )                                           01d:01h:01m:11s
#   Hub::dhms( 90071, "--nozeros" )                              1d:1h:1m:11s
#   Hub::dhms( 90071, "--nozeros" )                              1d:1h:1m:11s
#   Hub::dhms( 90071, "--nozeros", "[#d]days [#h]:[#m]:[#s]" )   1days 1:1:11
#   Hub::dhms( 90071, "[#d]days [#h]:[#m]:[#s]" )                01days 01:01:11
#   
# ------------------------------------------------------------------------------
sub dhms {
  my ($seconds,$options,$format) = @_;
  return unless $seconds;
  unless( $format ) {
    $format = $options unless $options =~ /--/;
  }
  my $digit_format = "%02d";
  $options =~ /nozeros/   and $digit_format = "%d";
  $options =~ /MS/        and $format = "[#m]m:[#s]s";
  $options =~ /HMS/       and $format = "[#h]h:[#m]m:[#s]s";
  $format ||= "[#d]d:[#h]h:[#m]m:[#s]s";
  my $dhms = {
    d => 0,
    h => 0,
    m => 0,
    s => 0,
  };
  $$dhms{'d'} = sprintf( $digit_format, int($seconds/86400) );
  $seconds -= ($$dhms{'d'} * 86400);
  $$dhms{'h'} = sprintf( $digit_format, int($seconds/3600) );
  $seconds -= ($$dhms{'h'} * 3600);
  $$dhms{'m'} = sprintf( $digit_format, int($seconds/60) );
  $seconds -= ($$dhms{'m'} * 60);
  $$dhms{'s'} = sprintf( "%02d", $seconds ); # sec don't acknowledge 'nozeros'
  return Hub::populate( \$format, $dhms );
}#dhms

#   ------------------------------------------------------- --------------------
1;
