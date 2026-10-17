# macOS-only user session setup. Declared from kpi::home, the macOS counterpart
# of the Arch-only systemd/hyprland/glimpse block there. Puppet runs as the
# user on macOS (no sudo), so everything here lives in the user's domain; the
# few root-only bits are in kpi::darwin::system, which ./run applies via sudo.
class kpi::darwin ($user, $home_dir) {
  $agents_dir = "${home_dir}/Library/LaunchAgents"
  $uid = $facts['identity']['uid']

  file { $agents_dir:
    ensure => directory,
    owner  => $user,
  }

  # Keyboard remaps for every keyboard; hidutil mappings don't survive a reboot,
  # so a LaunchAgent re-applies them at login.
  #  - Caps Lock -> Left Control, same as ctrl:nocaps on Linux
  #  - Right Command -> F18, bound below to "next input source" (Right Alt's
  #    grp:toggle on Linux)
  kpi::darwin::launch_agent { 'com.kpi.keyboard':
    program_arguments => [
      '/usr/bin/hidutil', 'property', '--set',
      join([
        '{"UserKeyMapping":[',
        '{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0},',
        '{"HIDKeyboardModifierMappingSrc":0x7000000E7,"HIDKeyboardModifierMappingDst":0x70000006D}',
        ']}',
      ]),
    ],
  }

  # Replaced by com.kpi.keyboard; drop once every Mac has run this.
  exec { 'launchctl remove com.kpi.capslock-ctrl':
    command => "/bin/launchctl bootout gui/${uid}/com.kpi.capslock-ctrl",
    onlyif  => "/bin/launchctl print gui/${uid}/com.kpi.capslock-ctrl",
  }
  -> file { "${agents_dir}/com.kpi.capslock-ctrl.plist":
    ensure => absent,
  }

  # F18 (key code 79, function-key flag 0x800000) = "Select next source in
  # Input menu", symbolic hotkey 61. activateSettings applies it without a logout.
  exec { 'input source hotkey F18':
    command  => join([
      "/usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61",
      "'{ enabled = 1; value = { parameters = (65535, 79, 8388608); type = standard; }; }'",
      '&& /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u',
    ], ' '),
    unless   => join([
      '/usr/bin/defaults export com.apple.symbolichotkeys -',
      '| /usr/bin/plutil -extract AppleSymbolicHotKeys.61.value.parameters.1 raw -o - -',
      '| /usr/bin/grep -qx 79',
    ], ' '),
    provider => shell,
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

  # Syncthing (data/common.yaml), the counterpart of its systemd user unit on
  # Linux; launchd restarts it if it exits. GUI on http://127.0.0.1:8384.
  kpi::darwin::launch_agent { 'com.kpi.syncthing':
    program_arguments => [
      '/opt/homebrew/bin/syncthing', 'serve', '--no-browser', '--no-restart',
      "--log-file=${home_dir}/Library/Logs/syncthing.log",
    ],
    keep_alive        => true,
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

  # No "smart" typing: curly quotes, em dashes and autocorrect mangle code and
  # shell commands typed outside the terminal.
  ['NSAutomaticQuoteSubstitutionEnabled', 'NSAutomaticDashSubstitutionEnabled',
    'NSAutomaticSpellingCorrectionEnabled'].each |String $key| {
    kpi::darwin::default { "no ${key}":
      domain => 'NSGlobalDomain', key => $key, value => false,
    }
  }

  # Finder shows every extension and dotfile; it only rereads these on restart.
  kpi::darwin::default { 'show all extensions':
    domain => 'NSGlobalDomain', key => 'AppleShowAllExtensions', value => true,
  }
  ~> exec { 'restart Finder':
    command     => '/usr/bin/killall Finder',
    refreshonly => true,
  }
  kpi::darwin::default { 'show hidden files':
    domain => 'com.apple.finder', key => 'AppleShowAllFiles', value => true,
    notify => Exec['restart Finder'],
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
}

# Root-only macOS setup. Not part of any node: ./run applies it with
# `sudo puppet apply -e 'include kpi::darwin::system'` when it's out of date.
class kpi::darwin::system () {
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
