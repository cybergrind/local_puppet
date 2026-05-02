# Second tailscaled instance for a personal tailnet, running alongside the
# distro-managed work tailscaled. Each daemon needs its own state, socket, TUN
# and UDP port so they don't collide.
class kpi::tailscale_priv (
  String $auth_key_path = "${kpi::home::home_dir}/.keys/.ts-auth.key",
  String $hostname      = "${node_hostname}-priv",
  Integer $port         = 41642,
  String $tun           = 'tspriv0',
) {
  $state_dir   = '/var/lib/tailscale-priv'
  $runtime_dir = '/run/tailscale-priv'
  $socket      = "${runtime_dir}/tailscaled.sock"
  $unit        = '/etc/systemd/system/tailscaled-priv.service'

  $unit_content = @("UNIT"/L)
    [Unit]
    Description=Tailscale node agent (private tailnet)
    Documentation=https://tailscale.com/docs/
    Wants=network-pre.target
    After=network-pre.target NetworkManager.service systemd-resolved.service

    [Service]
    # Keep this daemon out of host DNS. The work tailscaled is the sole owner
    # of /etc/resolv.conf and the resolved link config; if this daemon's DNS
    # manager autodetects "direct" mode it will overwrite resolv.conf and
    # restart systemd-resolved, wiping the work tailnet's split DNS routes.
    # Enforcement is via systemd sandboxing: the kernel/systemd refuse the
    # writes regardless of what the daemon's DNS manager tries to do.
    BindReadOnlyPaths=/etc/resolv.conf
    InaccessiblePaths=-/run/dbus/system_bus_socket
    InaccessiblePaths=-/run/systemd/resolve
    ExecStart=/usr/sbin/tailscaled --state=${state_dir}/tailscaled.state --socket=${socket} --port=${port} --tun=${tun}
    ExecStopPost=/usr/sbin/tailscaled --cleanup --socket=${socket}

    Restart=on-failure

    RuntimeDirectory=tailscale-priv
    RuntimeDirectoryMode=0755
    StateDirectory=tailscale-priv
    StateDirectoryMode=0700
    CacheDirectory=tailscale-priv
    CacheDirectoryMode=0750
    Type=notify

    [Install]
    WantedBy=multi-user.target
    | UNIT

  file { $unit:
    ensure  => file,
    content => $unit_content,
    mode    => '0644',
  }

  ~> exec { 'systemd reload tailscaled-priv':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  -> service { 'tailscaled-priv':
    ensure => running,
    enable => true,
  }

  # One-shot login using the pre-auth key. Idempotent via a durable sentinel.
  # If you ever wipe ${state_dir}, also delete the sentinel.
  $auth_sentinel = "${state_dir}/.puppet-authed"

  # Backfill the sentinel if the daemon is already authenticated — covers
  # hosts that were enrolled manually (e.g. via interactive login) or where a
  # previous puppet run completed `up` but crashed before touching the
  # sentinel. Polls `tailscale ip` for up to 10s to ride out the post-restart
  # warm-up window. If the daemon truly has no IP, this is a no-op and `up`
  # below will fire on a fresh host.
  exec { 'tailscale-priv mark-authed':
    command  => "/usr/bin/touch ${auth_sentinel}",
    onlyif   => "for i in 1 2 3 4 5 6 7 8 9 10; do /usr/bin/tailscale --socket=${socket} ip -4 >/dev/null 2>&1 && exit 0; sleep 1; done; exit 1",
    unless   => "/usr/bin/test -f ${auth_sentinel}",
    provider => shell,
    require  => Service['tailscaled-priv'],
  }

  exec { 'tailscale-priv up':
    command  => "/usr/bin/tailscale --socket=${socket} up --auth-key=\"$(cat ${auth_key_path})\" --hostname=${hostname} --accept-dns=false --ssh && /usr/bin/touch ${auth_sentinel}",
    creates  => $auth_sentinel,
    provider => shell,
    require  => Exec['tailscale-priv mark-authed'],
  }

  # Maintain runtime prefs after enrol. `tailscale up` only fires on first
  # auth, so flag changes (e.g. enabling --ssh on a host enrolled before the
  # flag existed) need to be applied via `tailscale set`. Sentinel file makes
  # it idempotent; bump the suffix if you ever change the flags below.
  $flags_sentinel = "${state_dir}/.puppet-flags-v1"
  exec { 'tailscale-priv set':
    command  => "/usr/bin/tailscale --socket=${socket} set --ssh && /usr/bin/touch ${flags_sentinel}",
    creates  => $flags_sentinel,
    provider => shell,
    require  => Exec['tailscale-priv up'],
  }
}
