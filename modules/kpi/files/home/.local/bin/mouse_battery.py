#!/usr/bin/env python3
# /// script
# requires-python = ">=3.13"
# ///
"""Print the current Logitech mouse battery percentage via solaar.

Queries the device directly over HID++ instead of reading
/sys/class/power_supply, where the kernel hid-logitech-hidpp driver
caches stale/bogus values while the mouse is charging.
"""

import re
import subprocess
import sys


def get_mouse_battery() -> int | None:
    try:
        proc = subprocess.run(['solaar', 'show'], capture_output=True, text=True, timeout=30)
    except OSError, subprocess.TimeoutExpired:
        return None
    kind = None
    for line in proc.stdout.splitlines():
        if m := re.match(r'\s*Kind\s*:\s*(\w+)', line):
            kind = m.group(1)
        elif (m := re.search(r'Battery: (\d+)%', line)) and kind == 'mouse':
            return int(m.group(1))
    return None


if __name__ == '__main__':
    level = get_mouse_battery()
    if level is None:
        print('Battery level unavailable', file=sys.stderr)
        sys.exit(1)
    print(level)
