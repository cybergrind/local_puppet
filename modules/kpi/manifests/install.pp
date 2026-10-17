# Idempotency is checked against brew itself (`brew list` / `brew tap`), so it
# works for formulae without a same-named binary (py3cairo, nvm, aliases like gpg).
# A fully qualified 'owner/tap/formula' name declares its tap automatically.
define kpi::install::macos ($bin=undef, $tap=false, $cask=false) {
  $brew = '/opt/homebrew/bin/brew'

  if $tap {
    $command = "${brew} tap ${name}"
    $unless  = "${brew} tap | /usr/bin/grep -qix '${name}'"
  } elsif $cask {
    $command = "${brew} install --cask ${name}"
    $unless  = "${brew} list --cask ${name}"
  } else {
    $command = "${brew} install ${name}"
    $unless  = "${brew} list --formula ${name}"
  }

  if !$tap and $name =~ /^([^\/]+\/[^\/]+)\/[^\/]+$/ {
    $tap_name = $1
    ensure_resource('kpi::install::macos', $tap_name, { tap => true })
    $requires = [Kpi::Install::Macos[$tap_name]]
  } else {
    $requires = []
  }

  unless $bin == 'noinstall' {
    exec { "brew ${name}":
      command     => $command,
      unless      => $unless,
      timeout     => 1800,
      environment => ["HOME=/Users/${facts['identity']['user']}", 'HOMEBREW_NO_AUTO_UPDATE=1'],
      require     => $requires,
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
  include kpi::os
  if $kpi::os::is_darwin {
    kpi::install::macos{$name:
      bin => $bin,
      tap => $tap,
      cask => $cask,
    }
  } elsif $kpi::os::is_windows {
    kpi::install::windows{$name:
      bin => $bin,
    }
  } else {
    kpi::install::linux{$name:}
  }
}
