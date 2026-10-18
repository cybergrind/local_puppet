# Extra packages for hiDPI hosts (kpi::home::hidpi).
class kpi::packages::hidpi (Array[String] $pkgs) {
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}
