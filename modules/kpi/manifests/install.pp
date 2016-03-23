define kpi::install () {
  include kpi::repos
  include kpi::packages::system

  exec { $name:
    unless => "/usr/bin/yaourt -Qk ${name}",
    user => 'yaourt',
    cwd => "/tmp",
    timeout => 1800,
    command => "/usr/bin/yaourt -S --noconfirm ${name}",
    require => [ Class[kpi::packages::system] ],
  }
}
