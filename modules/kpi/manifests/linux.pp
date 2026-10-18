# Arch-only user session setup (systemd --user units, compositor configs, the
# private tailnet). Declared from kpi::home, the counterpart of kpi::darwin; the
# per-host knobs (sshj, node_hostname, msx_hub, hidpi, uid) live on kpi::home.
class kpi::linux (String $user, String $home_dir) {
  $home = $home_dir

  if $kpi::home::sshj and $kpi::home::sshj_spec != undef {
    contain kpi::linux::sshj
    File[$home] -> Class['kpi::linux::sshj']
  }

  if $kpi::home::node_hostname != undef {
    contain kpi::tailscale_priv
    File[$home] -> Class['kpi::tailscale_priv']
  }

  contain kpi::linux::hyprland
  contain kpi::linux::glimpse
  contain kpi::linux::disable_localsearch
  File[$home] -> [Class['kpi::linux::hyprland'], Class['kpi::linux::glimpse'], Class['kpi::linux::disable_localsearch']]

  exec { 'enable-linger':
    command  => "/bin/loginctl enable-linger ${user}",
    provider => shell,
    unless   => "/bin/loginctl show-user ${user} | /bin/grep -q Linger=yes",
  }

  # CAP_SYS_NICE (for gamescope), handed out at login by pam_cap (kpi::system)
  file { '/etc/security/capability.conf':
    content => "cap_sys_nice ${user}\n",
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
    contain kpi::linux::hidpi
  }

  file { "${home}/.config/chrome-flags.conf":
    ensure  => file,
    content => epp('kpi/chromium-flags.conf.epp', {}),
    owner   => $user,
  }
}
