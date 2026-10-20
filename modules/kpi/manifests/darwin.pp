# macOS-only user session setup. Declared from kpi::home, the macOS counterpart
# of the Arch-only systemd/hyprland/glimpse block there. Puppet runs as the
# user on macOS (no sudo), so everything here lives in the user's domain; the
# few root-only bits are in kpi::darwin::system, which ./run applies via sudo.
class kpi::darwin (String $user, String $home_dir) {
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
  # The value is XML because the old-style plist syntax stores everything as
  # strings, which the hotkey reader ignores; unless also rejects such an entry.
  $hotkey_61 = 'AppleSymbolicHotKeys.61'
  $hotkey_f18 = join([
    '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array>',
    '<integer>65535</integer><integer>79</integer><integer>8388608</integer></array>',
    '<key>type</key><string>standard</string></dict></dict>',
  ])
  exec { 'input source hotkey F18':
    command  => join([
      "/usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '${hotkey_f18}'",
      '&& /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u',
    ], ' '),
    unless   => join([
      'h() { /usr/bin/defaults export com.apple.symbolichotkeys - | /usr/bin/plutil -extract "$1" raw -o - -; };',
      "test \"$(h ${hotkey_61}.enabled)\" = true && test \"$(h ${hotkey_61}.value.parameters.1)\" = 79",
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
    domain => 'NSGlobalDomain',
    key    => 'KeyRepeat',
    value  => 2,
  }
  kpi::darwin::default { 'initial key repeat':
    domain => 'NSGlobalDomain',
    key    => 'InitialKeyRepeat',
    value  => 15,
  }
  kpi::darwin::default { 'press and hold':
    domain => 'NSGlobalDomain',
    key    => 'ApplePressAndHoldEnabled',
    value  => false,
  }

  # No "smart" typing: curly quotes, em dashes and autocorrect mangle code and
  # shell commands typed outside the terminal.
  ['NSAutomaticQuoteSubstitutionEnabled', 'NSAutomaticDashSubstitutionEnabled',
    'NSAutomaticSpellingCorrectionEnabled'].each |String $key| {
    kpi::darwin::default { "no ${key}":
      domain => 'NSGlobalDomain',
      key    => $key,
      value  => false,
    }
  }

  # Finder shows every extension and dotfile; it only rereads these on restart.
  kpi::darwin::default { 'show all extensions':
    domain => 'NSGlobalDomain',
    key    => 'AppleShowAllExtensions',
    value  => true,
  }
  ~> exec { 'restart Finder':
    command     => '/usr/bin/killall Finder',
    refreshonly => true,
  }
  kpi::darwin::default { 'show hidden files':
    domain => 'com.apple.finder',
    key    => 'AppleShowAllFiles',
    value  => true,
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
