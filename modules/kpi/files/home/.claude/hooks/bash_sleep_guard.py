#!/usr/bin/env python3
"""PreToolUse hook on Bash: warn on `until ... sleep N; do ... done` loops.

Audit finding (2026-05-16): 12+ Android sessions had `until ... sleep` poll
loops despite the `feedback_short_polling_intervals` memory rule. e0a2e0d0
hit the harness `Blocked: sleep` error 3 times before reaching for Monitor.
See docs/ce/sessions/2026-05-16-android-context-audit-v2/findings-v2.md.

Contract (PreToolUse):
- stdin: Claude Code JSON {"tool_name": "Bash", "tool_input": {"command": "..."}, ...}
- stdout (with exit 0): additional context surfaced to the model after the
  tool call completes.
- exit 2 + stderr: block the call. We never block; this is a soft nudge.
"""

from __future__ import annotations

import json
import re
import sys


# Matches:
#   until <cond>; do ... sleep N ... done
#   while <cond>; do ... sleep N ... done    (also a poll loop)
#   for ... do ... sleep N ... done          (less common but same shape)
# Long single sleeps (>120) also trip the harness.
LOOP_PATTERN = re.compile(r'\b(until|while|for)\b.{0,400}?\bdo\b.{0,800}?\bsleep\s+\d+', re.S)
LONG_SLEEP_PATTERN = re.compile(r'\bsleep\s+(\d{3,}|[2-9]\d\d)\b')


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError, ValueError:
        return 0
    if payload.get('tool_name') != 'Bash':
        return 0
    cmd = (payload.get('tool_input') or {}).get('command') or ''
    if not isinstance(cmd, str) or not cmd:
        return 0
    hit_loop = bool(LOOP_PATTERN.search(cmd))
    long_sleep = LONG_SLEEP_PATTERN.search(cmd)
    if not (hit_loop or long_sleep):
        return 0
    msgs = ['<system-reminder>', 'bash_sleep_guard (PreToolUse hook) flagged this Bash command:']
    if hit_loop:
        msgs.append('- detected an `until/while ... sleep ... done` poll loop')
    if long_sleep:
        msgs.append(f'- detected a long single `sleep {long_sleep.group(1)}` (>=200s often blocked by the harness)')
    msgs.append('Polling loops bleed wall-clock + context. Prefer:')
    msgs.append(
        '  - `Bash` with `run_in_background: true` and a short '
        '`until <cond>; do sleep 2; done` shim that exits when the condition '
        'is met (single notification), OR'
    )
    msgs.append('  - the `Monitor` tool for streamed events (one notification per occurrence), OR')
    msgs.append('  - `ScheduleWakeup` for longer waits (loop mode).')
    msgs.append('See memory `feedback_short_polling_intervals`.')
    msgs.append('</system-reminder>')
    sys.stdout.write('\n'.join(msgs) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
