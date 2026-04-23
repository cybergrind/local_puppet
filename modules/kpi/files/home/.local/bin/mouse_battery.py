#!/usr/bin/env python3
# /// script
# requires-python = ">=3.13"
# ///
"""Print the current Logitech mouse battery percentage from sysfs."""

import sys
from pathlib import Path



POWER_SUPPLY = Path('/sys/class/power_supply')


def get_mouse_battery() -> int | None:
    for p in POWER_SUPPLY.glob('hidpp_battery_*'):
        capacity_file = p / 'capacity'
        if capacity_file.exists():
            return int(capacity_file.read_text().strip())
    return None


if __name__ == '__main__':
    level = get_mouse_battery()
    if level is None:
        print('Battery level unavailable', file=sys.stderr)
        sys.exit(1)
    print(level)
