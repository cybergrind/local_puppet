node 'home' {
  notice('host cbr_home')
  $user = 'kpi'
  $id_rsa = str2bool($facts["${user}_id_rsa"])
  notice("Fact kpi_id_rsa = ${id_rsa}")
  include kpi::base_devel
  kpi::home { 'kpi': }
}

node 'cbr_l' {
  include kpi::base_devel
  kpi::home { 'kpi': }
}

node 'dm4' {
  include kpi::base_devel
  kpi::home { 'kpi': }
}
