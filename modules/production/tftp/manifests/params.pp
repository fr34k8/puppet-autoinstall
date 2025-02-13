# Class: tftp::params
#
#   TFTP class parameters.
class tftp::params {
  $address    = '0.0.0.0'
  $port       = '69'
  $options    = '--secure --create'
  $binary     = '/usr/sbin/in.tftpd'
  $inetd      = false

  case $::osfamily {
    'debian': {
      $package  = 'tftpd-hpa'
      $defaults = true
      $username = 'tftp'
      case $::operatingsystem {
        'debian': {
          $directory  = '/srv/tftp'
          $hasstatus  = false
          $provider   = undef
        }
        'ubuntu': {
          $directory  = '/var/lib/tftpboot'
          $hasstatus  = true
          $provider   = 'upstart'
        }
      }
    }
    'redhat': {
      $package    = 'tftp-server'
      $username   = 'nobody'
      $defaults   = false
      $directory  = '/var/lib/tftpboot'
      $hasstatus  = false
      $provider   = 'base'
    }
    default: {
      $package    = 'tftpd'
      $username   = 'nobody'
      $defaults   = false
      $hasstatus  = false
      $provider   = undef
      warning("tftp:: $::operatingsystem may not be supported")
    }
  }
}
