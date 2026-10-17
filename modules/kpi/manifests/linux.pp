# Arch-only user session setup (systemd --user units, compositor configs, the
# private tailnet). Declared from kpi::home, the counterpart of kpi::darwin; the
# per-host knobs (sshj, node_hostname, msx_hub, hidpi, uid) live on kpi::home.
class kpi::linux ($user, $home_dir) {
  $home = $home_dir

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

  # outer wk tmux server; the unit file comes from linux_home/.config/systemd/user
  kpi::linux::user_service { 'tmux.service':
    user    => $user,
    require => File[$home],
  }

  # Syncthing (data/common.yaml); the Arch package ships the user unit
  kpi::linux::user_service { 'syncthing.service':
    user    => $user,
    require => Kpi::Install['syncthing'],
  }

  if $kpi::home::msx_hub {
    kpi::linux::user_service { 'msx-hub.service':
      user    => $user,
      require => File[$home],
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
  -> kpi::linux::user_service { 'sshj.service':
    user => $user,
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
  $services = ['glimpse-shell', 'glimpse-lock', 'glimpse-wallpaper']

  # Secret calendar sidecars live in ~/.keys/glimpse/calendars (never committed);
  # expose them to glimpse via a symlink the committed config.toml references.
  kpi::home_link { "${user}:.config/glimpse/calendars":
    target  => '.keys/glimpse/calendars',
    require => File["${kpi::home::home_dir}"],
  }

  # enabled only: they start with the graphical session, not from puppet
  $services.each |String $svc| {
    kpi::linux::user_service { "${svc}.service":
      user    => $user,
      ensure  => 'unmanaged',
      require => Kpi::Install['glimpse-desktop-bin'],
    }
  }
}

# A unit of $user's systemd --user manager: the user-level counterpart of the
# `service` type, which only talks to the system manager. Runs systemctl as the
# user with their XDG_RUNTIME_DIR; linger keeps that manager up without a login.
#   enable  enable the unit (`systemctl --user enable`)
#   ensure  'running' starts it if inactive; 'unmanaged' leaves its state alone
#           (not undef: undef means "use the default" for a parameter)
define kpi::linux::user_service (
  String $user,
  String $unit = $title,
  Boolean $enable = true,
  Enum['running', 'unmanaged'] $ensure = 'running',
) {
  $systemctl = '/bin/systemctl --user'
  $env = ["XDG_RUNTIME_DIR=/run/user/${kpi::home::uid}"]

  if $enable {
    exec { "${user} enable ${unit}":
      command     => "${systemctl} enable ${unit}",
      unless      => "${systemctl} is-enabled --quiet ${unit}",
      user        => $user,
      environment => $env,
      provider    => shell,
      require     => Exec['enable-linger'],
      before      => $ensure ? { 'running' => Exec["${user} start ${unit}"], default => [] },
    }
  }

  if $ensure == 'running' {
    exec { "${user} start ${unit}":
      command     => "${systemctl} start ${unit}",
      unless      => "${systemctl} is-active --quiet ${unit}",
      user        => $user,
      environment => $env,
      provider    => shell,
      require     => Exec['enable-linger'],
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
