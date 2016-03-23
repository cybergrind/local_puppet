class kpi::packages::system () {
  $system = [ 'yaourt', 'sudo', 'base-devel' ]
  package { $system:
    require => [ Class[kpi::repos] ]
  }

  user { 'yaourt':
    ensure => present,
    require => [ Package[$system] ],
  }

  file { '/etc/sudoers.d/yaourt':
    source => 'puppet:///modules/kpi/sudo.yaourt',
    mode => '440',
    require => [ User['yaourt'] ],
  }

  file { '/etc/makepkg.conf':
    content => epp('kpi/makepkg.conf.epp', {}),
  }
}

class kpi::packages () {
  $pkgs_nox = [
    'zsh', 'screen', 'encfs', 'iotop', 'htop', 'atop',
    'pv', 'pwgen', 'rsync', 'strace',
    'netctl', 'dialog', 'wpa_supplicant',
    'alsa-firmware', 'alsa-plugins', 'alsa-tools', 'alsa-utils',
    'net-tools', 'mtr', 'nmap', 'openbsd-netcat', 'bwm-ng',
    'powertop',
  ]
  kpi::install { $pkgs_nox: }

  $pkgs = [
    'ttf-droid', 'ttf-ms-fonts', 'ttf-freefont', 'ttf-bitstream-vera',
    'ttf-liberation', 'ttf-ubuntu-font-family', 'xkb-switch-git',
    'xorg-xev', 'xterm',
    'awesome',
    'virtualbox',
    'dropbox', 'skype', 'viber', 'pidgin', 'hipchat',
    'mplayer', 'mupdf', 'xpdf',
    'qbittorrent',  'shutter',
    'firefox-nightly', 'google-chrome', 'flashplugin', 'lib32-flashplugin', 'chromium-pepper-flash',
  ]
  kpi::install { $pkgs: }
}
