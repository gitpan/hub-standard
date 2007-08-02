package Hub::Webapp::Session;
use strict;
use CGI qw(:standard);
use CGI::Cookie;
use Hub qw(:lib);
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/
  COOKIE_SID
  SESSION_FILENAME
/;

use constant {
  COOKIE_SID        => "SID",
  SESSION_FILENAME  => "session.hf",
};

our @ISA = qw/Hub::Data::HashFile/;

sub new {
  my $sid = $_[1];
  unless ($sid) {
    $sid = Hub::checksum(Hub::random_id());
    my $cookie = new CGI::Cookie(
      -name   => COOKIE_SID,
      -value  => $sid,
      -expires=> '+1M',
      -path   => '/'
    );
    $$Hub{'/sys/response/headers'} ||= [];
    unshift @{$$Hub{'/sys/response/headers'}}, "Set-Cookie: $cookie";
  }
  my $path = $$Hub{'/conf/session/directory'};
  $path = Hub::secpath($path);
  mkdir $path unless -e $path;
  die "Session directory '$path' is not a directory"
      unless -d $path;
  $path .= Hub::SEPARATOR . $sid . Hub::SEPARATOR . SESSION_FILENAME;
  if (-e $path && $$Hub{'/conf/session/timeout'}) {
    my $stats = stat($path);
    my $delta = $$Hub{'/conf/session/timeout'} - (time - $stats->mtime());
    Hub::rmfile($path) if $delta < 0;
  }
  Hub::mkabsdir(Hub::getpath($path));
  Hub::touch($path);
  my $self = $_[0]->SUPER::new($path);
  $$self{'directory'} = Hub::getpath($path);
  $$self{+COOKIE_SID} = $sid;
  return $self;
}#new

1;
