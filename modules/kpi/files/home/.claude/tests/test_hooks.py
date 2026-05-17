"""Black-box tests for the UserPromptSubmit / PreToolUse hooks.

Each hook is a stdin->stdout filter, so we drive them via subprocess with a
synthetic HOME so the skill-discovery scan is hermetic.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest


HOOKS_DIR = Path(__file__).resolve().parent.parent / 'hooks'
SKILL_ROUTER = HOOKS_DIR / 'skill_router.py'
SLEEP_GUARD = HOOKS_DIR / 'bash_sleep_guard.py'


def run_hook(script: Path, payload, home: Path | None = None) -> subprocess.CompletedProcess:
    """Invoke a hook script as a subprocess, returning the completed process.

    `payload` is sent verbatim if str/bytes, else json.dumps'd.
    """
    if isinstance(payload, (str, bytes)):
        stdin = payload if isinstance(payload, bytes) else payload.encode()
    else:
        stdin = json.dumps(payload).encode()
    env = {'PATH': '/usr/bin:/bin'}
    if home is not None:
        env['HOME'] = str(home)
    return subprocess.run(
        ['python3', str(script)],
        input=stdin,
        capture_output=True,
        env=env,
        timeout=10,
        check=False,
    )


# ---------------------------------------------------------------------------
# skill_router.py
# ---------------------------------------------------------------------------


@pytest.fixture
def fake_home(tmp_path: Path) -> Path:
    """A HOME with no global skills and no enabled plugins."""
    (tmp_path / '.claude' / 'skills').mkdir(parents=True)
    (tmp_path / '.claude' / 'plugins').mkdir(parents=True)
    (tmp_path / '.claude' / 'plugins' / 'installed_plugins.json').write_text(
        json.dumps({'version': 2, 'plugins': {}}),
    )
    return tmp_path


def test_no_trigger_no_output(fake_home: Path) -> None:
    res = run_hook(SKILL_ROUTER, {'prompt': 'hello world', 'cwd': str(fake_home)}, home=fake_home)
    assert res.returncode == 0
    assert res.stdout == b''


def test_builtin_skill_always_fires(fake_home: Path) -> None:
    res = run_hook(
        SKILL_ROUTER,
        {'prompt': 'please write boilerplate from reference file for style', 'cwd': str(fake_home)},
        home=fake_home,
    )
    assert res.returncode == 0
    out = res.stdout.decode()
    assert 'llm-write' in out
    assert '<system-reminder>' in out


def test_disk_skill_missing_is_filtered(fake_home: Path) -> None:
    """Pre-fix bug: hook would tell Claude to invoke a skill that does not exist."""
    res = run_hook(
        SKILL_ROUTER,
        {'prompt': "let's do red/green TDD on this", 'cwd': str(fake_home)},
        home=fake_home,
    )
    assert res.returncode == 0
    assert res.stdout == b''


def test_disk_skill_present_via_cwd_fires(fake_home: Path, tmp_path: Path) -> None:
    project = tmp_path / 'proj'
    (project / '.claude' / 'skills' / 'test-driven-development').mkdir(parents=True)
    res = run_hook(
        SKILL_ROUTER,
        {'prompt': "let's do red/green TDD on this", 'cwd': str(project)},
        home=fake_home,
    )
    out = res.stdout.decode()
    assert 'test-driven-development' in out


def test_disk_skill_present_via_user_global_fires(fake_home: Path) -> None:
    (fake_home / '.claude' / 'skills' / 'systematic-debugging').mkdir(parents=True)
    res = run_hook(
        SKILL_ROUTER,
        {'prompt': 'tests fail repeatedly across the suite', 'cwd': str(fake_home)},
        home=fake_home,
    )
    out = res.stdout.decode()
    assert 'systematic-debugging' in out


def test_disk_skill_present_via_enabled_plugin_fires(fake_home: Path, tmp_path: Path) -> None:
    plugin_root = tmp_path / 'plugin'
    (plugin_root / 'skills' / 'writing-plans').mkdir(parents=True)
    (fake_home / '.claude' / 'plugins' / 'installed_plugins.json').write_text(
        json.dumps(
            {
                'version': 2,
                'plugins': {
                    'demo@market': [
                        {'installPath': str(plugin_root)},
                    ],
                },
            }
        ),
    )
    res = run_hook(
        SKILL_ROUTER,
        {'prompt': 'help me write an implementation plan', 'cwd': str(fake_home)},
        home=fake_home,
    )
    out = res.stdout.decode()
    assert 'writing-plans' in out


def test_bad_json_is_silent(fake_home: Path) -> None:
    res = run_hook(SKILL_ROUTER, b'not json {', home=fake_home)
    assert res.returncode == 0
    assert res.stdout == b''


def test_prompt_must_be_string(fake_home: Path) -> None:
    res = run_hook(SKILL_ROUTER, {'prompt': 12345, 'cwd': str(fake_home)}, home=fake_home)
    assert res.returncode == 0
    assert res.stdout == b''


def test_trigger_past_4000_chars_is_ignored(fake_home: Path) -> None:
    prompt = ('x ' * 2500) + ' write boilerplate from reference file for style'
    res = run_hook(SKILL_ROUTER, {'prompt': prompt, 'cwd': str(fake_home)}, home=fake_home)
    assert res.stdout == b''


def test_no_cwd_field_still_works(fake_home: Path) -> None:
    res = run_hook(SKILL_ROUTER, {'prompt': 'write boilerplate from reference file for style'}, home=fake_home)
    assert b'llm-write' in res.stdout


def test_missing_plugins_file_is_tolerated(tmp_path: Path) -> None:
    """No ~/.claude at all -> should still emit the builtin trigger."""
    res = run_hook(
        SKILL_ROUTER,
        {'prompt': 'write boilerplate from reference file for style', 'cwd': str(tmp_path)},
        home=tmp_path,
    )
    assert b'llm-write' in res.stdout


# ---------------------------------------------------------------------------
# bash_sleep_guard.py
# ---------------------------------------------------------------------------


def test_sleep_guard_ignores_non_bash() -> None:
    res = run_hook(SLEEP_GUARD, {'tool_name': 'Read', 'tool_input': {'file_path': '/etc/hosts'}})
    assert res.stdout == b''


def test_sleep_guard_passes_clean_command() -> None:
    res = run_hook(SLEEP_GUARD, {'tool_name': 'Bash', 'tool_input': {'command': 'ls -la'}})
    assert res.stdout == b''


def test_sleep_guard_flags_until_poll_loop() -> None:
    cmd = 'until curl -sf http://x/health; do sleep 2; done'
    res = run_hook(SLEEP_GUARD, {'tool_name': 'Bash', 'tool_input': {'command': cmd}})
    out = res.stdout.decode()
    assert 'poll loop' in out
    assert '<system-reminder>' in out


def test_sleep_guard_flags_while_poll_loop() -> None:
    cmd = 'while ! grep -q ready /tmp/log; do sleep 5; done'
    res = run_hook(SLEEP_GUARD, {'tool_name': 'Bash', 'tool_input': {'command': cmd}})
    assert b'poll loop' in res.stdout


def test_sleep_guard_flags_long_single_sleep() -> None:
    res = run_hook(SLEEP_GUARD, {'tool_name': 'Bash', 'tool_input': {'command': 'sleep 600 && echo done'}})
    out = res.stdout.decode()
    assert 'long single' in out
    assert '600' in out


def test_sleep_guard_allows_short_single_sleep() -> None:
    res = run_hook(SLEEP_GUARD, {'tool_name': 'Bash', 'tool_input': {'command': 'sleep 5 && echo'}})
    assert res.stdout == b''


def test_sleep_guard_flags_both_loop_and_long_sleep() -> None:
    cmd = 'sleep 400; until ok; do sleep 3; done'
    res = run_hook(SLEEP_GUARD, {'tool_name': 'Bash', 'tool_input': {'command': cmd}})
    out = res.stdout.decode()
    assert 'poll loop' in out
    assert 'long single' in out


def test_sleep_guard_handles_missing_tool_input() -> None:
    res = run_hook(SLEEP_GUARD, {'tool_name': 'Bash'})
    assert res.returncode == 0
    assert res.stdout == b''


def test_sleep_guard_handles_bad_json() -> None:
    res = run_hook(SLEEP_GUARD, b'}{ not json')
    assert res.returncode == 0
    assert res.stdout == b''


def test_sleep_guard_handles_non_string_command() -> None:
    res = run_hook(SLEEP_GUARD, {'tool_name': 'Bash', 'tool_input': {'command': 42}})
    assert res.returncode == 0
    assert res.stdout == b''
