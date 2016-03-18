
node 'cbr_home' {
  notice('host cbr_home')
  include kpi::base_devel
}

node 'cbr_l' {
  include kpi::base_devel
}
