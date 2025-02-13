# == Class: users
#
# Full description of class users here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if it
#   has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should not be used in preference to class parameters  as of
#   Puppet 2.6.)
#
# === Examples
#
#  class { users:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ]
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2011 Your name here, unless otherwise noted.
#
class users {
  if $::operatingsystem == 'debian' {
    user { 'rely':
      ensure     => 'present',
      managehome => true,
      groups     => 'sudo',
      password   => '$1$Dnuo2hbA$QS6RbCP0X7M/dWnSdwNbs1',
      require    => Package['sudo'],
    }
    package { [ 'sudo' ]:
      ensure => 'present',
    }
  }
  if $::operatingsystem == 'ubuntu' {
    user { 'rely':
      ensure     => 'present',
      managehome => true,
      groups     => 'sudo',
      password   => '$6$1fFkOm2c$4DkU9y083G/eOuV9XlhSZA.jfJc8PlxW1rsC2IMNUTMIw43Tn/ylDjpinPPgO8K6pMis1MyW3/xgdEMJ3qBBr0',
    }
  }
}
