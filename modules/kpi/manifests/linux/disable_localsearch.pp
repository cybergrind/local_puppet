# localsearch (the renamed tracker-miners) is a hard dependency of nautilus, which
# is pulled in by xdg-desktop-portal-gnome -> niri. We keep the portal but kill the
# filesystem indexer: every localsearch D-Bus service delegates through
# SystemdService=localsearch-*.service, so masking the user units blocks both the
# XDG autostart and on-demand D-Bus activation.
class kpi::linux::disable_localsearch {
  $user = $kpi::linux::user
  $dir = "${kpi::linux::home_dir}/.config/systemd/user"
  $env = ["XDG_RUNTIME_DIR=/run/user/${kpi::home::uid}"]
  $units = ['localsearch-3.service', 'localsearch-control-3.service', 'localsearch-writeback-3.service']

  file { $dir:
    ensure => directory,
    owner  => $user,
  }

  $units.each |String $unit| {
    file { "${dir}/${unit}":
      ensure  => link,
      target  => '/dev/null',
      owner   => $user,
      require => File[$dir],
      notify  => Exec['localsearch daemon-reload'],
    }
  }

  exec { 'localsearch daemon-reload':
    user        => $user,
    command     => '/bin/systemctl --user daemon-reload',
    environment => $env,
    provider    => shell,
    refreshonly => true,
  }
  # Stop any indexer already running this session (stop still works on a masked unit).
  -> exec { 'localsearch stop':
    user        => $user,
    command     => "/bin/systemctl --user stop ${join($units, ' ')}",
    environment => $env,
    provider    => shell,
    onlyif      => '/bin/systemctl --user is-active --quiet localsearch-3.service',
  }
}
