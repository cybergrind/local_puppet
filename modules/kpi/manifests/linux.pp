# Arch-only user session setup (systemd --user units, compositor configs, the
# private tailnet). Declared from kpi::home, the counterpart of kpi::darwin; the
# per-host knobs (sshj, node_hostname, msx_hub, hidpi, uid) live on kpi::home.
class kpi::linux ($user, $home_dir) {
  $home = $home_dir
  $uid = $kpi::home::uid

  if $kpi::home::sshj and $kpi::home::sshj_spec != undef {
    File[$home] -> kpi::linux::sshj {"${user}-sshj":
      user => $user,
    }
  }

  if $kpi::home::node_hostname != undef {
    File[$home] -> class { 'kpi::tailscale_priv':
      user_key_path => "${home}/.keys/.ts-auth.key",
    }
  }

  File[$home] -> kpi::linux::hyprland {"${user}-hyprland":
    user => $user,
  }

  File[$home] -> kpi::linux::glimpse {"${user}-glimpse":
    user => $user,
  }

  File[$home] -> kpi::linux::disable_localsearch {"${user}-localsearch":
    user => $user,
  }

  exec { 'enable-linger':
    command  => "/bin/loginctl enable-linger ${user}",
    provider => shell,
    unless   => "/bin/loginctl show-user ${user} | /bin/grep -q Linger=yes",
  }

  exec { 'tmux-service enable':
    user        => $user,
    command     => '/bin/systemctl --user enable tmux',
    environment => ["XDG_RUNTIME_DIR=/run/user/${uid}"],
    provider    => shell,
    creates     => "${home}/.config/systemd/user/default.target.wants/tmux.service",
    require     => File[$home],
  }
  -> exec { 'tmux-service start':
    user        => $user,
    command     => '/bin/systemctl --user start tmux',
    environment => ["XDG_RUNTIME_DIR=/run/user/${uid}"],
    provider    => shell,
    unless      => '/usr/bin/tmux -L wk has-session -t wk 2>/dev/null',
  }

  if $kpi::home::msx_hub {
    exec { 'msx-hub-service enable':
      user        => $user,
      command     => '/bin/systemctl --user enable msx-hub',
      environment => ["XDG_RUNTIME_DIR=/run/user/${uid}"],
      provider    => shell,
      creates     => "${home}/.config/systemd/user/default.target.wants/msx-hub.service",
      require     => File[$home],
    }
    -> exec { 'msx-hub-service start':
      user        => $user,
      command     => '/bin/systemctl --user start msx-hub',
      environment => ["XDG_RUNTIME_DIR=/run/user/${uid}"],
      provider    => shell,
      unless      => '/usr/bin/docker ps --format {{.Names}} | /usr/bin/grep -qx msx-hub',
    }
  }

  if $kpi::home::hidpi {
    kpi::linux::hi_dpi {"${user}-hidpi":
      user => $user,
    }
  }

  # if $facts['os']['family'] == 'ArchLinux' and $user == 'kpi' {
  #   # helm env
  #   exec { "install helm diff":
  #     command => "helm plugin install https://github.com/databus23/helm-diff",
  #     creates => "${home}/.local/share/helm/plugins/helm-diff/bin/diff",
  #     require => Kpi::Install['helm'],
  #     user => $user,
  #     provider => shell,
  #     cwd => $home,
  #   }
  # }

  file { "${home}/.config/chrome-flags.conf":
    ensure  => file,
    content => epp('kpi/chromium-flags.conf.epp', {}),
    owner => $user
  }
}

define kpi::linux::sshj($user){
  $uid = $kpi::home::uid

  file { "${kpi::home::home_dir}/.local/share/systemd/":
    ensure => directory,
    recurse => true,
    owner  => $user,
    mode   => '0700',
  }
  -> file { "${kpi::home::home_dir}/.local/share/systemd/user/":
    ensure => directory,
    recurse => true,
    owner  => $user,
    mode   => '0700',
  }
  -> file { "${kpi::home::home_dir}/.local/share/systemd/user/sshj.service":
    ensure  => file,
    content => epp('kpi/sshj.epp', {
      host => $kpi::home::node_hostname,
      sshj_spec => $kpi::home::sshj_spec
    })
  }
  -> exec { 'sshj enable':
    user => $user,
    command => "/bin/systemctl --user enable sshj",
    environment => [
      "XDG_RUNTIME_DIR=/run/user/${uid}"
    ],
    provider => shell,
    creates => "${kpi::home::home_dir}/.config/systemd/user/default.target.wants/sshj.service"
  }
  -> exec { 'sshj start':
    user => $user,
    environment => [
      "XDG_RUNTIME_DIR=/run/user/${uid}"
    ],
    command => "/bin/systemctl --user start sshj",
    creates => "/sys/fs/cgroup/user.slice/user-${uid}.slice/user@${uid}.service/app.slice/sshj.service/",
    provider => shell,
  }
}

# localsearch (the renamed tracker-miners) is a hard dependency of nautilus, which
# is pulled in by xdg-desktop-portal-gnome -> niri. We keep the portal but kill the
# filesystem indexer: every localsearch D-Bus service delegates through
# SystemdService=localsearch-*.service, so masking the user units blocks both the
# XDG autostart and on-demand D-Bus activation.
define kpi::linux::disable_localsearch($user){
  $uid = $kpi::home::uid
  $units = ['localsearch-3.service', 'localsearch-control-3.service', 'localsearch-writeback-3.service']

  file { "${kpi::home::home_dir}/.config/systemd/user":
    ensure => directory,
    owner  => $user,
  }

  $units.each |String $unit| {
    file { "${kpi::home::home_dir}/.config/systemd/user/${unit}":
      ensure  => link,
      target  => '/dev/null',
      owner   => $user,
      require => File["${kpi::home::home_dir}/.config/systemd/user"],
      notify  => Exec['localsearch daemon-reload'],
    }
  }

  exec { 'localsearch daemon-reload':
    user        => $user,
    command     => '/bin/systemctl --user daemon-reload',
    environment => ["XDG_RUNTIME_DIR=/run/user/${uid}"],
    provider    => shell,
    refreshonly => true,
  }
  # Stop any indexer already running this session (stop still works on a masked unit).
  -> exec { 'localsearch stop':
    user        => $user,
    command     => "/bin/systemctl --user stop ${join($units, ' ')}",
    environment => ["XDG_RUNTIME_DIR=/run/user/${uid}"],
    provider    => shell,
    onlyif      => '/bin/systemctl --user is-active --quiet localsearch-3.service',
  }
}

define kpi::linux::hyprland($user){
  file { "${kpi::home::home_dir}/.config/hypr/hyprland.conf":
    ensure  => file,
    content => epp('kpi/hyprland.conf', {}),
    owner => $user,
    require => File["${kpi::home::home_dir}"]
  }
}

define kpi::linux::glimpse ($user) {
  $uid = $kpi::home::uid
  $env = ["XDG_RUNTIME_DIR=/run/user/${uid}"]
  $services = ['glimpse-shell', 'glimpse-lock', 'glimpse-wallpaper']

  # Secret calendar sidecars live in ~/.keys/glimpse/calendars (never committed);
  # expose them to glimpse via a symlink the committed config.toml references.
  kpi::home_link { "${user}:.config/glimpse/calendars":
    target  => '.keys/glimpse/calendars',
    require => File["${kpi::home::home_dir}"],
  }

  $services.each |String $svc| {
    exec { "${svc} enable":
      user        => $user,
      command     => "/bin/systemctl --user enable ${svc}.service",
      environment => $env,
      provider    => shell,
      unless      => "/bin/systemctl --user is-enabled ${svc}.service",
      require     => Kpi::Install['glimpse-desktop-bin'],
    }
  }
}

define kpi::linux::hi_dpi ($user) {
  file { "${kpi::home::home_dir}/.Xresources":
    ensure  => file,
    content => epp('kpi/.Xresources.epp', {}),
    owner => $user
  }

  class {'kpi::packages::hidpi':}
}
