package Hub::Config::Webapp;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/CONF_WEBAPP/;

use constant CONF_WEBAPP => {

  # Session files and user data is stored in this directory.  The web server
  # user account (apache) must have write privileges here.
  'session' => {
    'enable' => 1,
    'directory' => '.sessions',
    'timeout' => 3600,
  },

  # Apache2 mod_perl2 PerlAuthenHandler
  'authorization' => {
    # Where are user accounts located?
    'users' => '/users',
    # To what do we compare the password?
    'password_key' => 'password.sha1',
    # Timeout in seconds
    'timeout' => 600,
  },

  # Content management
  'cms' => {
    # The website root directory. The web server user account (apache) must 
    # have write privileges here before either visitors or administrators are 
    # able to save data.
    'root' => '/',
    # Deny access to these directories
    'deny' => [],
  },

  # Source-code control
  'scc' => {
    'control_dir' => '.svn',
    'enabled' => '1',
    'command' => {
      'remove'  => 'svn remove --force [#file]',
      'add'     => 'svn add --force [#file]',
      'commit'  => 'svn commit [#file] -m "[#message]"',
      'restore' => 'svn update [#file]',
      'update'  => 'svn update -r[#revision]',
      'setignore' => 'svn propset svn:ignore "[#ignore]" "[#path]"',
      'getignore' => 'svn propget svn:ignore "[#path]"',
    },
  },

};

1;
