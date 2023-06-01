### macos

```
brew install findutils
export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
```


### sshj

By default should already be set from keys. On new node it won't be set until keys are monted.

```bash
FACTER_SSHJ_USER=something ./run
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
