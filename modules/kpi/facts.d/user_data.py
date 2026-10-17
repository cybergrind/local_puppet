#!/usr/bin/env python3
import os
from glob import glob
from os.path import exists, join


# macOS keeps homes in /Users and runs puppet as the user itself, so only the
# homes we are allowed to switch into are probed.
for d in glob('/home/*') + glob('/Users/*'):
    user = os.path.basename(d)
    stat = os.stat(d)
    if os.getuid() != 0 and stat.st_uid != os.getuid():
        continue
    if os.fork():
        continue
    os.setgid(stat.st_gid)
    os.setuid(stat.st_uid)
    for k, v in {'id_rsa': '.ssh/id_rsa', 'keys': '.keys/ready', 'yad': 'Yandex.Disk/wk_ssh2'}.items():
        check_dir = join(d, v)
        e = exists(check_dir)
        print(f'{user}_{k}={e}')
    break
