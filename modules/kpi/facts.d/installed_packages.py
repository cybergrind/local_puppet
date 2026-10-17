#!/usr/bin/env python3
# Installed package names, listed once per run so kpi::install can skip what's
# already there instead of spawning a check command per package.
#   kpi_packages:  pacman -Qq, or brew formulae + casks (short names)
#   kpi_brew_taps: brew tap
# Runs under macOS's stock python3 (3.9), keep the syntax old enough for it.
import json
import os
import subprocess


def lines(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.split()
    except (OSError, subprocess.CalledProcessError):
        return []


facts = {}
if os.path.exists('/usr/bin/pacman'):
    facts['kpi_packages'] = lines('/usr/bin/pacman', '-Qq')
elif os.path.exists('/opt/homebrew/bin/brew'):
    brew = '/opt/homebrew/bin/brew'
    facts['kpi_packages'] = lines(brew, 'list', '--formula', '-1') + lines(brew, 'list', '--cask', '-1')
    facts['kpi_brew_taps'] = lines(brew, 'tap')
print(json.dumps(facts))
