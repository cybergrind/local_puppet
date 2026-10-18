# Installs a package with the OS's package manager: yay on Arch, brew on macOS,
# chocolatey on Windows. Use it instead of `package` so one manifest works on
# every OS.
#   bin   'noinstall' declares the package without installing it; on Windows a
#         path installs via `choco install` unless that file exists
#   tap   (macOS) the title is a tap to add, not a formula
#   cask  (macOS) install a cask
define kpi::install (
  Optional[String[1]] $bin = undef,
  Boolean $tap = false,
  Boolean $cask = false,
) {
  include kpi::os

  if $kpi::os::is_darwin {
    kpi::install::macos { $name:
      bin  => $bin,
      tap  => $tap,
      cask => $cask,
    }
  } elsif $kpi::os::is_windows {
    kpi::install::windows { $name:
      bin => $bin,
    }
  } else {
    kpi::install::linux { $name: }
  }
}
