use 5.008003;
use ExtUtils::MakeMaker;

%makefileargs = (

    NAME              => 'Hub',
    VERSION_FROM      => 'lib/Hub.pm', # finds $VERSION
    PREREQ_PM         => { # e.g., Module::Name => 1.1
	CGI::Fast => 0.01,
Scalar::Util => 1.14,
Compress::Zlib => 1.41,
Fcntl => 1.05,
CGI => 3.10,
Archive::Tar => 1.26,
DBI => 1.50,
Net::HTTP => 1.00,
File::Copy => 2.08,
IO::File => 1.11,
IO::Zlib => 1.04,
Time::HiRes => 1.66,
Exporter => 5.58,
Carp => 1.04,
LWP::UserAgent => 2.033,
Cwd => 3.05,
File::stat => 1.00,
	},

    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT  		=> 'Hub Library',
       AUTHOR         	=> '<#meta/author>') : ()),

);

WriteMakefile( %makefileargs );
