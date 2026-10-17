# Per-host settings come from Hiera (data/nodes/<hostname>.yaml, then
# data/os/<family>.yaml), not from node-scope variables.
#   skip_user     the OS owns the account (Windows), don't manage the user
#   hidpi         Xresources + kpi::packages::hidpi
#   node_hostname enables tailscale_priv; host name for the sshj tunnel
#   sshj          false to never run the sshj tunnel, even with an sshj spec
#   sshj_spec     defaults to the sshj_fact / sshj_spec facts (FACTER_SSHJ_*)
#   uid           the user's uid, for XDG_RUNTIME_DIR of systemd --user
class kpi::home (
  String $user = 'kpi',
  String $home_dir = '/home/kpi',
  Boolean $msx_hub = false,
  Boolean $skip_user = false,
  Boolean $hidpi = false,
  Optional[String[1]] $node_hostname = undef,
  Boolean $sshj = true,
  Optional[String[1]] $sshj_spec = [$facts['sshj_fact'], $facts['sshj_spec']].filter |$s| { $s =~ String[1] }[0],
  Integer $uid = 1000,
) {
  include kpi::os

  $managehome = $kpi::os::is_arch
  $groups = $kpi::os::is_arch ? {
    true    => [ 'wheel', 'audio', 'docker' ],
    default => [],
  }

  unless $skip_user {
    user { $user:
      ensure     => present,
      managehome => $managehome,
      groups     => $groups,
      shell      => '/bin/zsh',
      require    => [ Class[kpi::packages::system] ]
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
      # group => $user,
      require            => $skip_user ? { true => [], default => [User[$user]] },
    }
  }

  # Linux/macOS specific operations
  unless $kpi::os::is_windows {
    kpi::home_repo {"${user}-emacs": user=>$user, dir=>'.emacs.d', repo=>'cybergrind/emacs_config'}
    kpi::home_repo {"${user}-zsh": user=>$user, dir=>'.oh-my-zsh', repo=>'robbyrussell/oh-my-zsh'}
    kpi::home_repo {"${user}-fzf": user=>$user, dir=>'.fzf', repo=>'junegunn/fzf'}
    kpi::home_symlinks {"${user}-symlinks": user=>$user}

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
      user     => $user
    }

    File[$home] -> kpi::home::tmux_setup {"${user}-tmux":
      user => $user,
    }

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

define kpi::home::tmux_setup($user){
  file { "${kpi::home::home_dir}/.config/tmux/tmux2.conf":
    ensure  => file,
    content => epp('kpi/tmux.conf.epp', {
      unique_part => file('kpi/tmux.wk.conf')
    })
  }
  -> file { "${kpi::home::home_dir}/.config/tmux/tmux.conf":
    ensure  => file,
    content => epp('kpi/tmux.conf.epp', {
      unique_part => file('kpi/tmux.general.conf')
    })
  }
}

define kpi::home_symlinks($user){
  $keys = str2bool($facts["${user}_keys"])
  $yad = str2bool($facts["${user}_yad"])

  file { "${kpi::home::home_dir}/.ssh":
    ensure => directory,
    owner  => $user,
    mode   => '0600',
  }

  if $keys and !$kpi::os::is_windows {
    kpi::home::keys_links {$user:}
  }

  if $yad {
    kpi::home::shared_links {$user:}
  }
}

define kpi::home::shared_links (){
  $user = $name
  kpi::home::shared_link { "${user}:.ssh/config": }
  kpi::home::shared_link { "${user}:start_work": }
  kpi::home::shared_link { "${user}:.pypirc": }
}

define kpi::home::shared_link() {
  $i = split($name, ':')
  $user = $i[0]
  $path = $i[1]
  # an existing file wins (e.g. a machine's own ~/start_work)
  kpi::home_link {"${user}:${path}":
    target  =>"Yandex.Disk/home/${path}",
    replace => false,
    require => [File["${kpi::home::home_dir}/.ssh"]],
  }
}

define kpi::home::keys_links () {
  $user = $name
  $home = $kpi::home::home_dir

  $files = ['id_rsa', 'id_rsa.pub',
            'id_ed25519', 'id_ed25519.pub',
            'perfect_label.pem']

  $files.each |String $filename| {
    kpi::home::keys_ssh_link {"${user}:.ssh/${filename}":
      require => [File["${kpi::home::home_dir}/.ssh"]],
    }
  }

  file {"${home}/.kube":
    ensure => directory,
    owner  => $user,
  }

  ['octo-eks1', 'octo-eks2', 'octo-cloud', 'octo-hz-de1', 'octo-hz-fi1'].each |String $fname| {
    kpi::home_link { "${user}:.kube/${fname}":
      target => ".keys/octo/${fname}",
      require => [File["${home}/.kube"]]
    }
  }
  kpi::home_link { "${user}:.kube/pl-eks":
    target => ".keys/perfect_label/pl-eks",
    require => [File["${home}/.kube"]]
  }
}

define kpi::home::keys_ssh_link () {
  $i = split($name, ':')
  $user = $i[0]
  $path = $i[1]
  # never clobber a real key that already sits in ~/.ssh (e.g. on macOS)
  kpi::home_link {"${user}:${path}": target=>".keys/${path}", mode=>'0600', replace=>false}
}

define kpi::home_link ($target, $mode='0755', $replace=true){
  $i = split($name, ':')
  $user = $i[0]
  $src = $i[1]
  file { "${kpi::home::home_dir}/${src}":
    ensure  => link,
    owner   => $user,
    mode    => $mode,
    replace => $replace,
    target  =>"${kpi::home::home_dir}/${target}",
  }
}

define kpi::home_repo($user, $dir, $repo){
  $repo_dir = "${kpi::home::home_dir}/${dir}"
  exec { "git clone http://github.com/${repo}.git ${repo_dir}":
    provider => shell,
    cwd      => $kpi::home::home_dir,
    user     => $user,
    creates  => "${repo_dir}/.git/config",
    timeout  => 1800,
    require  => [ File[$kpi::home::home_dir], Kpi::Install['git'] ],
  }
}

