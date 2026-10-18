# chocolatey backend of kpi::install.
#   bin  undef/'skip': a chocolatey package; 'noinstall': nothing; a path:
#        `choco install` unless that file exists
define kpi::install::windows (
  Optional[String[1]] $bin = undef,
) {
  info("Install ${name} on Windows")

  case $bin {
    undef, 'skip': {
      package { $name:
        ensure   => installed,
        provider => chocolatey,
      }
    }
    'noinstall': {}
    default: {
      exec { $name:
        creates  => $bin,
        command  => "choco install -y ${name}",
        provider => powershell,
      }
    }
  }
}
