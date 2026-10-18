# The sshj reverse-tunnel user unit, rendered from kpi::home::node_hostname and
# kpi::home::sshj_spec; kpi::linux declares it only when both sshj knobs allow.
class kpi::linux::sshj {
  $user = $kpi::linux::user
  $dir = "${kpi::linux::home_dir}/.local/share/systemd"

  file { [$dir, "${dir}/user"]:
    ensure  => directory,
    recurse => true,
    owner   => $user,
    mode    => '0700',
  }
  -> file { "${dir}/user/sshj.service":
    ensure  => file,
    owner   => $user,
    content => epp('kpi/sshj.epp', {
        host      => $kpi::home::node_hostname,
        sshj_spec => $kpi::home::sshj_spec,
    }),
  }
  -> kpi::linux::user_service { 'sshj.service':
    user => $user,
  }
}
