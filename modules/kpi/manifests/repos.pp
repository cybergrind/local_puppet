class kpi::repos () {
  case $::os['name'] {
    'Archlinux': {
      # file { '/etc/pacman.conf':
      #   source => 'puppet:///modules/kpi/pacman.conf',
      # }
      exec {"pacman -Sy":
        provider => shell,
        user => 'root',
        onlyif => '[ $(( $(date +%s) - $(stat -c %Y /var/lib/pacman/sync) )) -gt 1000 ]',
      }
    }
  }
}
