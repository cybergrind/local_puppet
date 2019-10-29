#!/usr/bin/env python
import os
from os.path import join, exists
from glob import glob


for d in glob('/home/*'):
    user = d.replace('/home/', '')
    stat = os.stat(d)
    if os.fork():
        continue
    os.setgid(stat.st_gid)
    os.setuid(stat.st_uid)
    for k, v in {'id_rsa': '.ssh/id_rsa',
                 'keys': '.keys/ready',
                 'yad': 'Yandex.Disk/wk_ssh2'}.items():
        check_dir = join(d, v)
        e = exists(check_dir)
        print('{}_{}={}'.format(user, k, e))
    break
