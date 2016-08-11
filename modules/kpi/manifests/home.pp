class kpi::home::repos {

}


define rdir ($user) {
  exec { $name:
    creates => $user,
    user => $user,
    command => "/bin/mkdir -p ${name}"
  } -> file { $name: }
}

define rfile ($user, $source) {
  $dname = dirname($name)
  rfile { dname:
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
    owner => $user,
    require => [ User[$user] ],
  }

  exec { '/bin/sbt gen-ensime exit':
    unless => "/bin/test -e ${home}/.sbt/0.13/plugins/target",
    user => $user,
    timeout => 1800,
    require => [ File[$home] ],
  }

  home_repo {"$user-emacs": user=>$user, dir=>'.emacs.d', repo=>'cybergrind/emacs_config'}
  home_repo {"$user-zsh": user=>$user, dir=>'.oh-my-zsh', repo=>'robbyrussell/oh-my-zsh'}
  home_symlinks {"$user-symlinks": user=>$user}
  kpi::home::vim_setup {"$user-vim": user=>$user}
}

define home_symlinks($user){
  $id_rsa = str2bool($facts["${user}_id_rsa"])
  $keys = str2bool($facts["${user}_keys"])
  $dropbox = str2bool($facts["${user}_dropbox"])

  file { "/home/$user/.ssh":
    ensure => directory,
    owner => $user,
    mode => "0600",
  }

  if $keys {
    keys_links {$user: }
  }

  if $dropbox {
    dropbox_links {$user: }
  }
}

define dropbox_links {
  $user = $name
  dropbox_link { "$user:.ssh/config": }
  dropbox_link { "$user:start_work": }
  dropbox_link { "$user:.pypirc": }
}

define dropbox_link {
  $i = split($name, ":")
  $user = $i[0]
  $path = $i[1]
  home_link {"$user:$path":
    target=>"Dropbox/home/$path",
    require => [File["/home/$user/.ssh"]]
  }
}

define keys_links {
  $user = $name
  $files = ['id_rsa', 'id_rsa.pub',
            'tipsikey_test_v2.pem',
            'tipsikey_test_v3.pem',
            'tipsikey_prod_v2.pem']

  $files.each |String $fileName| {
    keys_ssh_link {"$user:.ssh/$fileName":
      require => [File["/home/$user/.ssh"]],
    }
  }
}

define keys_ssh_link {
  $i = split($name, ":")
  $user = $i[0]
  $path = $i[1]
  home_link {"$user:$path": target=>".keys/$path", mode=>'0600'}
}

define home_link ($target, $mode='0755'){
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

define home_repo($user, $dir, $repo){
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
  } ->

  exec { "git clone https://github.com/junegunn/fzf.git ${home}/.fzf":
    provider => shell,
    cwd => "${home}",
    user => $user,
    creates => "${home}/.fzf",
    require => [ File[$home], Kpi::Install['git'] ],
  }
  # "[$user] please run vim +PluginInstall +qall"

}
