$base = '/home'
$user_uid = 1000
$hiDPI = false

$use_wayland = true
$use_ksnip = false

$node_hostname = undef
$skip_user = false
$sshj_spec = if $facts['sshj_fact'] and $facts['sshj_fact'] != '' {
  $facts['sshj_fact']
} elsif $facts['sshj_spec'] and $facts['sshj_spec'] != '' {
  $facts['sshj_spec']
} else {
  undef
}

node 'home' {
  include kpi::base_devel
  class {'kpi::home': }
}

node 'tpad' {
  $hiDPI = true
  include kpi::base_devel
  class {'kpi::home': }
}

node 'dm4' {
  include kpi::base_devel
  class {'kpi::home': }
}

node 'xx' {
  include kpi::base_devel
  $node_hostname = 'xx'
  class {'kpi::home': }
}

node 'zz' {
  $hiDPI = true
  include kpi::base_devel
  class {'kpi::home': }
}

node 'cybergrinds-macbook-pro.local' {
  include kpi::base_devel
  class {'kpi::home':
    user => 'kpi',
    home_dir => '/Users/kpi'
  }
}

node 'cybergrinds-macbook-pro.tail6384d.ts.net' {
  include kpi::base_devel
  class {'kpi::home':
    user => 'kpi',
    home_dir => '/Users/kpi'
  }
}

node 'ww' {
  # Windows host - lightweight config with editor setups
  $skip_user = true
  $sshj_spec = undef
  include kpi::packages::windows

  class {'kpi::home':
    user => 'kpi',
    home_dir => 'C:/Users/kpi'
  }
}

node 'ww-wsl' {
  # WSL host - full development environment
  $sshj_spec = undef

  include kpi::base_devel

  class {'kpi::home':
    user => 'kpi',
    home_dir => '/home/kpi'
  }
}
