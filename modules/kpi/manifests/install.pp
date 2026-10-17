# Packages already in the kpi_packages / kpi_brew_taps facts (facts.d/
# installed_packages.py) get no exec at all. Anything else is checked against
# brew itself (`brew list` / `brew tap`), which also covers aliases like gpg.
# A fully qualified 'owner/tap/formula' name declares its tap automatically.
define kpi::install::macos ($bin=undef, $tap=false, $cask=false) {
  include kpi::repos
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

  # brew lists formulae/casks by short name and taps in lowercase
  $installed = $tap ? {
    true    => downcase($name) in $facts['kpi_brew_taps'].lest || { [] },
    default => $name.split('/')[-1] in $facts['kpi_packages'].lest || { [] },
  }

  unless $bin == 'noinstall' or $installed {
    exec { "brew ${name}":
      command     => $command,
      unless      => $unless,
      timeout     => 1800,
      environment => ["HOME=/Users/${facts['identity']['user']}", 'HOMEBREW_NO_AUTO_UPDATE=1'],
      require     => [Class['kpi::repos']] + $requires,
    }
  }
}

# Packages already in the kpi_packages fact (pacman -Qq, facts.d/
# installed_packages.py) get no exec at all.
define kpi::install::linux () {
  include kpi::repos
  include kpi::packages::system

  unless $name in $facts['kpi_packages'].lest || { [] } {
    exec { $name:
      unless => "/usr/bin/pacman -Qq ${name}",
      user => 'yay',
      cwd => "/tmp",
      timeout => 1800,
      command => "/usr/bin/yay -S --noconfirm ${name}",
      require => [ Class[kpi::packages::system] ],
      environment => ['HOME=/home/yay'],
    }
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
