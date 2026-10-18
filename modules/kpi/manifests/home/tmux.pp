# tmux configs rendered from one template: tmux2.conf for the outer wk server,
# tmux.conf for every other tmux.
class kpi::home::tmux {
  $dir = "${kpi::home::home_dir}/.config/tmux"

  file { "${dir}/tmux2.conf":
    ensure  => file,
    owner   => $kpi::home::user,
    content => epp('kpi/tmux.conf.epp', {
        unique_part => file('kpi/tmux.wk.conf'),
    }),
  }
  -> file { "${dir}/tmux.conf":
    ensure  => file,
    owner   => $kpi::home::user,
    content => epp('kpi/tmux.conf.epp', {
        unique_part => file('kpi/tmux.general.conf'),
    }),
  }
}
