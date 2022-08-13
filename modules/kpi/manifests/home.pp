class kpi::home::repos {
}


define kpi::home::rdir ($user) {
  exec { $name:
    creates => $user,
    user => $user,
    command => "/bin/mkdir -p ${name}"
  } -> file { $name: }
}

define kpi::home::rfile ($user, $source) {
  $dname = dirname($name)
  kpi::home::rfile { dname:
    user => $user
  }
  file { $name:
    source => $source,
    owner => $user,
    require => Rfile[dname],
  }
}

define kpi::home ($base = '/home'){
  $user = $title
  if $facts['os']['family'] == 'linux' {
    $managehome = true
    $groups = [ 'wheel', 'audio', 'docker' ]
  } else {
    $managehome = false
    $groups = []
  }

  user { $user:
    ensure => present,
    managehome => $managehome,
    groups => $groups,
    shell => '/bin/zsh',
    require => [ Class[kpi::packages::system] ]
  }


  $home = "${base}/$user"

  file { $home:
    ensure => directory,
    recurse => remote,
    source => 'puppet:///modules/kpi/home',
    source_permissions => use,
    owner => $user,
    # group => $user,
    require => [ User[$user] ],
  }

  # exec { '/bin/sbt gen-ensime exit':
  #   unless => "/bin/test -e ${home}/.sbt/0.13/plugins/target",
  #   user => $user,
  #   timeout => 1800,
  #   require => [ File[$home] ],
  # }

  kpi::home_repo {"$user-emacs": user=>$user, dir=>'.emacs.d', repo=>'cybergrind/emacs_config', base=>$base}
  kpi::home_repo {"$user-zsh": user=>$user, dir=>'.oh-my-zsh', repo=>'robbyrussell/oh-my-zsh', base=>$base}
  kpi::home_symlinks {"$user-symlinks": user=>$user, base=>$base}
  kpi::home::vim_setup {"$user-vim": user=>$user, base=>$base}

  exec { "${home} flake8-string-format":
    command => "pip3 install --user flake8-string-format",
    provider => shell,
    cwd => "${home}",
    user => $user,
    creates => "${home}/.local/lib/python3.6/site-packages/flake8_string_format.py",
  }

  exec { 'pip3 install --user dot-tools':
    creates => "${home}/.local/bin/release.py",
    provider => shell,
    cwd => $home,
    user => $user
  }

  File[$home] -> kpi::home::tmux_setup {"$user-tmux":
    user => $user,
    base => $base
  }
}

define kpi::home::tmux_setup($user, $base){
  file { "${base}/${user}/.config/tmux/tmux2.conf":
    ensure => file,
    content => epp('kpi/tmux.conf.epp', {
      unique_part => file('kpi/tmux.wk.conf')
    })
  } ->
  file { "${base}/${user}/.config/tmux/tmux.conf":
    ensure => file,
    content => epp('kpi/tmux.conf.epp', {
      unique_part => file('kpi/tmux.general.conf')
    })
  }
}

define kpi::home_symlinks($user, $base){
  $id_rsa = str2bool($facts["${user}_id_rsa"])
  $keys = str2bool($facts["${user}_keys"])
  $yad = str2bool($facts["${user}_yad"])

  file { "${base}/$user/.ssh":
    ensure => directory,
    owner => $user,
    mode => "0600",
  }

  if $keys {
    kpi::home::keys_links {$user: base=>$base}
  }

  if $yad {
    kpi::home::shared_links {$user: base=>$base}
  }
}

define kpi::home::shared_links ($base){
  $user = $name
  kpi::home::shared_link { "$user:.ssh/config": base=>$base}
  kpi::home::shared_link { "$user:start_work": base=>$base}
  kpi::home::shared_link { "$user:.pypirc": base=>$base}
}

define kpi::home::shared_link($base) {
  $i = split($name, ":")
  $user = $i[0]
  $path = $i[1]
  kpi::home_link {"$user:$path":
    target=>"Yandex.Disk/home/$path",
    require => [File["${base}/$user/.ssh"]],
    base=>$base
  }
}

define kpi::home::keys_links ($base) {
  $user = $name
  $files = ['id_rsa', 'id_rsa.pub',
            'id_ed25519', 'id_ed25519.pub',
            'tipsikey_test_v2.pem',
            'tipsikey_test_v3.pem',
            'tipsikey_prod_v2.pem',
            'perfect_label.pem']

  $files.each |String $fileName| {
    kpi::home::keys_ssh_link {"$user:.ssh/$fileName":
      require => [File["${base}/$user/.ssh"]],
      base => $base,
    }
  }
}

define kpi::home::keys_ssh_link ($base) {
  $i = split($name, ":")
  $user = $i[0]
  $path = $i[1]
  kpi::home_link {"$user:$path": target=>".keys/$path", mode=>'0600', base=>$base}
}

define kpi::home_link ($target, $mode='0755', $base){
  $i = split($name, ":")
  $user = $i[0]
  $src = $i[1]
  file { "${base}/${user}/${src}":
    ensure => link,
    owner => $user,
    mode => $mode,
    target=>"${base}/${user}/${target}",
  }
}

define kpi::home_repo($user, $dir, $repo, $base){
  $home_dir = "${base}/$user/$dir"
  exec { "git clone http://github.com/$repo.git $home_dir":
    provider => shell,
    cwd => "${base}/$user",
    user => $user,
    creates => "$home_dir/.git/config",
    timeout => 1800,
    require => [ File["${base}/$user"], Kpi::Install['git'] ],
  }
}

define kpi::home::vim_setup($user, $dir=undef, $base){
  $home = $dir ? {
    undef => "${base}/$user",
    default => $dir,
  }

  file {"$home/.config/nvim":
    owner => $user,
    ensure => directory,
  }
  -> file {"$home/.config/nvim/init.vim":
    source => 'puppet:///modules/kpi/home/.vimrc',
    owner => $user,
  }

  # "[$user] please run vim +PlugInstall +qall"

}
