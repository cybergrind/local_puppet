# A unit of $user's systemd --user manager: the user-level counterpart of the
# `service` type, which only talks to the system manager. Runs systemctl as the
# user with their XDG_RUNTIME_DIR; linger keeps that manager up without a login.
#   enable  enable the unit (`systemctl --user enable`)
#   ensure  'running' starts it if inactive; 'unmanaged' leaves its state alone
#           (not undef: undef means "use the default" for a parameter)
define kpi::linux::user_service (
  String $user,
  Enum['running', 'unmanaged'] $ensure = 'running',
  String $unit = $title,
  Boolean $enable = true,
) {
  $systemctl = '/bin/systemctl --user'
  $env = ["XDG_RUNTIME_DIR=/run/user/${kpi::home::uid}"]
  $start = $ensure ? {
    'running' => [Exec["${user} start ${unit}"]],
    default   => [],
  }

  if $enable {
    exec { "${user} enable ${unit}":
      command     => "${systemctl} enable ${unit}",
      unless      => "${systemctl} is-enabled --quiet ${unit}",
      user        => $user,
      environment => $env,
      provider    => shell,
      require     => Exec['enable-linger'],
      before      => $start,
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
