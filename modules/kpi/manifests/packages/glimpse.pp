# The glimpse desktop shell (its user units are set up by kpi::linux::glimpse).
class kpi::packages::glimpse {
  kpi::install { 'glimpse-desktop-bin': }
}
