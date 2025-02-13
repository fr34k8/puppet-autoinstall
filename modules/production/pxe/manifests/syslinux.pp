# This class will install the syslinux images into the tftp root directory.

class pxe::syslinux {

  include pxe::params

  $syslinux_dir     = $pxe::params::syslinux_dir
  $syslinux_archive = $pxe::params::syslinux_archive
  $tftp_root        = $pxe::tftp_root

  exec { "syslinux_install":
    path    => ["/bin", "/usr/bin", "/usr/local/bin"],
    cwd     => "/usr/local/src",
    command => "wget -q -O - ${syslinux_archive} | tar -xz -C /usr/local/src",
    creates => "/usr/local/src/syslinux-4.04",
    require => Class[ 'tftp' ],
  }

  File {
    owner => root,
    group => 0,
    mode  => 755,
  }

  file {
    "${tftp_root}/pxelinux.0":
      source    => "${syslinux_dir}/core/pxelinux.0",
      require   => Exec["syslinux_install"];
    "${tftp_root}/menu.c32":
      source    => "${syslinux_dir}/com32/menu/menu.c32",
      require   => Exec["syslinux_install"];
    "${tftp_root}/vesamenu.c32":
      source    => "${syslinux_dir}/com32/menu/vesamenu.c32",
      require   => Exec["syslinux_install"];
    "${tftp_root}/chain.c32":
      source    => "${syslinux_dir}/com32/modules/chain.c32",
      require   => Exec["syslinux_install"];
    "${tftp_root}/reboot.c32":
      source    => "${syslinux_dir}/com32/modules/reboot.c32",
      require   => Exec["syslinux_install"];
    "${tftp_root}/memdisk":
      source    => "${syslinux_dir}/memdisk/memdisk",
      require   => Exec["syslinux_install"];
    "${tftp_root}/pxelinux.cfg":
      ensure    => directory;
  }

}
