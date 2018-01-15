#!/usr/bin/python

# xscreensaver-command -deactivate
# xprop -id $(xprop -root _NET_ACTIVE_WINDOW | cut -d ' ' -f 5) _NET_WM_NAME
import sys
import subprocess
import time


STOPWORDS = [
    'twitch', 'youtube', 'mplayer', 'stepmania'
]

wname = "xprop -id $(xprop -root _NET_ACTIVE_WINDOW | cut -d ' ' -f 5) _NET_WM_NAME"
stop_saver = 'xscreensaver-command -deactivate'


def perform_check():
    desc = subprocess.check_output(wname, shell=True).decode('utf8').lower()
    print('wname: {}'.format(desc))
    for word in STOPWORDS:
        if word in desc:
            print('Disable screensaver')
            subprocess.call(stop_saver, shell=True)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'once':
        perform_check()
        return
    while True:
        perform_check()
        time.sleep(120)

if __name__ == '__main__':
    main()
