# The user's account and home directory on every OS: dotfiles, helper repos,
# links into ~/.keys and ~/Yandex.Disk, plus kpi::linux / kpi::darwin.
#
# Per-host settings come from Hiera (data/nodes/<hostname>.yaml, then
# data/os/<family>.yaml), not from node-scope variables.
#   skip_user     the OS owns the account (Windows), don't manage the user
#   hidpi         Xresources + kpi::packages::hidpi
#   node_hostname enables tailscale_priv; host name for the sshj tunnel
#   sshj          false to never run the sshj tunnel, even with an sshj spec
#   sshj_spec     defaults to the sshj_fact / sshj_spec facts (FACTER_SSHJ_*)
#   uid           the user's uid, for XDG_RUNTIME_DIR of systemd --user;
#                 defaults to the <user>_uid fact (facts.d/user_data.py)
class kpi::home (
  String $user = 'kpi',
  String $home_dir = '/home/kpi',
  Boolean $msx_hub = false,
  Boolean $skip_user = false,
  Boolean $hidpi = false,
  Optional[String[1]] $node_hostname = undef,
  Boolean $sshj = true,
  Optional[String[1]] $sshj_spec = [$facts['sshj_fact'], $facts['sshj_spec']].filter |$s| { $s =~ String[1] }[0],
  Integer $uid = Integer($facts["${user}_uid"].lest || { 1000 }),
) {
  include kpi::os

  $managehome = $kpi::os::is_arch
  $groups = $kpi::os::is_arch ? {
    true    => ['wheel', 'audio', 'docker'],
    default => [],
  }

  unless $skip_user {
    user { $user:
      ensure     => present,
      managehome => $managehome,
      groups     => $groups,
      shell      => '/bin/zsh',
      require    => [Class[kpi::packages::system]],
    }
  }

  $home = $kpi::home::home_dir

  # home/ is shared; linux_home/ and osx_home/ are per-OS overlays merged on top
  # of it (sourceselect => all; home/ wins on clashes).
  if $kpi::os::is_darwin {
    $home_sources = ['puppet:///modules/kpi/home', 'puppet:///modules/kpi/osx_home']
  } else {
    $home_sources = ['puppet:///modules/kpi/home', 'puppet:///modules/kpi/linux_home']
  }
  $home_require = $skip_user ? {
    true    => [],
    default => [User[$user]],
  }

  if $kpi::os::is_windows {
    # On Windows, deploy config files to AppData and user home
    file { "${home}/.config":
      ensure             => directory,
      recurse            => remote,
      source             => 'puppet:///modules/kpi/home/.config',
      source_permissions => ignore,
    }
    # Deploy specific config files for VSCode
    file { "${home}/AppData/Roaming/Code/User":
      ensure             => directory,
      recurse            => remote,
      source             => 'puppet:///modules/kpi/home/.config/Code/User',
      source_permissions => ignore,
    }
    # Deploy specific config files for Zed
    file { "${home}/AppData/Roaming/Zed":
      ensure             => directory,
      recurse            => remote,
      source             => 'puppet:///modules/kpi/home/.config/zed',
      source_permissions => ignore,
    }
    # Deploy git config
    file { "${home}/.gitconfig":
      ensure             => file,
      source             => 'puppet:///modules/kpi/home/.gitconfig',
      source_permissions => ignore,
    }
  } else {
    # Linux/macOS
    file { $home:
      ensure             => directory,
      recurse            => remote,
      source             => $home_sources,
      sourceselect       => all,
      source_permissions => 'use',
      ignore             => ['__pycache__', '*.pyc'],
      owner              => $user,
      require            => $home_require,
    }
  }

  # Linux/macOS specific operations
  unless $kpi::os::is_windows {
    kpi::home::repo { '.emacs.d': repo => 'cybergrind/emacs_config' }
    kpi::home::repo { '.oh-my-zsh': repo => 'robbyrussell/oh-my-zsh' }
    kpi::home::repo { '.fzf': repo => 'junegunn/fzf' }
    contain kpi::home::symlinks

    # ~/Yandex.Disk is synced by Syncthing (and, while moving off it, by the
    # Yandex.Disk client on Linux). .stignore is per machine, never synced.
    # Machine-specific patterns go into .stignore-local, which is never in git
    # or synced; puppet only creates it empty.
    file { "${home}/Yandex.Disk":
      ensure => directory,
      owner  => $user,
    }
    -> file { "${home}/Yandex.Disk/.stignore-local":
      ensure  => file,
      owner   => $user,
      replace => false,
      content => '',
    }
    -> file { "${home}/Yandex.Disk/.stignore":
      ensure  => file,
      owner   => $user,
      content => @(STIGNORE),
        // managed by puppet (kpi::home): Yandex.Disk client metadata, macOS clutter
        /.sync
        /.localized
        (?d).DS_Store
        /.stignore-local
        #include .stignore-local
        | STIGNORE
    }

    exec { 'uv tool install dot-tools':
      creates  => "${home}/.local/bin/release.py",
      provider => shell,
      cwd      => $home,
      user     => $user,
    }

    contain kpi::home::tmux
    File[$home] -> Class['kpi::home::tmux']

    if $kpi::os::is_darwin {
      File[$home] -> class { 'kpi::darwin':
        user     => $user,
        home_dir => $home,
      }
    }

    if $kpi::os::is_arch {
      class { 'kpi::linux':
        user     => $user,
        home_dir => $home,
      }
    }
  }
}
