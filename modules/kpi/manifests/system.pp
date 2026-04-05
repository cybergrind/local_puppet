class kpi::system {
  case $::os['name'] {
    'Archlinux': {
      file { '/etc/X11/xorg.conf.d/50-synaptics.conf':
        source => 'puppet:///modules/kpi/50-synaptics.conf',
        require => [ Kpi::Install['xf86-input-synaptics'] ],
      }

      # Grant CAP_SYS_NICE to user kpi via pam_cap
      file { '/etc/security/capability.conf':
        content => "cap_sys_nice kpi\n",
      }

      file { '/etc/pam.d/system-login':
        source => 'puppet:///modules/kpi/system-login',
      }

      exec { 'gamescope-cap-sys-nice':
        command => '/usr/bin/setcap cap_sys_nice=eip /usr/bin/gamescope',
        unless  => '/usr/bin/getcap /usr/bin/gamescope | /usr/bin/grep -q cap_sys_nice',
        require => [ Kpi::Install['gamescope'] ],
      }
    }
  }
}
