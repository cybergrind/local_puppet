class kpi::home::repos {
}


define kpi::home::rdir ($user) {
  exec { $name:
    creates => $user,
    user    => $user,
    command => "/bin/mkdir -p ${name}"
  } -> file { $name: }
}

define kpi::home::rfile ($user, $source) {
  $dname = dirname($name)
  kpi::home::rfile { 'dname':
    user => $user
  }
  file { $name:
    source  => $source,
    owner   => $user,
    require => Rfile[dname],
  }
}

class kpi::home ($user = 'kpi', $home_dir = '/home/kpi'){

  if $facts['os']['family'] == 'Archinux' {
    $managehome = true
    $groups = [ 'wheel', 'audio', 'docker' ]
  } else {
    $managehome = false
    $groups = []
  }

  user { $user:
    ensure     => present,
    managehome => $managehome,
    groups     => $groups,
    shell      => '/bin/zsh',
    require    => [ Class[kpi::packages::system] ]
  }


  $home = $kpi::home::home_dir

  file { $home:
    ensure             => directory,
    recurse            => remote,
    source             => 'puppet:///modules/kpi/home',
    source_permissions => 'use',
    owner              => $user,
    # group => $user,
    require            => [ User[$user] ],
  }

  # exec { '/bin/sbt gen-ensime exit':
  #   unless => "/bin/test -e ${home}/.sbt/0.13/plugins/target",
  #   user => $user,
  #   timeout => 1800,
  #   require => [ File[$home] ],
  # }

  kpi::home_repo {"${user}-emacs": user=>$user, dir=>'.emacs.d', repo=>'cybergrind/emacs_config'}
  kpi::home_repo {"${user}-zsh": user=>$user, dir=>'.oh-my-zsh', repo=>'robbyrussell/oh-my-zsh'}
  kpi::home_symlinks {"${user}-symlinks": user=>$user}
  kpi::home::vim_setup {"${user}-vim": user=>$user}

  exec { 'pip3 install --user dot-tools':
    creates  => "${home}/.local/bin/release.py",
    provider => shell,
    cwd      => $home,
    user     => $user
  }

  File[$home] -> kpi::home::tmux_setup {"${user}-tmux":
    user => $user,
  }

  if $facts['os']['family'] == 'Archlinux' and $sshj_spec != undef {
    File[$home] -> kpi::home::sshj {"${user}-sshj":
      user => $user,
    }
  }

  if $facts['os']['family'] == 'ArchLinux' and $hiDPI {
    kpi::home::hi_dpi {"${user}-hidpi":
      user => $user,
    }
  }

  # helm env
  exec { "install helm diff":
    command => "helm plugin install https://github.com/databus23/helm-diff",
    creates => "${home}/.local/share/helm/plugins/helm-diff/bin/diff",
    require => Kpi::Install['helm'],
    user => $user,
    provider => shell,
    cwd => $home,
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

define kpi::home::sshj($user){
  $uid = $user_uid

  file { "${kpi::home::home_dir}/.local/share/systemd/":
    ensure => directory,
    recurse => true,
    owner  => $user,
    mode   => '0700',
  }
  -> file { "${kpi::home::home_dir}/.local/share/systemd/user/":
    ensure => directory,
    recurse => true,
    owner  => $user,
    mode   => '0700',
  }
  -> file { "${kpi::home::home_dir}/.local/share/systemd/user/sshj.service":
    ensure  => file,
    content => epp('kpi/sshj.epp', {
      host => $hostname,
      sshj_spec => $sshj_spec
    })
  }
  -> exec { 'sshj enable':
    user => $user,
    command => "/bin/systemctl --user enable sshj",
    environment => [
      "XDG_RUNTIME_DIR=/run/user/${uid}"
    ],
    provider => shell,
    creates => "${kpi::home::home_dir}/.config/systemd/user/default.target.wants/sshj.service"
  }
  -> exec { 'sshj start':
    user => $user,
    environment => [
      "XDG_RUNTIME_DIR=/run/user/${uid}"
    ],
    command => "/bin/systemctl --user start sshj",
    creates => "/sys/fs/cgroup/user.slice/user-${uid}.slice/user@${uid}.service/app.slice/sshj.service/",
    provider => shell,
  }
}

define kpi::home_symlinks($user){
  $id_rsa = str2bool($facts["${user}_id_rsa"])
  $keys = str2bool($facts["${user}_keys"])
  $yad = str2bool($facts["${user}_yad"])

  file { "${kpi::home::home_dir}/.ssh":
    ensure => directory,
    owner  => $user,
    mode   => '0600',
  }

  if $keys {
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
  kpi::home_link {"${user}:${path}":
    target  =>"Yandex.Disk/home/${path}",
    require => [File["${kpi::home::home_dir}/.ssh"]],
  }
}

define kpi::home::keys_links () {
  $user = $name
  $home = "/home/${user}"

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

define kpi::home::hi_dpi ($user) {
  file { "${kpi::home::home_dir}/.config/chrome-flags.conf":
    ensure  => file,
    content => epp('kpi/chromium-flags.conf.epp', {}),
    owner => $user
  }
  file { "${kpi::home::home_dir}/.config/brave-flags.conf":
    ensure  => file,
    content => epp('kpi/chromium-flags.conf.epp', {}),
    owner => $user
  }

  file { "${kpi::home::home_dir}/.Xresources":
    ensure  => file,
    content => epp('kpi/.Xresources.epp', {}),
    owner => $user
  }

  class {'kpi::packages::hidpi':}
}

define kpi::home::keys_ssh_link () {
  $i = split($name, ':')
  $user = $i[0]
  $path = $i[1]
  kpi::home_link {"${user}:${path}": target=>".keys/${path}", mode=>'0600'}
}

define kpi::home_link ($target, $mode='0755'){
  $i = split($name, ':')
  $user = $i[0]
  $src = $i[1]
  file { "${kpi::home::home_dir}/${src}":
    ensure => link,
    owner  => $user,
    mode   => $mode,
    target =>"${kpi::home::home_dir}/${target}",
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

define kpi::home::vim_setup($user, $dir=undef){
  $home = $dir ? {
    undef => $kpi::home::home_dir,
    default => $dir,
  }

  file {"${home}/.config/nvim":
    ensure => directory,
    owner  => $user,
  }
  -> file {"${home}/.config/nvim/init.vim":
    source => 'puppet:///modules/kpi/home/.vimrc',
    owner  => $user,
  }

  # "[$user] please run vim +PlugInstall +qall"

}
