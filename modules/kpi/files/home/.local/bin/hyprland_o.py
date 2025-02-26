#!/usr/bin/env python3
import argparse
import json
import logging
from pprint import pprint
from subprocess import run


logging.basicConfig(level=logging.DEBUG, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')
log = logging.getLogger('hyprland_o')


def hyprctl(command: str | list, is_json=True) -> dict | list | str:
    # run hyprctl.sh command -j and read json
    cmd_list = ['~/.local/bin/hyprctl.sh']
    if isinstance(command, list):
        cmd_list.extend(command)
    else:
        cmd_list.append(command)
    if is_json:
        cmd_list.append('-j')
    out = run(' '.join(cmd_list), capture_output=True, shell=True)
    if out.returncode != 0:
        log.error(f'{cmd_list} failed with {out.returncode}')
        log.error(out.stdout.decode('utf-8'))
        log.error(out.stderr.decode('utf-8'))
        return {}
    if is_json:
        return json.loads(out.stdout)
    else:
        return out.stdout.decode('utf-8')


def parse_args():
    parser = argparse.ArgumentParser(description='DESCRIPTION')
    parser.add_argument('-d', '--debug', action='store_true')
    parser.add_argument('command', nargs='?', default=None)
    return parser.parse_args()


def move_active_window(monitors_list):
    """ """
    if len(monitors_list) == 1:
        log.debug('only one monitor, nothing to do')
        return
    to_workspace = None
    for monitor in monitors_list:
        if not monitor['focused']:
            to_workspace = monitor['activeWorkspace']['name']
            hyprctl(['dispatch', 'movetoworkspace', str(to_workspace)], is_json=False)
            return


def main():
    args = parse_args()
    if args.debug:
        log.setLevel(logging.DEBUG)
    log.debug(f'args: {args}')
    if args.command:
        out = hyprctl(args.command)
        pprint(out)  # noqa: T203
        return
    else:
        monitors = hyprctl('monitors')
        move_active_window(monitors)


if __name__ == '__main__':
    main()
