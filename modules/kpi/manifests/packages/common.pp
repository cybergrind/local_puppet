# Tools with the same package name in brew and pacman/AUR (Linux + macOS).
class kpi::packages::common (Array[String] $pkgs) {
  kpi::install { $pkgs: }
}
