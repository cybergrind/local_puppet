# Every host gets the same entry point. What differs per host lives in Hiera,
# not here: modules/kpi/data/nodes/<hostname>.yaml (only for hosts that differ),
# then data/os/<family>.yaml, then data/common.yaml. A new machine needs no
# change at all unless it has its own settings.
node default {
  include kpi::base_devel
  include kpi::home
}
