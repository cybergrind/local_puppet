class kpi::os {
  $family     = $facts['os']['family']
  $os_name    = $facts['os']['name']
  $is_arch    = $family == 'Archlinux'
  $is_darwin  = $family == 'Darwin'
  $is_windows = $family == 'windows'
}
