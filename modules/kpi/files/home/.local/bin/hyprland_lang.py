#!/usr/bin/env python3
"""
It remember active layout for window and switches it on focus if required.

connects to unix socket:

$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock

for events:

# focused window
activewindowv2>>622aeda74730

# closed window
closewindow>>622aed65ad50

# active layout change
activelayout>>704340378@qq.com-spilt-84v2-keyboard,English (US)
"""
import argparse
import asyncio
import logging
import os
import subprocess
import typing
from pathlib import Path


logging.basicConfig(level=logging.DEBUG, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')
log = logging.getLogger('LOG_NAME')


LAYOUT_MAPPING = {
    'English (US)': 0,
    'Russian': 1,
}

HYPRCTL = Path('~/.local/bin/hyprctl.sh').expanduser()


class LayoutHandler:
    def __init__(self):
        # windowid: layout
        self.tracked = {}
        self.active_window = ''
        self.current_layout = 0

    def handle_switch_window(self, windowid: str):
        self.tracked[self.active_window] = self.current_layout
        self.active_window = windowid
        log.debug(f'switched_to: {windowid}')
        required_layout = self.tracked.get(windowid, 0)
        if required_layout != self.current_layout:
            self.switch_layout(required_layout)

    def handle_switch_layout(self, kbd_and_layout: str):
        layout = kbd_and_layout.split(',')[-1].strip()
        self.current_layout = LAYOUT_MAPPING.get(layout, 0)
        self.tracked[self.active_window] = self.current_layout

    def handle_closed_window(self, windowid: str):
        self.tracked.pop(windowid, None)

    def switch_layout(self, layout_id: int):
        """
        use ~/.local/bin/hyprctl.sh setlayout all <layout_id>
        """
        cmd = [HYPRCTL, 'switchxkblayout', 'all', str(layout_id)]
        log.debug(f'cmd: {cmd}')
        subprocess.run(cmd, capture_output=True)

    HANDLERS: typing.ClassVar = {
        'activewindowv2': handle_switch_window,
        'closewindow': handle_closed_window,
        'activelayout': handle_switch_layout,
    }

    def handle_callback(self, callback: str):
        """
        activewindowv2>>622aeda74730
        closewindow>>622aed65ad50
        activelayout>>KEYBOARD_ID,English (US)
        """
        cmd, rest = callback.split('>>')
        if handler := self.HANDLERS.get(cmd):
            log.debug(f'cmd: {cmd}, rest: {rest}')
            handler(self, rest)


async def connect_and_run():
    log.debug('connect_and_run')
    socket_path = os.path.join(
        os.environ['XDG_RUNTIME_DIR'], 'hypr', os.environ['HYPRLAND_INSTANCE_SIGNATURE'], '.socket2.sock'
    )
    log.debug(f'socket_path: {socket_path}')
    reader, writer = await asyncio.open_unix_connection(socket_path)
    log.debug('connected')
    handler = LayoutHandler()
    while True:
        data = await reader.readline()
        if not data:
            break
        handler.handle_callback(data.decode().strip())
    writer.close()
    await writer.wait_closed()


def get_args():
    parser = argparse.ArgumentParser(description='DESCRIPTION')
    parser.add_argument('-d', '--debug', action='store_true')
    return parser.parse_args()


def main():
    args = get_args()
    if not args.debug:
        logging.root.setLevel(logging.INFO)

    log.debug('start')
    loop = asyncio.get_event_loop()
    loop.run_until_complete(connect_and_run())


if __name__ == '__main__':
    main()
