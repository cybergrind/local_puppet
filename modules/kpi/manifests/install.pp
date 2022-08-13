define kpi::install::macos ($bin=undef, $tap=false) {
  if $tap {
    $command = "/opt/homebrew/bin/brew tap ${name}"
  } else {
    $command = "/opt/homebrew/bin/brew install ${name}"
  }
  if $bin {
    exec {$name:
      unless => "/usr/bin/whereis ${bin}",
      command => $command,
    }
  } else {
    exec {$name:
      unless => "/usr/bin/whereis ${name}",
      command => $command,
    }
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
