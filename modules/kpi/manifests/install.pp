define kpi::install::macos () {
  exec {$name:
    unless => "/usr/bin/whereis ${name}",
    command => "/opt/homebrew/bin/brew install ${name}",
  }
}

define kpi::install::linux () {
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

define kpi::install () {
  if $facts['os']['family'] == 'Darwin' {
    kpi::install::macos{$name:}
  } else {
    kpi::install::linux{$name:}
  }
}
