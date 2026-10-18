# The package groups for this OS; the lists are module Hiera data
# (data/common.yaml, data/os/<family>.yaml).
class kpi::packages {
  include kpi::os

  unless $kpi::os::is_windows {
    include kpi::packages::common
  }

  if $kpi::os::is_arch {
    include kpi::packages::linux
    include kpi::packages::hyprland
    include kpi::packages::niri
    include kpi::packages::glimpse
  } elsif $kpi::os::is_windows {
    include kpi::packages::windows
  } else {
    include kpi::packages::macos
  }
}
