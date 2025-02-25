class kpi::packages::system() {
  if $facts['os']['family'] == 'Archlinux' {
    class {'kpi::packages::system::linux':}
  } else {
    info("no system for macos")
  }
}


class kpi::packages::system::linux () {
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

  service { 'NetworkManager':
    ensure => running,
    enable => true,
    require => [Kpi::Install['networkmanager']]
  }
  include kpi::system
}

class kpi::packages::hyprland () {
  $pkgs = [
    'hyprland', 'wofi',
    'uwsm',
    'wl-clipboard',
    'xdg-desktop-portal-hyprland',
    'xdg-desktop-portal',
    'xdg-desktop-portal-gnome',
    'xdg-desktop-portal-gtk-git'
  ]
  kpi::install { $pkgs: }
}
class kpi::packages::sway () {
  $pkgs_sway = [
    'sway', 'swaylock',
    'wl-clipboard',
    'xdg-desktop-portal',
    'xdg-desktop-portal-gnome',
    'grim', 'slurp',
    'spectacle',
  ]
  kpi::install { $pkgs_sway: } 
}

class kpi::packages () {
  if $facts['os']['family'] == 'Archlinux' {
    class {'kpi::packages::linux':}
    # class {'kpi::packages::sway':}
    class {'kpi::packages::hyprland':}
  } else {
    class {'kpi::packages::macos':}
  }
}

class kpi::packages::macos () {
  kpi::install::macos{'gromgit/fuse':
    tap => true,
    bin => '/opt/homebrew/bin/encfs',
  }
  kpi::install {'git': bin => 'noinstall'}
  kpi::install {'findutils':
    bin => '/opt/homebrew/opt/findutils'
  }
  kpi::install {'encfs-mac':
    bin => '/opt/homebrew/bin/encfs'
  }

  $pkgs_nox = [
    'pinentry-mac',
    'gpg',
    'tmux', 'cmake', 'emacs-plus', 'kubectl', 'nvim',
    'vim', 'ag', 'direnv', 'fd', 'nvm',
    'htop', 'tree', 'npm',
    'py3cairo', 'gtk+3',
    'xsel', 'kubectx'
  ]
  kpi::install { $pkgs_nox: }

  $pkgs_cask = [
    'nikitabobko/tap/aerospace',
  ]

  kpi::install::macos { $pkgs_cask: cask => true }

}

class kpi::packages::linux () {
  $pkgs_nox = [
    'zsh', 'zsh-completions',
    'gnome-keyring', 'libgnome-keyring',
    'tmux', 'encfs', 'iotop', 'htop', 'atop',
    'inetutils',
    'pv', 'pwgen', 'rsync', 'strace',
    'netctl', 'dialog', 'wpa_supplicant',
    'alsa-firmware', 'alsa-plugins', 'alsa-tools', 'alsa-utils',
    'net-tools', 'mtr', 'nmap', 'openbsd-netcat', 'bwm-ng', 'ipset',
    'unzip', 'pigz', 'fzf', 'p7zip',
    'powertop',
    'uctags-git', 'vim-plug-git',
    'the_silver_searcher', 'fd',
    'networkmanager-openvpn',
    'networkmanager',
    'kubectx', 'xh',
    'libxcrypt-compat', 'libselinux',
    'asp', 'man-db', 'man-pages',
  ]
  kpi::install { $pkgs_nox:
    require => [Class[kpi::packages::system]],
  }

  $pkgs = [
    'ttf-droid', 'ttf-ms-fonts', 'ttf-bitstream-vera',
    'ttf-droid-sans-mono-slashed-powerline-git',
    'ttf-fira-code', 'woff-fira-code', 'woff2-fira-code',
    'ttf-liberation', 'ttf-ubuntu-font-family',
    'ttf-liberation-mono-nerd', 'noto-fonts-emoji',
    'otf-openmoji', 'ttf-joypixels', 'ttf-twemoji-color',
    'xorg-server', 'xf86-input-synaptics', 'xf86-input-evdev',
    'xorg-xrdb', 'xorg-xev',
    'xterm', 'xorg-xrandr', 'arandr', 'xorg-xmodmap',
    'pkgfile', 'kitty',
    'awesome', 'vicious',
    'virtualbox',
    'mupdf', 'xpdf', 'feh',
    'qbittorrent',
    'google-chrome',
    'yandex-disk', 'helm',
    'tfswitch-bin',
    # X related
    'xsel', 'flameshot', 'copyq',
    'dunst', # required for flameshot
    'network-manager-applet',
    'gtk2', 'freerdp', 'jq', 'yq',
    'pcmanfm', 'k9s',
    'ruff', 'aws-cli',
    'slock', 'xorg-xinput',
    # notifications
    'mate-notification-daemon',
  ]

  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }

  kpi::install { 'helmfile':
    require => [Class[kpi::packages::system]],
  }
}

class kpi::packages::optional () {
  case $::os['name'] {
    'Archlinux': {
      $pkgs = [
        'direnv',
        'lm_sensors', 'lshw', 'hdparm', 'tk',
        'pavucontrol', 'pipewire-pulse', 'pasystray',
        'xscreensaver', 'teamviewer',
        'inotify-tools',
        # development
        'python-virtualenv', 'whois', 'bind-tools', # dig
        'python-pip', 'flake8', 'python-uv',
        'postgresql-libs',
        'nvm', 'pnpm-bin',
      ]
    }
    'Darwin': {
      $pkgs = []
    }
  }


  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}


class kpi::packages::hidpi () {
  $pkgs = [
    'xpra',
  ]
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}
