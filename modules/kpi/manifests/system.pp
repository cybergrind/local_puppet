# System-level Arch config: X input, pam_cap, gamescope, udev, systemd timeouts,
# lock before sleep, logind. Per-user bits (capability.conf) are in kpi::linux.
class kpi::system {
  include kpi::os

  if $kpi::os::is_arch {
    file { '/etc/X11/xorg.conf.d/50-synaptics.conf':
      source  => 'puppet:///modules/kpi/50-synaptics.conf',
      require => [Kpi::Install['xf86-input-synaptics']],
    }

    # pam_cap hands out /etc/security/capability.conf (kpi::linux) at login
    file { '/etc/pam.d/system-login':
      source => 'puppet:///modules/kpi/system-login',
    }

    exec { 'gamescope-cap-sys-nice':
      command => '/usr/bin/setcap cap_sys_nice=eip /usr/bin/gamescope',
      unless  => '/usr/bin/getcap /usr/bin/gamescope | /usr/bin/grep -q cap_sys_nice',
      require => [Kpi::Install['gamescope']],
    }

    # Disable PS4/PS5 controller touchpad from acting as a mouse
    file { '/etc/udev/rules.d/99-ds4-touchpad.rules':
      source => 'puppet:///modules/kpi/99-ds4-touchpad.rules',
    }

    $shutdown_timeout = "[Manager]\nDefaultTimeoutStopSec=1min\n"

    file { '/etc/systemd/system.conf.d':
      ensure => directory,
    }
    -> file { '/etc/systemd/system.conf.d/50-shutdown-timeout.conf':
      content => $shutdown_timeout,
    }

    file { '/etc/systemd/user.conf.d':
      ensure => directory,
    }
    -> file { '/etc/systemd/user.conf.d/50-shutdown-timeout.conf':
      content => $shutdown_timeout,
    }

    file { '/etc/systemd/system/lock-before-sleep.service':
      source => 'puppet:///modules/kpi/lock-before-sleep.service',
    }
    ~> exec { 'enable lock-before-sleep':
      command => '/bin/systemctl enable lock-before-sleep.service',
      unless  => '/bin/systemctl is-enabled lock-before-sleep.service',
    }

    # Ignore the power button so the cat can't power the machine off.
    # Powering on is firmware-level and unaffected by this.
    file { '/etc/systemd/logind.conf.d':
      ensure => directory,
    }
    -> file { '/etc/systemd/logind.conf.d/50-power-button.conf':
      content => "[Login]\nHandlePowerKey=ignore\nHandlePowerKeyLongPress=ignore\n",
    }
    ~> exec { 'restart-logind':
      command     => '/bin/systemctl restart systemd-logind',
      refreshonly => true,
    }
  }
}
