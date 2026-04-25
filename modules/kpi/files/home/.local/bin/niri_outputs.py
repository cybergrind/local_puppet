#!/usr/bin/env python3
"""Swap HDMI-A-1 <-> DP-5 in ~/.config/niri/config.kdl to match
whichever external output is currently connected, then move any
already-created named workspaces to their target monitor.

Niri only honours `open-on-output` when a workspace is first
created, so after a config reload existing workspaces stay put
unless we move them explicitly.

Puppet owns this file, so `./run` reverts the swap — re-run the
script after each puppet apply.
"""

import functools
import json
import re
import subprocess
import sys
from collections.abc import Callable
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Literal, NamedTuple, TypedDict, overload


CONFIG_PATH = Path.home() / '.config' / 'niri' / 'config.kdl'
HDMI_OUTPUT = 'HDMI-A-1'
DP_OUTPUT = 'DP-5'
WORKSPACE_RULE_RE = re.compile(r'workspace\s+"([^"]+)"\s*\{\s*open-on-output\s+"([^"]+)"')


class OutputSwap(NamedTuple):
    active: str
    stale: str


class Workspace(TypedDict):
    idx: int
    name: str | None
    output: str
    is_focused: bool


class OutputInfo(TypedDict, total=False):
    logical: dict[str, Any] | None


class OutputSelectionError(Exception):
    pass


# ---------- business logic (read top-to-bottom) ----------------------------


def notify_on_error(title: str) -> Callable:
    def decorator(func: Callable[..., int]) -> Callable[..., int]:
        @functools.wraps(func)
        def wrapper(*args, **kwargs) -> int:
            try:
                return func(*args, **kwargs)
            except (subprocess.CalledProcessError, FileNotFoundError, OutputSelectionError) as exc:
                notify(title, str(exc))
                return 1

        return wrapper

    return decorator


@notify_on_error('niri outputs')
def main() -> int:
    connected = connected_outputs()
    swap = pick_active_external(connected)

    with focus_preserved():
        swap_summary = rewrite_config(swap)
        moves_done = align_workspaces_to_config(available=connected)

    notify('niri config', f'{swap_summary}, moved {moves_done} workspace(s)')
    return 0


def pick_active_external(connected: set[str]) -> OutputSwap:
    if HDMI_OUTPUT in connected and DP_OUTPUT not in connected:
        return OutputSwap(active=HDMI_OUTPUT, stale=DP_OUTPUT)
    if DP_OUTPUT in connected and HDMI_OUTPUT not in connected:
        return OutputSwap(active=DP_OUTPUT, stale=HDMI_OUTPUT)
    raise OutputSelectionError(f'need exactly one of {HDMI_OUTPUT} or {DP_OUTPUT} connected')


def rewrite_config(swap: OutputSwap) -> str:
    text = CONFIG_PATH.read_text()
    if swap.stale not in text:
        return f'already using {swap.active}'
    CONFIG_PATH.write_text(text.replace(swap.stale, swap.active))
    return f'{swap.stale} → {swap.active}'


def align_workspaces_to_config(*, available: set[str]) -> int:
    plan = parse_workspace_plan(CONFIG_PATH.read_text(), available)
    return sum(1 for entry in plan if place_workspace(*entry))


# ---------- helpers --------------------------------------------------------


def connected_outputs() -> set[str]:
    return {name for name, info in niri_query('outputs').items() if info.get('logical')}


def parse_workspace_plan(config_text: str, available_outputs: set[str]) -> list[tuple[str, str, int]]:
    """Return [(name, output, target_idx)] in config order, where target_idx
    is the workspace's 1-based position among config-defined workspaces on
    its output. Skips rules whose output is not currently connected."""
    names_per_output: dict[str, list[str]] = {}
    for name, output in WORKSPACE_RULE_RE.findall(config_text):
        if output in available_outputs:
            names_per_output.setdefault(output, []).append(name)
    return [
        (name, output, position)
        for output, names in names_per_output.items()
        for position, name in enumerate(names, start=1)
    ]


def place_workspace(name: str, target_output: str, target_idx: int) -> bool:
    """Place workspace `name` at (target_output, target_idx). Returns True
    if a move was actually performed."""
    workspace = find_workspace_by_name(name)
    if workspace is None:
        return False
    if workspace['output'] == target_output and workspace['idx'] == target_idx:
        return False
    if not focus_output(workspace['output']):
        return False
    # Numeric workspace names collide with indices in `--reference`, so
    # focus the workspace via its current idx on the focused monitor.
    niri_action('focus-workspace', str(workspace['idx']))
    if workspace['output'] != target_output:
        niri_action('move-workspace-to-monitor', target_output)
    niri_action('move-workspace-to-index', str(target_idx))
    return True


def find_workspace_by_name(name: str) -> Workspace | None:
    return next(
        (w for w in niri_query('workspaces') if w.get('name') == name),
        None,
    )


@contextmanager
def focus_preserved():
    initial = focused_output()
    try:
        yield
    finally:
        if initial:
            focus_output(initial)


def focused_output() -> str | None:
    return next(
        (workspace['output'] for workspace in niri_query('workspaces') if workspace['is_focused']),
        None,
    )


def focus_output(target_output: str, max_hops: int = 4) -> bool:
    for _ in range(max_hops):
        if focused_output() == target_output:
            return True
        niri_action('focus-monitor-next')
    return focused_output() == target_output


# ---------- niri IPC thin wrappers -----------------------------------------


@overload
def niri_query(resource: Literal['outputs']) -> dict[str, OutputInfo]: ...
@overload
def niri_query(resource: Literal['workspaces']) -> list[Workspace]: ...
def niri_query(resource: str) -> Any:
    result = subprocess.run(
        ['niri', 'msg', '--json', resource],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def niri_action(*command: str) -> None:
    subprocess.run(['niri', 'msg', 'action', *command], check=False)


def notify(title: str, body: str = '') -> None:
    subprocess.run(['notify-send', '-t', '5000', title, body])


if __name__ == '__main__':
    sys.exit(main())
