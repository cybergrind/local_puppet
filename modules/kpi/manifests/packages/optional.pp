# Nice-to-have tools (sensors, sound, python dev helpers).
class kpi::packages::optional (Array[String] $pkgs = []) {
  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}
