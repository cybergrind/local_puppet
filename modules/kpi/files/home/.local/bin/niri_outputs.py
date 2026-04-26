#!/usr/bin/env python3
"""Configure niri outputs and workspaces in ~/.config/niri/config.kdl based
on which external monitor(s) are currently connected, then move any
already-created named workspaces to their target monitor.

Three profiles:
- HDMI-A-1 only: workspaces 1-9 on HDMI-A-1, workspace 10 on eDP-1.
                 Pause -> HDMI-A-1, Shift+Pause -> eDP-1.
- DP-5 only:     workspaces 1-9 on DP-5, workspace 10 on eDP-1.
                 Pause -> DP-5, Shift+Pause -> eDP-1.
- Both externals: HDMI-A-1 placed left of DP-5, workspaces 1-9 on DP-5,
                  workspace 10 on HDMI-A-1. eDP-1 stays on but gets no
                  pinned workspaces. Pause -> DP-5, Shift+Pause -> HDMI-A-1.

The script rewrites three marker-delimited regions in config.kdl:
`niri_outputs.py: OUTPUTS / WORKSPACES / SCREENSHOTS START/END`.

Niri only honours `open-on-output` when a workspace is first created, so
after a config reload existing workspaces stay put unless we move them
explicitly.

Puppet owns config.kdl, so `./run` reverts the dynamic rewrite — re-run
this script after each puppet apply.
"""

import functools
import json
import re
import subprocess
import sys
from collections.abc import Callable
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal, TypedDict, overload


CONFIG_PATH = Path.home() / '.config' / 'niri' / 'config.kdl'
HDMI = 'HDMI-A-1'
DP = 'DP-5'
LAPTOP = 'eDP-1'
WORKSPACE_COUNT = 10

OUTPUTS_REGION_RE = re.compile(
    r'(// niri_outputs\.py: OUTPUTS START\n).*?(^// niri_outputs\.py: OUTPUTS END)',
    re.DOTALL | re.MULTILINE,
)
WORKSPACES_REGION_RE = re.compile(
    r'(// niri_outputs\.py: WORKSPACES START\n).*?(^// niri_outputs\.py: WORKSPACES END)',
    re.DOTALL | re.MULTILINE,
)
SCREENSHOTS_REGION_RE = re.compile(
    r'(// niri_outputs\.py: SCREENSHOTS START\n).*?(^// niri_outputs\.py: SCREENSHOTS END)',
    re.DOTALL | re.MULTILINE,
)
WORKSPACE_RULE_RE = re.compile(r'workspace\s+"([^"]+)"\s*\{\s*open-on-output\s+"([^"]+)"')


@dataclass(frozen=True)
class Profile:
    name: str
    output_blocks: list[str]
    workspaces: list[tuple[str, str]]  # [(workspace name, output)]
    screenshot_primary: str  # Pause
    screenshot_secondary: str  # Shift+Pause


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
    outputs = niri_query('outputs')
    connected = {name for name, info in outputs.items() if info.get('logical')}
    profile = pick_profile(connected, outputs)

    with focus_preserved():
        change_summary = rewrite_config(profile)
        moves_done = align_workspaces_to_config(available=connected)

    notify('niri config', f'{profile.name}: {change_summary}, moved {moves_done} workspace(s)')
    return 0


def pick_profile(connected: set[str], outputs: dict[str, OutputInfo]) -> Profile:
    has_hdmi = HDMI in connected
    has_dp = DP in connected
    if has_hdmi and has_dp:
        hdmi_width = logical_width(outputs[HDMI])
        return Profile(
            name=f'{HDMI} + {DP}',
            output_blocks=[
                f'output "{HDMI}" {{ position x=0 y=0; }}',
                f'output "{DP}" {{ position x={hdmi_width} y=0; }}',
            ],
            workspaces=[*[(str(i), DP) for i in range(1, WORKSPACE_COUNT)], (str(WORKSPACE_COUNT), HDMI)],
            screenshot_primary=DP,
            screenshot_secondary=HDMI,
        )
    if has_hdmi:
        return Profile(
            name=f'{HDMI} only',
            output_blocks=[],
            workspaces=default_workspaces(HDMI),
            screenshot_primary=HDMI,
            screenshot_secondary=LAPTOP,
        )
    if has_dp:
        return Profile(
            name=f'{DP} only',
            output_blocks=[],
            workspaces=default_workspaces(DP),
            screenshot_primary=DP,
            screenshot_secondary=LAPTOP,
        )
    raise OutputSelectionError(f'need {HDMI} or {DP} connected')


def default_workspaces(external: str) -> list[tuple[str, str]]:
    pairs = [(str(i), external) for i in range(1, WORKSPACE_COUNT)]
    pairs.append((str(WORKSPACE_COUNT), LAPTOP))
    return pairs


def rewrite_config(profile: Profile) -> str:
    text = CONFIG_PATH.read_text()
    new_text = replace_region(text, OUTPUTS_REGION_RE, render_outputs(profile.output_blocks), 'OUTPUTS')
    new_text = replace_region(new_text, WORKSPACES_REGION_RE, render_workspaces(profile.workspaces), 'WORKSPACES')
    new_text = replace_region(
        new_text,
        SCREENSHOTS_REGION_RE,
        render_screenshots(profile.screenshot_primary, profile.screenshot_secondary),
        'SCREENSHOTS',
    )
    if new_text == text:
        return 'unchanged'
    CONFIG_PATH.write_text(new_text)
    return 'rewritten'


def render_outputs(blocks: list[str]) -> str:
    return ''.join(f'{line}\n' for line in blocks)


def render_workspaces(pairs: list[tuple[str, str]]) -> str:
    return ''.join(f'workspace "{name}" {{ open-on-output "{output}"; }}\n' for name, output in pairs)


def render_screenshots(primary: str, secondary: str) -> str:
    return (
        f'    Pause       {{ spawn-sh "grim -o {primary} - | ~/.local/bin/satty_wrapper.py"; }}\n'
        f'    Shift+Pause {{ spawn-sh "grim -o {secondary} - | ~/.local/bin/satty_wrapper.py"; }}\n'
    )


def replace_region(text: str, region_re: re.Pattern[str], body: str, label: str) -> str:
    match = region_re.search(text)
    if not match:
        raise OutputSelectionError(f'{label} markers not found in {CONFIG_PATH}')
    return f'{text[: match.start()]}{match.group(1)}{body}{match.group(2)}{text[match.end() :]}'


def align_workspaces_to_config(*, available: set[str]) -> int:
    plan = parse_workspace_plan(CONFIG_PATH.read_text(), available)
    return sum(1 for entry in plan if place_workspace(*entry))


# ---------- helpers --------------------------------------------------------


def logical_width(info: 'OutputInfo') -> int:
    """Logical (scaled) width niri reports for a connected output. Niri
    auto-rearranges all outputs when any explicit position overlaps another,
    so neighbour positions must use the actual logical width — not a
    hard-coded one. See `niri msg outputs` for the source of truth."""
    logical = info.get('logical')
    if not logical or 'width' not in logical:
        raise OutputSelectionError('output has no logical geometry — is it connected?')
    return int(logical['width'])


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
