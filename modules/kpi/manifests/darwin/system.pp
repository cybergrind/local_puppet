# Root-only macOS setup. Not part of any node: ./run applies it with
# `sudo puppet apply -e 'include kpi::darwin::system'` when it's out of date.
class kpi::darwin::system {
  # Touch ID for sudo, also inside tmux (pam_reattach reconnects the session to
  # the GUI). sudo_local is included by /etc/pam.d/sudo and survives OS updates.
  # If pam_reattach.so goes missing sudo can't initialise PAM at all, so keep
  # pam-reattach in data/os/Darwin.yaml while this line references it.
  file { '/etc/pam.d/sudo_local':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0444',
    content => @(PAM),
      # managed by puppet (kpi::darwin::system)
      auth       optional       /opt/homebrew/lib/pam/pam_reattach.so ignore_ssh
      auth       sufficient     pam_tid.so
      | PAM
  }

  # No Spotlight indexing on any volume.
  exec { 'disable spotlight':
    command => '/usr/bin/mdutil -a -i off',
    unless  => "/usr/bin/mdutil -s / | /usr/bin/grep -q 'Indexing disabled'",
  }
}
