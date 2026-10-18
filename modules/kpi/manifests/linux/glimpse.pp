# The glimpse shell's user units and its link to the private calendar sidecars.
class kpi::linux::glimpse {
  # Secret calendar sidecars live in ~/.keys/glimpse/calendars (never committed);
  # expose them to glimpse via a symlink the committed config.toml references.
  kpi::home::link { '.config/glimpse/calendars':
    target => '.keys/glimpse/calendars',
  }

  # enabled only: they start with the graphical session, not from puppet
  ['glimpse-shell', 'glimpse-lock', 'glimpse-wallpaper'].each |String $svc| {
    kpi::linux::user_service { "${svc}.service":
      ensure  => 'unmanaged',
      user    => $kpi::linux::user,
      require => Kpi::Install['glimpse-desktop-bin'],
    }
  }
}
