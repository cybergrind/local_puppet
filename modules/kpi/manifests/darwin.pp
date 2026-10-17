# macOS-only user session setup. Declared from kpi::home, the macOS counterpart
# of the Arch-only systemd/hyprland/glimpse block there. Puppet runs as the
# user on macOS (no sudo), so everything here lives in the user's domain.
class kpi::darwin ($user, $home_dir) {
  $agents_dir = "${home_dir}/Library/LaunchAgents"

  file { $agents_dir:
    ensure => directory,
    owner  => $user,
  }

  # Caps Lock -> Left Control for every keyboard, same as ctrl:nocaps on Linux.
  # hidutil mappings don't survive a reboot, so a LaunchAgent re-applies them.
  kpi::darwin::launch_agent { 'com.kpi.capslock-ctrl':
    program_arguments => [
      '/usr/bin/hidutil', 'property', '--set',
      '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}]}',
    ],
  }

  # Outer tmux server, the macOS counterpart of tmux.service on Linux. tmux
  # daemonizes, so launchd must not reap the process group when the client exits.
  kpi::darwin::launch_agent { 'com.kpi.tmux-wk':
    program_arguments     => [
      '/opt/homebrew/bin/tmux', '-L', 'wk', '-f', "${home_dir}/.config/tmux/tmux2.conf",
      'new-session', '-d', '-s', 'wk',
    ],
    environment           => {
      'PATH' => '/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin',
      'LANG' => 'en_US.UTF-8',
    },
    abandon_process_group => true,
  }

  # Fast key repeat; press-and-hold pops up the accent menu instead of repeating
  # (breaks hjkl in vim). Both apply from the next login.
  kpi::darwin::default { 'key repeat':
    domain => 'NSGlobalDomain', key => 'KeyRepeat', value => 2,
  }
  kpi::darwin::default { 'initial key repeat':
    domain => 'NSGlobalDomain', key => 'InitialKeyRepeat', value => 15,
  }
  kpi::darwin::default { 'press and hold':
    domain => 'NSGlobalDomain', key => 'ApplePressAndHoldEnabled', value => false,
  }

  # brew's docker CLI doesn't look in /opt/homebrew for its compose/buildx plugins.
  file { ["${home_dir}/.docker", "${home_dir}/.docker/cli-plugins"]:
    ensure => directory,
    owner  => $user,
  }
  ['docker-compose', 'docker-buildx'].each |String $plugin| {
    file { "${home_dir}/.docker/cli-plugins/${plugin}":
      ensure => link,
      owner  => $user,
      target => "/opt/homebrew/opt/${plugin}/bin/${plugin}",
    }
  }

  class { 'kpi::darwin::iterm': }
}

# Dynamic profile inheriting from the stock "Default" profile; it only flips
# Left Option to Esc+ so tmux sees M-<key> (outer tmux binds M-0..M-9).
# Right Option stays Normal for typing accented/special characters.
class kpi::darwin::iterm () {
  $user = $kpi::darwin::user
  $profiles_dir = "${kpi::darwin::home_dir}/Library/Application Support/iTerm2/DynamicProfiles"
  $guid = 'kpi-puppet-default'

  file { $profiles_dir:
    ensure => directory,
    owner  => $user,
  }
  -> file { "${profiles_dir}/kpi.json":
    ensure => file,
    owner  => $user,
    source => 'puppet:///modules/kpi/darwin/iterm2-profile.json',
  }
  -> kpi::darwin::default { 'iterm default profile':
    domain => 'com.googlecode.iterm2', key => 'Default Bookmark Guid', value => $guid,
  }
}

# One `defaults write`, skipped when `defaults read` already returns the value.
define kpi::darwin::default (String $domain, String $key, Variant[Boolean, Integer, String] $value) {
  $type = $value ? {
    Boolean => 'bool',
    Integer => 'int',
    default => 'string',
  }
  # `defaults read` prints booleans as 1/0
  $expected = $value ? {
    true    => '1',
    false   => '0',
    default => String($value),
  }

  exec { "defaults ${domain} ${key}":
    command  => "/usr/bin/defaults write ${domain} '${key}' -${type} '${value}'",
    unless   => "/bin/test \"$(/usr/bin/defaults read ${domain} '${key}' 2>/dev/null)\" = '${expected}'",
    provider => shell,
  }
}

# A per-user LaunchAgent: renders the plist and (re)loads it into the gui domain.
define kpi::darwin::launch_agent (
  Array[String] $program_arguments,
  Hash[String, String] $environment = {},
  Boolean $abandon_process_group = false,
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
