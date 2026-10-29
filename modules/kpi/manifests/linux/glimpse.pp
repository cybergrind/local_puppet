# The glimpse shell's session target and its link to the private calendar sidecars.
class kpi::linux::glimpse {
  # Secret calendar sidecars live in ~/.keys/glimpse/calendars (never committed);
  # expose them to glimpse via a symlink the committed config.toml references.
  kpi::home::link { '.config/glimpse/calendars':
    target => '.keys/glimpse/calendars',
  }

  # glimpse-session.target wants the panel, wallpaper, idle and lock units. It is
  # enabled only: it starts with graphical-session.target (niri's startup line).
  kpi::linux::user_service { 'glimpse-session.target':
    ensure  => 'unmanaged',
    user    => $kpi::linux::user,
    require => Kpi::Install['glimpse-desktop-bin'],
  }

  # glimpse-weather picks °C/°F from LC_MEASUREMENT, but .zprofile's
  # LC_ALL=en_US.UTF-8 (imported into the user manager) means Fahrenheit.
  # C.UTF-8 is metric and always present, unlike locales left to locale.gen.
  $dropin = "${kpi::linux::home_dir}/.config/systemd/user/glimpse-weather.service.d"
  file { $dropin:
    ensure => directory,
    owner  => $kpi::linux::user,
  }
  file { "${dropin}/units.conf":
    content => "[Service]\nUnsetEnvironment=LC_ALL\nEnvironment=LANG=en_US.UTF-8 LC_MEASUREMENT=C.UTF-8\n",
    owner   => $kpi::linux::user,
    notify  => Exec['glimpse-weather restart'],
  }
  exec { 'glimpse-weather restart':
    command     => '/bin/systemctl --user daemon-reload && /bin/systemctl --user try-restart glimpse-weather.service',
    user        => $kpi::linux::user,
    environment => ["XDG_RUNTIME_DIR=/run/user/${kpi::home::uid}"],
    provider    => shell,
    refreshonly => true,
  }
}
