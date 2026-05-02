# Second tailscaled instance for a personal tailnet, running alongside the
# distro-managed work tailscaled. Each daemon needs its own state, socket, TUN
# and UDP port so they don't collide.
class kpi::tailscale_priv (
  String $user          = 'kpi',
  String $user_key_path = "${kpi::home::home_dir}/.keys/.ts-auth.key",
  String $auth_key_path = '/root/.keys/.ts-auth.key',
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
    # Keep this daemon out of host DNS. The work tailscaled is the sole
    # owner of /etc/resolv.conf and the resolved link config. In "direct"
    # DNS mode tailscaled would (a) overwrite /etc/resolv.conf and
    # (b) shell out to `systemctl restart systemd-resolved`, both of which
    # clobber the work tailnet's split DNS. We block both paths:
    #   - BindReadOnlyPaths makes /etc/resolv.conf unwritable in this
    #     unit's mount namespace.
    #   - NoExecPaths prevents the daemon from fork-execing systemctl,
    #     so the resolved-restart path can't fire.
    # We deliberately leave D-Bus and resolved sockets accessible: Tailscale
    # SSH spawns user sessions via PAM/logind over D-Bus, and blocking that
    # silently breaks incoming SSH connections.
    BindReadOnlyPaths=/etc/resolv.conf
    NoExecPaths=/usr/bin/systemctl
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

  ~> service { 'tailscaled-priv':
    ensure => running,
    enable => true,
  }

  # Stage the pre-auth key in root's home so the puppet-driven `up` exec
  # reads it without crossing user boundaries. Two-step because the user's
  # key may live on per-user encfs/FUSE — root cannot read those, but the
  # owning user can. We do the read as ${user} into /tmp (via puppet's
  # `user =>`), then root installs it into /root/.keys with correct mode
  # and removes the staging file.
  $staged_key = '/tmp/.tspriv-auth.key.staging'

  file { '/root/.keys':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }

  # Step 1: as ${user}, copy the (possibly encfs-mounted) key into /tmp
  # with restrictive mode. Skipped when the root copy is already in place
  # so we don't pointlessly stage on every run.
  exec { 'tailscale-priv stage-from-user':
    command  => "/usr/bin/install -m 0600 ${user_key_path} ${staged_key}",
    user     => $user,
    creates  => $auth_key_path,
    onlyif   => "/usr/bin/test -s ${user_key_path}",
    provider => shell,
  }

  # Step 2: as root, install the staged copy into /root/.keys (root:root,
  # 0600) and remove the staging file. Conditional on the staged file
  # actually existing — if step 1 was skipped (root copy already present),
  # this is a no-op too.
  exec { 'tailscale-priv stage-auth-key':
    command  => "/usr/bin/install -m 0600 -o root -g root ${staged_key} ${auth_key_path} && /bin/rm -f ${staged_key}",
    onlyif   => "/usr/bin/test -s ${staged_key}",
    provider => shell,
    require  => [File['/root/.keys'], Exec['tailscale-priv stage-from-user']],
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
    require  => [Exec['tailscale-priv mark-authed'], Exec['tailscale-priv stage-auth-key']],
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
