define kpi::install::macos ($bin=undef, $tap=false, $cask=false) {
  info("Install ${name}")
  if $cask {
    $command = "/opt/homebrew/bin/brew install --cask ${name}"
  } elsif $tap {
    $command = "/opt/homebrew/bin/brew tap ${name}"
  } else {
    $command = "/opt/homebrew/bin/brew install ${name}"
  }

  case $bin {
    undef: {
      exec {$name:
        creates => "/opt/homebrew/bin/${name}",
        command => $command,
        environment => ["HOME=/Users/kpi"],
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
        environment => ["HOME=/Users/kpi"],
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

define kpi::install::windows ($bin=undef) {
  info("Install ${name} on Windows")

  case $bin {
    undef: {
      package {$name:
        ensure   => installed,
        provider => chocolatey,
      }
    }
    'noinstall': {}
    'skip': {
      package {$name:
        ensure   => installed,
        provider => chocolatey,
      }
    }
    default: {
      exec {$name:
        creates => $bin,
        command => "choco install -y ${name}",
        provider => powershell,
      }
    }
  }
}

define kpi::install ($bin=undef, $tap=false, $cask=false) {
  if $facts['os']['family'] == 'Darwin' {
    kpi::install::macos{$name:
      bin => $bin,
      tap => $tap,
      cask => $cask,
    }
  } elsif $facts['os']['family'] == 'windows' {
    kpi::install::windows{$name:
      bin => $bin,
    }
  } else {
    kpi::install::linux{$name:}
  }
}
