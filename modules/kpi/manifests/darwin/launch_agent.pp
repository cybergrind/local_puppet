# A per-user LaunchAgent: renders the plist and (re)loads it into the gui domain.
define kpi::darwin::launch_agent (
  Array[String] $program_arguments,
  Hash[String, String] $environment = {},
  Boolean $abandon_process_group = false,
  Boolean $keep_alive = false,
) {
  $user = $kpi::darwin::user
  $uid = $facts['identity']['uid']
  $plist = "${kpi::darwin::agents_dir}/${name}.plist"

  file { $plist:
    ensure  => file,
    owner   => $user,
    mode    => '0644',
    content => epp('kpi/launch_agent.plist.epp', {
      label                 => $name,
      program_arguments     => $program_arguments,
      environment           => $environment,
      abandon_process_group => $abandon_process_group,
      keep_alive            => $keep_alive,
    }),
    require => File[$kpi::darwin::agents_dir],
  }
  ~> exec { "launchctl reload ${name}":
    command     => "/bin/launchctl bootout gui/${uid}/${name}; sleep 1; /bin/launchctl bootstrap gui/${uid} '${plist}'",
    provider    => shell,
    refreshonly => true,
  }
  -> exec { "launchctl load ${name}":
    command => "/bin/launchctl bootstrap gui/${uid} '${plist}'",
    unless  => "/bin/launchctl print gui/${uid}/${name}",
  }
}
