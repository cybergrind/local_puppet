# Arch packages: pkgs_nox for every machine, pkgs for the X/Wayland desktop.
class kpi::packages::linux (Array[String] $pkgs_nox, Array[String] $pkgs) {
  kpi::install { $pkgs_nox:
    require => [Class[kpi::packages::system]],
  }

  kpi::install { $pkgs:
    require => [Class[kpi::packages::system]],
  }
}
