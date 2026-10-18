# Everything a dev machine needs before the home directory: repos, package
# groups and the per-OS toolchain (kpi::base_devel::pkgs in data/os/<family>.yaml).
class kpi::base_devel (Array[String] $pkgs = []) {
  include kpi::os
  include kpi::packages
  include kpi::packages::system
  include kpi::packages::optional
  include kpi::repos

  kpi::install { $pkgs: }

  if $kpi::os::is_arch {
    file { '/root': ensure => directory }
  }
}
