# The glimpse desktop shell (its session target is set up by kpi::linux::glimpse).
class kpi::packages::glimpse {
  kpi::install { 'glimpse-desktop-bin': }
}
