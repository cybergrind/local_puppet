# yay (pacman + AUR) backend of kpi::install, run as the unprivileged yay user.
# Packages already in the kpi_packages fact (pacman -Qq, facts.d/
# installed_packages.py) get no exec at all.
define kpi::install::linux {
  include kpi::repos
  include kpi::packages::system

  unless $name in $facts['kpi_packages'].lest || { [] } {
    exec { $name:
      unless      => "/usr/bin/pacman -Qq ${name}",
      user        => 'yay',
      cwd         => '/tmp',
      timeout     => 1800,
      command     => "/usr/bin/yay -S --noconfirm ${name}",
      require     => [Class[kpi::packages::system]],
      environment => ['HOME=/home/yay'],
    }
  }
}
