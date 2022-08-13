$base = '/home'

node 'home' {
  include kpi::base_devel
  kpi::home { 'kpi': }
}

node 'tpad' {
  include kpi::base_devel
  kpi::home { 'kpi': }
}

node 'dm4' {
  include kpi::base_devel
  kpi::home { 'kpi': }
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
