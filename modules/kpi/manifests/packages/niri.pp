# The niri session and its portals.
class kpi::packages::niri (Array[String] $pkgs) {
  kpi::install { $pkgs: }
}
