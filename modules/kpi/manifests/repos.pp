class kpi::repos () {
  include kpi::os
  case $kpi::os::family {
    'Archlinux': {
      # file { '/etc/pacman.conf':
      #   source => 'puppet:///modules/kpi/pacman.conf',
      # }
      exec {"pacman -Sy":
        provider => shell,
        user => 'root',
        onlyif => '[ $(( $(date +%s) - $(stat -c %Y /var/lib/pacman/sync) )) -gt 1000 ]',
      }
    }
    'Darwin': {
      # counterpart of `pacman -Sy`: puppet installs run with HOMEBREW_NO_AUTO_UPDATE,
      # so refresh brew's index here, at most once a day
      $home = "/Users/${facts['identity']['user']}"
      $stamp = "${home}/Library/Caches/Homebrew/.kpi-brew-update"
      exec { 'brew update':
        command     => "/opt/homebrew/bin/brew update --quiet && /usr/bin/touch '${stamp}'",
        onlyif      => "/bin/test -z \"$(/usr/bin/find '${stamp}' -mtime -1 2>/dev/null)\"",
        environment => ["HOME=${home}"],
        provider    => shell,
        timeout     => 600,
      }
    }
  }
}
