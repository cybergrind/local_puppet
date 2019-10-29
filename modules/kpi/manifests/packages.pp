class kpi::packages::system () {
  $system = [ 'yaourt', 'sudo', 'openssh' ]
  package { $system:
    require => [ Class[kpi::repos] ]
  }

  user { 'yaourt':
    ensure => present,
    managehome => true,
    require => [ Package[$system] ],
  } ->
  exec { "gpg --keyserver pgp.mit.edu --recv-keys 14F26682D0916CDD81E37B6D61B7B526D98F0353 && touch .ff.key":
    user => 'yaourt',
    cwd => '/home/yaourt',
    provider => shell,
    creates => '/home/yaourt/.ff.key'
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
    'ttf-droid', 'ttf-ms-fonts', 'ttf-bitstream-vera',
    'ttf-droid-sans-mono-slashed-powerline-git',
    'ttf-liberation', 'ttf-ubuntu-font-family',
    'xorg-server', 'xf86-input-synaptics', 'xf86-input-evdev', 'xf86-input-keyboard',
    'xf86-input-mouse',
    'xorg-xev', 'xterm', 'sakura', 'pkgfile', 'xorg-xmodmap',
    'awesome', 'vicious', 'xorg-xrandr', 'arandr',
    'virtualbox',
    'mplayer', 'mupdf', 'xpdf',
    'qbittorrent',
    'firefox', 'google-chrome', 'flashplugin', 'lib32-flashplugin',
    'yandex-disk',
    # X related
     'xsel', 'flameshot',
  ]
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}

class kpi::packages::optional () {
  $pkgs = [
    'direnv', 'viber',
    'lm_sensors', 'lshw', 'hdparm', 'tk',
    'pavucontrol', 'pulseaudio-alsa', 'pulseaudio',
    'xscreensaver', 'teamviewer',
    'emacs-python-mode',
    'inotify-tools',
    # development
    'python-virtualenv', 'whois', 'bind-tools', # dig
    'python-pip', 'python2-pip', 'flake8',
    'selenium-server-standalone',
    'postgresql-libs',
  ]
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}
