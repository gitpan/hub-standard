package Hub::Base::Logger;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

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


sub show ;
sub set ;
sub disable ;
sub tee ;
sub msg ;
sub out ;
sub err ;
sub dump ;
sub morte ;
sub measurefrom ;
sub measureto ;
sub logRaw ;
sub trim_file ;
sub flush ;
sub new ;
sub refresh ;
sub DESTROY ;

# ------------------------------------------------------------------------------
# AUTOLOAD
#
# We intend to attempt AUTOLOADing the module just once.
#
# This has been inserted as part of the BulkSplit structure.  We use AutoLoader
# to load the module body.
#
# When the module defines it's own AUTOLOAD, it will become redefined, and this 
# method will not be hit again.
# ------------------------------------------------------------------------------
sub AUTOLOAD {
    use AutoLoader qw//;
    my $name = $Hub::Base::Logger::AUTOLOAD;
	return if substr($name,-9) eq '::DESTROY';
    use Carp qw/croak/;
    croak "Undefined subroutine: $name" if defined &Hub::Base::Logger::Logger;
    $AutoLoader::AUTOLOAD = "Hub::Base::Logger::Logger";
    local $SIG{__WARN__} = sub {
        warn $_[0] unless $_[0] =~ "Subroutine AUTOLOAD redefined";
    };
    AutoLoader::AUTOLOAD();
    foreach my $pkg ( @Hub::Base::Logger::ISA ) {
        my ($pkgname) = $pkg =~ /.*::(\w+)$/;
        eval("${pkg}::Logger");
    }
    goto &$name;
}

1;

__END__
