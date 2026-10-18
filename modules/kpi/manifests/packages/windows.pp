# Chocolatey packages.
class kpi::packages::windows (Array[String] $pkgs) {
  kpi::install { $pkgs: }
}
