# Arch bootstrap: the pacman packages yay needs, the yay user and a yay built
# from source, plus sshd, NetworkManager and the system tweaks (kpi::system).
class kpi::packages::system::linux (Array[String] $pkgs) {
  package { $pkgs:
    require => [Class[kpi::repos]],
  }

  user { 'yay':
    ensure     => present,
    managehome => true,
    require    => [Package[$pkgs]],
  }
  -> vcsrepo { '/home/yay/yay/':
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/Jguer/yay.git',
    user     => 'yay',
  }
  ~> exec { 'build yay':
    command     => 'make',
    user        => 'yay',
    cwd         => '/home/yay/yay',
    environment => ['HOME=/home/yay'],
    provider    => shell,
    refreshonly => true,
  }
  ~> exec { 'install yay':
    command     => 'make PREFIX=/usr install',
    user        => 'root',
    cwd         => '/home/yay/yay',
    provider    => shell,
    refreshonly => true,
  }

  file { '/etc/sudoers.d/yay':
    source  => 'puppet:///modules/kpi/sudo.yay',
    mode    => '0440',
    require => [User['yay']],
  }

  file { '/etc/makepkg.conf':
    content => epp('kpi/makepkg.conf.epp', {}),
  }

  service { 'sshd':
    ensure  => running,
    enable  => true,
    require => [Package['openssh']],
  }

  service { 'NetworkManager':
    ensure  => running,
    enable  => true,
    require => [Kpi::Install['networkmanager']],
  }

  include kpi::system
}
