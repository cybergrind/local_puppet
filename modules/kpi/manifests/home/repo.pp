# A checkout of github.com/<repo> at ~/<dir> (the title), cloned once and then
# left to the user (no pulls).
define kpi::home::repo (
  Pattern[/\A[\w.-]+\/[\w.-]+\z/] $repo,
  String[1] $dir = $title,
  String[1] $user = $kpi::home::user,
) {
  $repo_dir = "${kpi::home::home_dir}/${dir}"

  exec { "git clone ${repo}":
    command  => "git clone https://github.com/${repo}.git ${repo_dir}",
    provider => shell,
    cwd      => $kpi::home::home_dir,
    user     => $user,
    creates  => "${repo_dir}/.git/config",
    timeout  => 1800,
    require  => [File[$kpi::home::home_dir], Kpi::Install['git']],
  }
}
