#!/usr/bin/env python3
import os
import subprocess
import sys
from glob import glob
from os.path import exists, join


# macOS keeps homes in /Users and runs puppet as the user itself, so only the
# homes we are allowed to switch into are probed.
def keys_mounted(home):
    # On macOS ~/.keys is a FUSE mount (sshfs/encfs) and a dead one blocks every
    # stat forever, including through the ~/.ssh links into it. Linux: as before.
    if sys.platform != 'darwin':
        return True
    mounts = subprocess.run(['/sbin/mount'], capture_output=True, text=True).stdout
    return f' on {home}/.keys ' in mounts


for d in glob('/home/*') + glob('/Users/*'):
    user = os.path.basename(d)
    stat = os.stat(d)
    if os.getuid() != 0 and stat.st_uid != os.getuid():
        continue
    if os.fork():
        continue
    os.setgid(stat.st_gid)
    os.setuid(stat.st_uid)
    keys_ok = keys_mounted(d)
    for k, v in {'id_rsa': '.ssh/id_rsa', 'keys': '.keys/ready', 'yad': 'Yandex.Disk/wk_ssh2'}.items():
        check_dir = join(d, v)
        e = (keys_ok or k == 'yad') and exists(check_dir)
        print(f'{user}_{k}={e}')
    break
