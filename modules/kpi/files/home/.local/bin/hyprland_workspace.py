#!/usr/bin/env python3
import argparse
import json
import logging
from subprocess import run


logging.basicConfig(level=logging.DEBUG, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')
log = logging.getLogger('hyprland_workspace')


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


def workspace_info():
    """
        window:
        {
        "address": "0x622aed978cb0",
        "mapped": true,
        "hidden": false,
        "at": [1440, 22],
        "size": [2560, 1418],
        "workspace": {
            "id": 2,
            "name": "2"
        },
        "floating": true,
        "pseudo": false,
        "monitor": 1,
        "class": "kitty",
        "title": "tmx",
        "initialClass": "kitty",
        "initialTitle": "kitty",
        "pid": 2667513,
        "xwayland": false,
        "pinned": false,
        "fullscreen": 0,
        "fullscreenClient": 0,
        "grouped": [],
        "tags": [],
        "swallowing": "0x0",
        "focusHistoryID": 0,
        "inhibitingIdle": false
    }

        clients: list of --
        },{
        "address": "0x622aed978cb0",
        "mapped": true,
        "hidden": false,
        "at": [1440, 22],
        "size": [2560, 1418],
        "workspace": {
            "id": 2,
            "name": "2"
        },
        "floating": true,
        "pseudo": false,
        "monitor": 1,
        "class": "kitty",
        "title": "tmx",
        "initialClass": "kitty",
        "initialTitle": "kitty",
        "pid": 2667513,
        "xwayland": false,
        "pinned": false,
        "fullscreen": 0,
        "fullscreenClient": 0,
        "grouped": [],
        "tags": [],
        "swallowing": "0x0",
        "focusHistoryID": 0,
        "inhibitingIdle": false
    }]
    """
    window = hyprctl('activewindow')
    clients = hyprctl('clients')

    active_monitor = window['monitor']
    active_workspace = window['workspace']['name']
    active_window_address = window['address']
    print('     ', end='')

    for client in clients:
        client_workspace = client['workspace']['name']
        client_address = client['address']
        client_monitor = client['monitor']

        if active_window_address == client_address:
            continue
        if active_monitor != client_monitor:
            continue
        if active_workspace != client_workspace:
            continue
        client_string = f' ∎∎ {client["title"]}'
        print(client_string, end='')

    # flush stdout
    print()


def main():
    args = parse_args()
    log.setLevel(logging.DEBUG)
    if args.debug:
        log.setLevel(logging.DEBUG)

    workspace_info()


if __name__ == '__main__':
    main()
