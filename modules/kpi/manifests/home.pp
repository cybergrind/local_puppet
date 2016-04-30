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
    require => [ Class[kpi::packages], ]
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
}


define home_repo($user, $dir, $repo){
  $home_dir = "/home/$user/$dir"
  exec { "git clone http://github.com/$repo.git $home_dir":
    provider => shell,
    cwd => "/home/$user",
    creates => "$home_dir/.git/config",
    timeout => 1800,
    require => [ File["/home/$user"], Kpi::Install['git'] ],
  }
}
