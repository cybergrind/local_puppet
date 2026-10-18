# The Hyprland session and its helpers.
class kpi::packages::hyprland (Array[String] $pkgs) {
  kpi::install { $pkgs: }
}
