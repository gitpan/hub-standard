package Hub::Config::Base;
use strict;
use Hub qw/:lib/;
our $VERSION = '4.00043';
our @EXPORT = qw//;
our @EXPORT_OK = qw/CONF_BASE/;

use constant CONF_BASE => {
  'win32' => {
    'owner_name' => 'Administrators',
    'group_name' => 'Everyone',
    'other_name' => 'Everyone',
  },
  'parser' => {
    'max_depth' => 10000,
    'max_scope_depth' => 100,
  },
};

1;
