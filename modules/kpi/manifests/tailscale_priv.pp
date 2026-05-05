# Second tailscaled instance for a personal tailnet, running alongside the
# distro-managed work tailscaled. Each daemon needs its own state, socket, TUN
# and UDP port so they don't collide.
class kpi::tailscale_priv (
  String $user          = 'kpi',
  String $user_key_path = "${kpi::home::home_dir}/.keys/.ts-auth.key",
  String $auth_key_path = '/root/.keys/.ts-auth.key',
  String $hostname      = "${node_hostname}-priv",
  Integer $port         = 41642,
  String $socks5_addr   = 'localhost:1055',
) {
  $state_dir        = '/var/lib/tailscale-priv'
  $runtime_dir      = '/run/tailscale-priv'
  $socket           = "${runtime_dir}/tailscaled.sock"
  $unit             = '/etc/systemd/system/tailscaled-priv.service'
  $ensure_up_script = '/usr/local/sbin/tailscale-priv-ensure-up'

  $unit_content = @("UNIT"/L)
    [Unit]
    Description=Tailscale node agent (private tailnet)
    Documentation=https://tailscale.com/docs/
    Wants=network-pre.target
    After=network-pre.target NetworkManager.service systemd-resolved.service

    [Service]
    # Userspace-networking mode: the daemon runs its own gVisor netstack
    # instead of installing a kernel TUN. This avoids the routing-table-52
    # collision that two kernel-mode tailscaleds on the same host inflict on
    # each other (both daemons claim 100.100.100.100/32 in table 52, both
    # use fwmark 0x80000, last writer wins → host DNS lands at the wrong
    # daemon → netstack TX path wedges over time). See TS_HANDOFF.md.
    #
    # Outbound from host: `tspriv ssh/nc <peer>` via the LocalAPI socket,
    # or any process via ALL_PROXY=socks5://${socks5_addr}.
    # Inbound from peers: the netstack proxies all TCP on the tailnet IP to
    # 127.0.0.1:<port> on this host, so any service bound to localhost is
    # reachable as <hostname>-priv:<port> from the priv tailnet.
    ExecStart=/usr/sbin/tailscaled --state=${state_dir}/tailscaled.state --socket=${socket} --port=${port} --tun=userspace-networking --socks5-server=${socks5_addr}
    # Self-heal: if the daemon comes up needing login (node key expired, control
    # plane requested re-auth, fresh state dir), re-run `tailscale up` with the
    # pre-staged auth key. No-op when BackendState is Running with no AuthURL,
    # so it's safe to run on every start. `-` prefix swallows failures so a
    # missing key file or transient localapi error doesn't take the unit down.
    ExecStartPost=-${ensure_up_script} ${socket} ${auth_key_path} ${hostname}
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

  file { $ensure_up_script:
    ensure => file,
    source => 'puppet:///modules/kpi/tailscale-priv-ensure-up',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { $unit:
    ensure  => file,
    content => $unit_content,
    mode    => '0644',
    require => File[$ensure_up_script],
  }

  # Use raw `systemctl` execs instead of the `service` resource because
  # Puppet's systemd provider auto-detection is flaky on some of our hosts
  # ("Provider systemd is not functional on this host"), even where systemd
  # is up and running. systemctl shells out the same way either way.
  ~> exec { 'systemd reload tailscaled-priv':
    command     => '/bin/systemctl daemon-reload && /bin/systemctl restart tailscaled-priv',
    refreshonly => true,
  }

  exec { 'tailscaled-priv enable+start':
    command => '/bin/systemctl enable --now tailscaled-priv',
    unless  => '/bin/systemctl is-active tailscaled-priv && /bin/systemctl is-enabled tailscaled-priv',
    require => [File[$unit], Exec['systemd reload tailscaled-priv']],
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
    require  => Exec['tailscaled-priv enable+start'],
  }

  # In userspace-networking mode the daemon installs no kernel netfilter
  # rules, so --netfilter-mode is moot. We drop it from `up`/`set` (kept in
  # the historical record via the sentinel bump v2 → v3, which forces `set`
  # to re-fire on hosts that had the old flags applied).
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
  $flags_sentinel = "${state_dir}/.puppet-flags-v3"
  exec { 'tailscale-priv set':
    command  => "/usr/bin/tailscale --socket=${socket} set --ssh && /usr/bin/touch ${flags_sentinel}",
    creates  => $flags_sentinel,
    provider => shell,
    require  => Exec['tailscale-priv up'],
  }
}
