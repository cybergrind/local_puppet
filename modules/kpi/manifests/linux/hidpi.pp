# hiDPI hosts (kpi::home::hidpi): X resources plus kpi::packages::hidpi.
class kpi::linux::hidpi {
  file { "${kpi::linux::home_dir}/.Xresources":
    ensure  => file,
    content => epp('kpi/.Xresources.epp', {}),
    owner   => $kpi::linux::user,
  }

  include kpi::packages::hidpi
}
