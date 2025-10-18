#!/usr/bin/env python3
import difflib
import hashlib
import logging
import os
import shutil
from pathlib import Path
from subprocess import run


logging.basicConfig(level=logging.DEBUG, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')
log = logging.getLogger('sync')

target_dir = Path('~').expanduser().absolute()
source_dir = Path('modules/kpi/files/home/').absolute()

if os.name == 'nt':
    appdata = Path(os.environ.get('APPDATA', target_dir / 'AppData' / 'Roaming'))
    WINDOWS_PATHS = {
        Path('.config/Code/User'): appdata / 'Code' / 'User',
        Path('.config/zed'): appdata / 'Zed',
    }
else:
    WINDOWS_PATHS = {}


def file_hash(path: Path) -> str:
    digest = hashlib.md5()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(8192), b''):
            digest.update(chunk)
    return digest.hexdigest()


def is_same(src: Path, dst: Path) -> bool:
    if not dst.exists() or src.stat().st_size != dst.stat().st_size:
        return False
    return file_hash(src) == file_hash(dst)


def show_diff(src: Path, dst: Path) -> None:
    try:
        src_lines = src.read_text(encoding='utf-8', errors='replace').splitlines()
        dst_lines = dst.read_text(encoding='utf-8', errors='replace').splitlines()
    except OSError as exc:
        log.warning('Cannot show diff for %s: %s', src, exc)
        return

    diff = list(difflib.unified_diff(src_lines, dst_lines, fromfile=str(src), tofile=str(dst), lineterm=''))
    if not diff:
        log.info('Files differ but no textual diff available for %s', src)
        return

    for line in diff:
        print(line)


def resolve_target(relative: Path) -> Path:
    for source_root, destination_root in WINDOWS_PATHS.items():
        try:
            suffix = relative.relative_to(source_root)
        except ValueError:
            continue
        return destination_root / suffix
    return target_dir / relative


def check_for_sync_posix():
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
        show_diff(source_file, target_file)
        choice = input('Do you want to sync? [y/n]: ')
        if choice.lower() == 'y':
            source_file.write_text(target_file.read_text())
            log.info(f'{source_file} synced')
        else:
            log.info(f'{source_file} not synced')


def check_for_sync_windows():
    for source_file in source_dir.rglob('*'):
        if not source_file.is_file():
            continue
        relative = source_file.relative_to(source_dir)
        target_file = resolve_target(relative)
        if not target_file.exists():
            continue
        if is_same(source_file, target_file):
            continue
        log.info('Diff for %s:', source_file)
        show_diff(source_file, target_file)
        choice = input('Sync home -> repo? [y/N]: ').strip().lower()
        if choice != 'y':
            log.info('%s skipped', source_file)
            continue
        source_file.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target_file, source_file)
        log.info('%s synced', source_file)


def main():
    if os.name == 'nt':
        check_for_sync_windows()
    else:
        check_for_sync_posix()


if __name__ == '__main__':
    main()
