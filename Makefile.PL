use 5.008003;
use ExtUtils::MakeMaker;
%makefileargs = (
    'NAME'              => 'Hub',
    'VERSION_FROM'      => 'lib/Hub.pm',
    'PREREQ_PM'         => {
      'Carp' 						=> 1.01,
      'CGI' 						=> 3.11,
      'Compress::Zlib'	=> 1.33,
      'Cwd' 						=> 2.12,
      'Exporter' 				=> 5.57,
      'Fcntl' 					=> 1.1,
      'File::Copy' 			=> 2.07,
      'File::stat' 			=> 0,
      'IO::Dir'					=> 0,
      'IO::File'				=> 1.10,
      'IO::Handle'			=> 0,
      'LWP::UserAgent'	=> 0,
      'Net::HTTP'				=> 0,
      'Scalar::Util'		=> 0,
      'Time::HiRes'			=> 1.55,
    },
		EXE_FILES						=>
			[qw(scripts/hub-info scripts/hub-parse scripts/hub-passwd scripts/hub-get)],
    ($] >= 5.005 ?
      (ABSTRACT => 'Hub Library',
       AUTHOR   => 'Livesite Networks, LLC') : ()),
);
WriteMakefile(%makefileargs);
