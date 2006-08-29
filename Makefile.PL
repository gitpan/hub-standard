use 5.008007;
use ExtUtils::MakeMaker;

%makefileargs = (

    NAME              => 'Hub',
    VERSION_FROM      => 'lib/Hub.pm', # finds $VERSION
    PREREQ_PM         => { # e.g., Module::Name => 1.1
	File::Copy => 2.08,
Scalar::Util => 1.14,
Compress::Zlib => 1.41,
IO::Zlib => 1.04,
IO::File => 1.11,
Fcntl => 1.05,
Time::HiRes => 1.66,
Exporter => 5.58,
Carp => 1.04,
Archive::Tar => 1.26,
File::stat => 1.00,
Cwd => 3.05,

	},

    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT  		=> 'Hub Library',
       AUTHOR         	=> '<#meta/author>') : ()),

);

WriteMakefile( %makefileargs );
