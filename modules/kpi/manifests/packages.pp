class kpi::packages::system() {
  include kpi::os
  if $kpi::os::is_arch {
    class {'kpi::packages::system::linux':}
  } else {
    info("no system for macos")
  }
}

class kpi::packages::system::linux () {
  $system = [ 'sudo', 'openssh', 'base-devel', 'go' ]
  package { $system:
    require => [ Class[kpi::repos] ]
  }

  user { 'yay':
    ensure => present,
    managehome => true,
    require => [ Package[$system] ],
  }
  -> vcsrepo {'/home/yay/yay/':
    ensure => latest,
    provider => git,
    source => 'https://github.com/Jguer/yay.git',
    user => 'yay',
  }
  ~> exec { 'build yay':
    command => 'make',
    user => 'yay',
    cwd => '/home/yay/yay',
    environment => ['HOME=/home/yay'],
    provider => shell,
    refreshonly => true,
  }
  ~> exec { 'install yay':
    command => 'make PREFIX=/usr install',
    user => 'root',
    cwd => '/home/yay/yay',
    provider => shell,
    refreshonly => true,
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

class kpi::packages::hyprland (Array[String] $pkgs) {
  kpi::install { $pkgs: }
}

class kpi::packages::niri (Array[String] $pkgs) {
  kpi::install { $pkgs: }
}

class kpi::packages::glimpse () {
  kpi::install { 'glimpse-desktop-bin': }
}
class kpi::packages::sway (Array[String] $pkgs) {
  kpi::install { $pkgs: }
}

class kpi::packages::windows (Array[String] $pkgs) {
  kpi::install { $pkgs: }
}

class kpi::packages () {
  include kpi::os
  unless $kpi::os::is_windows {
    class {'kpi::packages::common':}
  }

  if $kpi::os::is_arch {
    class {'kpi::packages::linux':}
    # class {'kpi::packages::sway':}
    class {'kpi::packages::hyprland':}
    class {'kpi::packages::niri':}
    class {'kpi::packages::glimpse':}
  } elsif $kpi::os::is_windows {
    class {'kpi::packages::windows':}
  } else {
    class {'kpi::packages::macos':}
  }
}

# Package lists for this and the per-OS classes below live in module data:
# data/common.yaml (same name in brew and pacman/AUR) and data/os/<family>.yaml.
class kpi::packages::common (Array[String] $pkgs) {
  kpi::install { $pkgs: }
}

class kpi::packages::macos (Array[String] $pkgs, Array[String] $casks) {
  kpi::install {'git': bin => 'noinstall'}  # ships with Xcode CLT

  # encfs needs macFUSE; the cask runs a sudo'ed .pkg installer, which can't
  # prompt from inside puppet, so ./run installs it interactively beforehand.
  kpi::install {'macfuse': cask => true}
  -> kpi::install {'gromgit/fuse/encfs-mac': }

  kpi::install { $pkgs: }
  kpi::install { $casks: cask => true }
}

class kpi::packages::linux (Array[String] $pkgs_nox, Array[String] $pkgs) {
  kpi::install { $pkgs_nox:
    require => [Class[kpi::packages::system]],
  }

  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}

class kpi::packages::optional (Array[String] $pkgs = []) {
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}

class kpi::packages::hidpi (Array[String] $pkgs) {
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}
