$base = '/home'

node 'home' {
  include kpi::base_devel
  class {'kpi::home': }
}

node 'tpad' {
  include kpi::base_devel
  class {'kpi::home': }
}

node 'dm4' {
  include kpi::base_devel
  class {'kpi::home': }
}

node 'zz' {
  include kpi::base_devel
  class {'kpi::home': }
}

node 'kpis-mbp.local' {
  include kpi::base_devel
  class {'kpi::home':
    user => 'kpi',
    home_dir => '/Users/kpi'
  }
}
