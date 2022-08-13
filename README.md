### macos

```
brew install findutils
export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
```


### coding snippets


```puppet
case $::os['name'] {
  'Archlinux': {
    file { '/etc/pacman.conf':
      source => 'puppet:///modules/kpi/pacman.conf',
    }
    exec {"pacman -Sy":
      provider => shell,
      user => 'root',
      onlyif => '[ $(( $(date +%s) - $(stat -c %Y /var/lib/pacman/sync) )) -gt 1000 ]',
    }
  }
}
```
