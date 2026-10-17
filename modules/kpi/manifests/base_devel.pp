# Dev toolchain list: kpi::base_devel::pkgs in data/os/<family>.yaml.
class kpi::base_devel (Array[String] $pkgs = []) {
  include kpi::os
  include kpi::packages
  include kpi::packages::system
  include kpi::packages::optional
  include kpi::repos

  # $python2 = [ 'python2', 'python2-numpy', 'ipython2', 'python2-virtualenv' ]
  # kpi::install { $python2: }
  kpi::install { $pkgs: }

  if $kpi::os::is_arch {
    file {"/root": ensure => directory}
  }
}
