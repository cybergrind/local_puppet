# macOS formulae and casks, plus macFUSE and the FUSE filesystems built on it.
class kpi::packages::macos (Array[String] $pkgs, Array[String] $casks) {
  kpi::install { 'git': bin => 'noinstall' }  # ships with Xcode CLT

  # encfs/sshfs need macFUSE; the cask runs a sudo'ed .pkg installer, which
  # can't prompt from inside puppet, so ./run installs it interactively beforehand.
  kpi::install { 'macfuse': cask => true }
  -> kpi::install { ['gromgit/fuse/encfs-mac', 'gromgit/fuse/sshfs-mac']: }

  kpi::install { $pkgs: }
  kpi::install { $casks: cask => true }
}
