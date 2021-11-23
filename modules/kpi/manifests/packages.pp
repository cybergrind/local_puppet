class kpi::packages::system () {
  $system = [ 'sudo', 'openssh', 'base-devel' ]
  package { $system:
    require => [ Class[kpi::repos] ]
  }

  user { 'yay':
    ensure => present,
    managehome => true,
    require => [ Package[$system] ],
  }
  -> vcsrepo {'/home/yay/yay-bin/':
    ensure => latest,
    provider => git,
    source => 'https://aur.archlinux.org/yay-bin.git',
    user => 'yay',
  }
  ~> exec { "makepkg -f && cp yay-*.pkg.tar.xz yay.tar.xz":
    user => 'yay',
    cwd => '/home/yay/yay-bin',
    environment => ['HOME=/home/yay'],
    provider => shell,
    creates => '/home/yay/yay-bin/yay.tar.xz',
    #refreshonly => true,
  }
  ~> exec { 'pacman -U --noconfirm /home/yay/yay-bin/yay.tar.xz':
    user => 'root',
    provider => shell,
    #unless => "/usr/bin/pacman -Qk ${name}",
    creates => '/usr/bin/yay',
    #refreshonly => true,
  }

  file { '/etc/sudoers.d/yay':
    source => 'puppet:///modules/kpi/sudo.yay',
    mode => '440',
    require => [ User['yay'] ],
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
    'pv', 'pwgen', 'rsync', 'strace',
    'netctl', 'dialog', 'wpa_supplicant',
    'alsa-firmware', 'alsa-plugins', 'alsa-tools', 'alsa-utils',
    'net-tools', 'mtr', 'nmap', 'openbsd-netcat', 'bwm-ng', 'ipset',
    'unzip', 'pigz', 'fzf', 'p7zip',
    'powertop',
    'uctags-git', 'vim-plug-git',
    'the_silver_searcher', 'fd',
  ]
  kpi::install { $pkgs_nox:
    require => [Class[kpi::packages::system]],
  }

  $pkgs = [
    'ttf-droid', 'ttf-ms-fonts', 'ttf-bitstream-vera',
    'ttf-droid-sans-mono-slashed-powerline-git',
    'ttf-liberation', 'ttf-ubuntu-font-family',
    'xorg-server', 'xf86-input-synaptics', 'xf86-input-evdev',
    'xorg-xev', 'xterm', 'sakura', 'pkgfile', 'xorg-xmodmap',
    'awesome', 'vicious', 'xorg-xrandr', 'arandr',
    'virtualbox',
    'mplayer', 'mupdf', 'xpdf', 'feh',
    'qbittorrent',
    'firefox', 'google-chrome',
    'yandex-disk',
    # X related
     'xsel', 'flameshot', 'copyq'
  ]
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}

class kpi::packages::optional () {
  $pkgs = [
    'direnv', 'viber',
    'lm_sensors', 'lshw', 'hdparm', 'tk',
    'pavucontrol', 'pipewire-pulse', 'pasystray',
    'xscreensaver', 'teamviewer',
    'inotify-tools',
    # development
    'python-virtualenv', 'whois', 'bind-tools', # dig
    'python-pip', 'flake8',
    'postgresql-libs',
  ]
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}
