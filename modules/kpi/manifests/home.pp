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

define kpi::home {
  $user = $title

  user { $user:
    ensure => present,
    managehome => true,
    groups => [ 'wheel', 'audio', 'docker' ],
    shell => '/bin/zsh',
    require => [ Class[kpi::packages::system] ]
  }


  $home = "/home/$user"

  file { $home:
    ensure => directory,
    recurse => remote,
    source => 'puppet:///modules/kpi/home',
    source_permissions => use,
    owner => $user,
    group => $user,
    require => [ User[$user] ],
  }

  # exec { '/bin/sbt gen-ensime exit':
  #   unless => "/bin/test -e ${home}/.sbt/0.13/plugins/target",
  #   user => $user,
  #   timeout => 1800,
  #   require => [ File[$home] ],
  # }

  kpi::home_repo {"$user-emacs": user=>$user, dir=>'.emacs.d', repo=>'cybergrind/emacs_config'}
  kpi::home_repo {"$user-zsh": user=>$user, dir=>'.oh-my-zsh', repo=>'robbyrussell/oh-my-zsh'}
  kpi::home_symlinks {"$user-symlinks": user=>$user}
  kpi::home::vim_setup {"$user-vim": user=>$user}

  exec { "${home} flake8-string-format":
    command => "pip3 install --user flake8-string-format",
    provider => shell,
    cwd => "${home}",
    user => $user,
    creates => "${home}/.local/lib/python3.6/site-packages/flake8_string_format.py",
  }

  exec { '/bin/pip3 install --user dot-tools':
    creates => "${home}/.local/bin/release.py",
    provider => shell,
    cwd => $home,
    user => $user
  }

}

define kpi::home_symlinks($user){
  $id_rsa = str2bool($facts["${user}_id_rsa"])
  $keys = str2bool($facts["${user}_keys"])
  $yad = str2bool($facts["${user}_yad"])

  file { "/home/$user/.ssh":
    ensure => directory,
    owner => $user,
    mode => "0600",
  }

  if $keys {
    kpi::home::keys_links {$user: }
  }

  if $yad {
    kpi::home::shared_links {$user: }
  }
}

define kpi::home::shared_links {
  $user = $name
  kpi::home::shared_link { "$user:.ssh/config": }
  kpi::home::shared_link { "$user:start_work": }
  kpi::home::shared_link { "$user:.pypirc": }
}

define kpi::home::shared_link {
  $i = split($name, ":")
  $user = $i[0]
  $path = $i[1]
  kpi::home_link {"$user:$path":
    target=>"Yandex.Disk/home/$path",
    require => [File["/home/$user/.ssh"]]
  }
}

define kpi::home::keys_links {
  $user = $name
  $files = ['id_rsa', 'id_rsa.pub',
            'id_ed25519', 'id_ed25519.pub',
            'tipsikey_test_v2.pem',
            'tipsikey_test_v3.pem',
            'tipsikey_prod_v2.pem',
            'perfect_label.pem']

  $files.each |String $fileName| {
    kpi::home::keys_ssh_link {"$user:.ssh/$fileName":
      require => [File["/home/$user/.ssh"]],
    }
  }
}

define kpi::home::keys_ssh_link {
  $i = split($name, ":")
  $user = $i[0]
  $path = $i[1]
  kpi::home_link {"$user:$path": target=>".keys/$path", mode=>'0600'}
}

define kpi::home_link ($target, $mode='0755'){
  $i = split($name, ":")
  $user = $i[0]
  $src = $i[1]
  file { "/home/${user}/${src}":
    ensure => link,
    owner => $user,
    mode => $mode,
    target=>"/home/${user}/${target}",
  }
}

define kpi::home_repo($user, $dir, $repo){
  $home_dir = "/home/$user/$dir"
  exec { "git clone http://github.com/$repo.git $home_dir":
    provider => shell,
    cwd => "/home/$user",
    user => $user,
    creates => "$home_dir/.git/config",
    timeout => 1800,
    require => [ File["/home/$user"], Kpi::Install['git'] ],
  }
}

define kpi::home::vim_setup($user, $dir=undef){
  $home = $dir ? {
    undef => "/home/$user",
    default => $dir,
  }

  file {"$home/.vimrc":
    source => 'puppet:///modules/kpi/home/.vimrc',
    owner => $user,
  }
  ~> file {"$home/.config":
    owner => $user,
    ensure => directory,
  }
  -> file {"$home/.config/nvim":
    owner => $user,
    ensure => directory,
  }
  -> file {"$home/.config/nvim/init.vim":
    source => 'puppet:///modules/kpi/home/.vimrc',
    owner => $user,
  }

  # "[$user] please run vim +PlugInstall +qall"

}
