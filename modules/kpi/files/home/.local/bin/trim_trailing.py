#!/usr/bin/env python3
# /// script
# requires-python = ">=3.13"
# ///
"""Clean terminal/clipboard text.

- Strip trailing spaces/tabs from each line (preserving CR for CRLF inputs).
- Drop zsh prompt top-border lines (starting with ``┌`` and ending with ``┐``),
  replacing them with a blank separator between non-empty blocks.
- Collapse zsh prompt bottom lines (``└…──> cmd … ──(date)─┘``) into ``$ cmd``.
"""

import re
import sys


_TRAILING = re.compile(r'[ \t]+(\r?)(?=\n|\Z)')
_TOP_BORDER = re.compile(r'^┌.*┐\r?$')
_PROMPT = re.compile(r'^└.*?──>(?:\s(.*?))?\r?$')
_PROMPT_TAIL = re.compile(r'\s*(?:\d+\s*↵\s*)?──\([^)]*\)─┘\s*$')


def trim(text: str) -> str:
    text = _TRAILING.sub(r'\1', text)
    out: list[str] = []
    for line in text.split('\n'):
        if _TOP_BORDER.match(line):
            if out and out[-1] != '':
                out.append('')
            continue
        m = _PROMPT.match(line)
        if m:
            raw = m.group(1) or ''
            cmd = _PROMPT_TAIL.sub('', raw).strip()
            if cmd:
                out.append(f'$ {cmd}')
            continue
        out.append(line)
    return '\n'.join(out)


if __name__ == '__main__':
    sys.stdout.write(trim(sys.stdin.read()))
