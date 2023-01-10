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

node 'xx' {
  include kpi::base_devel
  class {'kpi::home': }
}

node 'kpis-mbp' {
  include kpi::base_devel
  class {'kpi::home':
    user => 'kpi',
    home_dir => '/Users/kpi'
  }
}
