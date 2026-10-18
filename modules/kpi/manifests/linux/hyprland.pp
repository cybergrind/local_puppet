# hyprland.conf, rendered per host (kpi::home::node_hostname tweaks).
class kpi::linux::hyprland {
  file { "${kpi::linux::home_dir}/.config/hypr/hyprland.conf":
    ensure  => file,
    content => epp('kpi/hyprland.conf.epp', {}),
    owner   => $kpi::linux::user,
  }
}
