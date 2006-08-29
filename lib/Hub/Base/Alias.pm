package Hub::Base::Alias;

#-------------------------------------------------------------------------------
# Copyright (c) 2006 Livesite Networks, LLC.  All rights reserved.
# Copyright (c) 2000-2005 Ryan Gies.  All rights reserved.
#-------------------------------------------------------------------------------

#line 2
use strict;

use Hub qw/:lib/;

our @EXPORT         = qw//;
our @EXPORT_OK      = qw//;

# ------------------------------------------------------------------------------
# Access to logger
# ------------------------------------------------------------------------------

push @EXPORT_OK, qw/lshow  lraw    lmsg    lwarn   lerr    ldie    lflush
                    lbegm  lendm   ldmp    lfresh  lopt/;

sub lshow           { $Hub->logger->show( @_ ); }
sub lraw            { $Hub->logger->msg( join( '', @_ ) ); }
sub lmsg            { $Hub->logger->msg( @_ ); }
sub lwarn           { $Hub->logger->msg( shift, "warn" ); }
sub lerr            { $Hub->logger->err( @_ ); }
sub ldmp            { $Hub->logger->dump( @_ ); }
sub lflush          { $Hub->logger->flush( @_ ); }
sub lbegm           { $Hub->logger->measurefrom( @_ ); }
sub lendm           { $Hub->logger->measureto( @_ ); }
sub ldie            { $Hub->logger->morte( @_ ); }
sub lfresh          { $Hub->logger->refresh( @_ ); }
sub lopt            { $Hub->logger->set( @_ ); }

# ------------------------------------------------------------------------------
# Access to web constants
# ------------------------------------------------------------------------------

push @EXPORT_OK, qw/srcpath respath getconst setconst resdir/;

sub srcpath         { $Hub->config->getSourcePath( @_ ); }
sub respath         { $Hub->config->getResource( @_ ); }
sub getconst        { $Hub->config->getConst( @_ ); }
sub setconst        { $Hub->config->setConst( @_ ); }
sub resdir          { $Hub->config->getResourcePath( @_ ); }

# ------------------------------------------------------------------------------
# Access path elements
# ------------------------------------------------------------------------------

push @EXPORT_OK, qw/spath wpath rpath/;

sub spath           { $Hub->path->srcpath( @_ ); }
sub wpath           { $Hub->path->workpath( @_ ); }
sub rpath           { $Hub->path->respath( @_ ); }

# ------------------------------------------------------------------------------
# execconf - Execute the scripts configuration as a program.
# ------------------------------------------------------------------------------

push @EXPORT_OK, qw/execconf/;

sub execconf {

    my $opts = Hub::cmdopts( \@ARGV );

    my $props = $Hub->getcv('/');

    foreach my $arg ( %$opts ) {

      $Hub->setcv( $arg, $$opts{$arg} );

    }#foreach

    foreach my $key ( %$props ) {

      my $val = $$props{$key};

      defined $val && $val =~ /^`.*`$/ and do {
      
        my $tmp = eval($val);
        
        chomp $tmp;
        
        $Hub->setcv( $key, $tmp );

      };#do

    }#foreach

    Hub::writefile( ".main.sh",
      Hub::populate( $Hub->getcv( 'main' ), $Hub->getcv('/') ), 0750 );

    my $error_code = system ".main.sh";

    Hub::rmfile( ".main.sh" ) unless $error_code;

}#execconf

# ------------------------------------------------------------------------------


'???';
