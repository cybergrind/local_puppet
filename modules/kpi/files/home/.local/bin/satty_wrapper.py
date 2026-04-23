#!/usr/bin/env python3
"""Pick between custom ~/.local/bin/satty and system /usr/bin/satty.

Custom satty supports --daemon and --show flags for faster startup;
system satty does not. On --daemon, we only run the custom build —
if it's missing we exit silently so niri's spawn-sh-at-startup is a
no-op. In screenshot mode, we fall back to the system binary when
the custom one is absent.
"""

import argparse
import os
import sys
from pathlib import Path


CUSTOM = Path.home() / '.local' / 'bin' / 'satty'
SYSTEM = Path('/usr/bin/satty')


def has_custom() -> bool:
    return CUSTOM.is_file() and os.access(CUSTOM, os.X_OK)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Route to custom or system satty.')
    parser.add_argument(
        '--daemon',
        action='store_true',
        help='start the custom satty daemon; exit silently when the custom build is missing',
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)

    if args.daemon:
        if not has_custom():
            return 0
        os.execv(str(CUSTOM), [str(CUSTOM), '--daemon', '--initial-tool=crop'])

    if has_custom():
        cmd = [str(CUSTOM), '--show', '--initial-tool=crop', '--filename', '-']
    else:
        cmd = [str(SYSTEM), '--initial-tool=crop', '--filename', '-']
    os.execv(cmd[0], cmd)


if __name__ == '__main__':
    sys.exit(main())
