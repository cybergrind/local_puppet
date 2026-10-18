# What kpi::install needs before it can install anything (yay on Arch).
class kpi::packages::system {
  include kpi::os

  if $kpi::os::is_arch {
    include kpi::packages::system::linux
  }
}
