define kpi::install () {
  include kpi::repos
  include kpi::packages::system

  exec { $name:
    unless => "/usr/bin/yay -Qk ${name}",
    user => 'yay',
    cwd => "/tmp",
    timeout => 1800,
    command => "/usr/bin/yay -S --noconfirm ${name}",
    require => [ Class[kpi::packages::system] ],
    environment => ['HOME=/home/yay'],
  }
}
