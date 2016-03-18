class kpi::repos () {
  case $::os['name'] {
    'Archlinux': {
      file { '/etc/pacman.conf':
        source => 'puppet:///modules/kpi/pacman.conf',
      }
    }
  }
}
