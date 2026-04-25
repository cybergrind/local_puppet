#!/usr/bin/env python3
"""Listen to the niri event stream and trigger actions on relevant
events. Currently: re-run niri_outputs.py when the set of outputs
hosting workspaces changes (monitor plugged/unplugged).

Layout:
  main / dispatch   — top-level loop and event routing (extension point)
  handlers          — per-event business logic, mutate state, call actions
  actions           — side effects (running scripts, etc.)
  event source      — plumbing that yields parsed niri events
"""

import json
import subprocess
import sys
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ALIGN_SCRIPT = Path.home() / '.local' / 'bin' / 'niri_outputs.py'


@dataclass
class State:
    last_outputs: frozenset[str] | None = None


# ---------- main / dispatch ------------------------------------------------


def main() -> int:
    state = State()
    for event in niri_events():
        dispatch(event, state)
    return 0


def dispatch(event: dict[str, Any], state: State) -> None:
    match event:
        case {'WorkspacesChanged': {'workspaces': workspaces}}:
            on_workspaces_changed(workspaces, state)
        # Add more `case`s here for new event types.


# ---------- handlers -------------------------------------------------------


def on_workspaces_changed(workspaces: list[dict[str, Any]], state: State) -> None:
    current = frozenset(w['output'] for w in workspaces)
    if state.last_outputs is None:
        state.last_outputs = current
        return
    if current == state.last_outputs:
        return
    state.last_outputs = current
    run_align()


# ---------- actions --------------------------------------------------------


def run_align() -> None:
    subprocess.run([str(ALIGN_SCRIPT)], check=False)


# ---------- event source ---------------------------------------------------


def niri_events() -> Iterator[dict[str, Any]]:
    proc = subprocess.Popen(
        ['niri', 'msg', '--json', 'event-stream'],
        stdout=subprocess.PIPE,
        text=True,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            continue


if __name__ == '__main__':
    sys.exit(main())
