# A symlink ~/<path> -> ~/<target> owned by the user. The title is the path.
#   replace  false leaves whatever already sits at ~/<path> alone
define kpi::home::link (
  String[1] $target,
  String[1] $path = $title,
  String[1] $user = $kpi::home::user,
  Stdlib::Filemode $mode = '0755',
  Boolean $replace = true,
) {
  file { "${kpi::home::home_dir}/${path}":
    ensure  => link,
    owner   => $user,
    mode    => $mode,
    replace => $replace,
    target  => "${kpi::home::home_dir}/${target}",
  }
}
