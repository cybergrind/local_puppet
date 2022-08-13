class kpi::system {
  case $::os['name'] {
    'Archlinux': {
      file { '/etc/X11/xorg.conf.d/50-synaptics.conf':
        source => 'puppet:///modules/kpi/50-synaptics.conf',
        require => [ Kpi::Install['xf86-input-synaptics'] ],
      }
    }
  }
}
