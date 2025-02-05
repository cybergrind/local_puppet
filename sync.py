#!/usr/bin/env python3
import logging
from pathlib import Path
from subprocess import run


logging.basicConfig(level=logging.DEBUG, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')
log = logging.getLogger('sync')
target_dir = Path('~').expanduser().absolute()
source_dir= Path('modules/kpi/files/home/').absolute()


def is_same(src, dst):
    if not dst.exists():
        return False
    if src.stat().st_size != dst.stat().st_size:
        return False
    src_md5 = run(['md5sum', src], capture_output=True, text=True).stdout.split()[0]
    dst_md5 = run(['md5sum', dst], capture_output=True, text=True).stdout.split()[0]
    return src_md5 == dst_md5

def check_for_sync():
    """
    Iterates over target_dir files and check if source_dir
    files have more recent changes.
    Shows diff for such files and ask if it need it to sync to source_dir
    """
    for source_file in source_dir.rglob('*'):
        if source_file.is_dir():
            continue
        target_file = target_dir / source_file.relative_to(source_dir)
        if not target_file.exists():
            continue
        if is_same(source_file, target_file):
            continue
        log.info(f'Diff for {source_file}:')
        run(['diff', source_file, target_file])
        choice = input('Do you want to sync? [y/n]: ')
        if choice.lower() == 'y':
            source_file.write_text(target_file.read_text())
            log.info(f'{source_file} synced')
        else:
            log.info(f'{source_file} not synced')

def main():
    check_for_sync()

if __name__ == '__main__':
    main()

