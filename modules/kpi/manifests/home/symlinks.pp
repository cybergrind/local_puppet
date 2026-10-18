# Links from ~ into ~/.keys (ssh keys, kube configs) and ~/Yandex.Disk/home
# (shared dotfiles), each only when the <user>_keys / <user>_yad fact says that
# tree is there (facts.d/user_data.py).
class kpi::home::symlinks {
  $user = $kpi::home::user
  $home = $kpi::home::home_dir

  file { "${home}/.ssh":
    ensure => directory,
    owner  => $user,
    mode   => '0700',
  }

  if str2bool($facts["${user}_keys"]) {
    # never clobber a real key that already sits in ~/.ssh (e.g. on macOS)
    ['id_rsa', 'id_rsa.pub', 'id_ed25519', 'id_ed25519.pub', 'perfect_label.pem'].each |String $key| {
      kpi::home::link { ".ssh/${key}":
        target  => ".keys/.ssh/${key}",
        mode    => '0600',
        replace => false,
        require => File["${home}/.ssh"],
      }
    }

    file { "${home}/.kube":
      ensure => directory,
      owner  => $user,
    }
    ['octo-eks1', 'octo-eks2', 'octo-cloud', 'octo-hz-de1', 'octo-hz-fi1'].each |String $config| {
      kpi::home::link { ".kube/${config}":
        target  => ".keys/octo/${config}",
        require => File["${home}/.kube"],
      }
    }
    kpi::home::link { '.kube/pl-eks':
      target  => '.keys/perfect_label/pl-eks',
      require => File["${home}/.kube"],
    }
  }

  if str2bool($facts["${user}_yad"]) {
    # an existing file wins (e.g. a machine's own ~/start_work)
    ['.ssh/config', 'start_work', '.pypirc'].each |String $path| {
      kpi::home::link { $path:
        target  => "Yandex.Disk/home/${path}",
        replace => false,
        require => File["${home}/.ssh"],
      }
    }
  }
}
