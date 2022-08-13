define kpi::install::macos ($bin=undef, $tap=false) {
  info("Install ${name}")
  if $tap {
    $command = "/opt/homebrew/bin/brew tap ${name}"
  } else {
    $command = "/opt/homebrew/bin/brew install ${name}"
  }

  case $bin {
    undef: {
      exec {$name:
        creates => "/opt/homebrew/bin/${name}",
        command => $command,
      }
    }
    'noinstall': {}
    'skip': {
      exec {$name:
        command => $command,
      }
    }
    default: {
      exec {$name:
        #unless => "/usr/bin/whereis -q ${bin}",
        creates => $bin,
        command => $command,
      }
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

define kpi::install ($bin=undef, $tap=false) {
  if $facts['os']['family'] == 'Darwin' {
    kpi::install::macos{$name:
      bin => $bin,
      tap => $tap,
    }
  } else {
    kpi::install::linux{$name:}
  }
}
