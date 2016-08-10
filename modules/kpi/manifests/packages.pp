class kpi::packages::system () {
  $system = [ 'yaourt', 'sudo', 'openssh' ]
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

  service { 'sshd':
    ensure => running,
    enable => true,
    require => [ Package['openssh'] ],
  }
  include kpi::system
}

class kpi::packages () {
  $pkgs_nox = [
    'zsh', 'screen', 'encfs', 'iotop', 'htop', 'atop',
    'pv', 'pwgen', 'rsync', 'strace', 'the_silver_searcher',
    'netctl', 'dialog', 'wpa_supplicant',
    'alsa-firmware', 'alsa-plugins', 'alsa-tools', 'alsa-utils',
    'net-tools', 'mtr', 'nmap', 'openbsd-netcat', 'bwm-ng', 'ipset',
    'unzip', 'pigz',
    'powertop',
    'yapf',
    'universal-ctags-git', 'vim-plug-git',
  ]
  kpi::install { $pkgs_nox:
    require => [Class[kpi::packages::system]],
  }

  $pkgs = [
    'ttf-droid', 'ttf-ms-fonts', 'ttf-freefont', 'ttf-bitstream-vera',
    'ttf-liberation', 'ttf-ubuntu-font-family', 'xkb-switch-git',
    'xorg-server', 'xf86-input-synaptics', 'xf86-input-evdev', 'xf86-input-keyboard',
    'xf86-input-mouse',
    'xorg-xev', 'xterm', 'sakura', 'pkgfile', 'xorg-xmodmap',
    'awesome', 'vicious',
    'virtualbox',
    'dropbox', 'pidgin',
    'mplayer', 'mupdf', 'xpdf',
    'qbittorrent',  'shutter',
    'firefox', 'google-chrome', 'flashplugin', 'lib32-flashplugin',
    'chromium-pepper-flash',
  ]
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}

class kpi::packages::optional () {
  $pkgs = [
    'firefox-nightly', 'skype', 'viber',  'hipchat',
  ]
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}
