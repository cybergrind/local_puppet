#!/usr/bin/env python3
"""UserPromptSubmit hook: surface skill triggers as a system reminder.

Audit finding (2026-05-16): ~85 of 108 Android sessions loaded zero skills
even when the user typed an exact trigger phrase. Doc-layer rules don't
fire; a harness hook is the only reliable lever. See
docs/ce/sessions/2026-05-16-android-context-audit-v2/findings-v2.md.

Contract:
- stdin: Claude Code JSON {"prompt": "...", "session_id": "...", ...}
- stdout: optional <system-reminder>...</system-reminder> injected before
  the user prompt is shown to the model. Empty stdout = no-op.
- exit 0: success (with or without stdout). Exit 2: block submission.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


# Harness-bundled skills — always available regardless of cwd/plugins.
# Keep in sync with the "available skills" system reminder if the harness
# adds/removes built-ins.
BUILTIN_SKILLS: frozenset[str] = frozenset(
    {
        'ask-llm',
        'llm-write',
        'extract-chat',
        'update-config',
        'keybindings-help',
        'simplify',
        'fewer-permission-prompts',
        'loop',
        'schedule',
        'claude-api',
        'init',
        'review',
        'security-review',
    }
)

HOME = Path(os.path.expanduser('~'))
PLUGINS_INSTALLED = HOME / '.claude' / 'plugins' / 'installed_plugins.json'

# (regex pattern, skill name, friendly trigger label)
TRIGGERS: list[tuple[re.Pattern[str], str, str]] = [
    (re.compile(r'\bred[/ ]?green\s+tdd\b', re.I), 'test-driven-development', 'red/green TDD'),
    (
        re.compile(r'use\s+sub[- ]?agents|spawn\s+(?:separate\s+)?sub[- ]?agents|leverage\s+sub[- ]?agents', re.I),
        'dispatching-parallel-agents',
        'use sub-agents',
    ),
    (
        re.compile(r'\bprevent\s+context\s+pollution\b', re.I),
        'dispatching-parallel-agents',
        'prevent context pollution',
    ),
    (
        re.compile(
            r'\bprepare\s+commit\b|\bbump\s+(?:the\s+)?tag\b|\bpublish\s+to\s+firebase\b|\bapp\s+distribution\b', re.I
        ),
        'verification-before-completion',
        'prepare commit / publish',
    ),
    (
        re.compile(
            r'\bsplit\s+(?:the\s+)?package\b|\bby\s+coupling\b|\breview\s+(?:the\s+)?file\s+structure\b|\bsplit\s+it\s+more\b',
            re.I,
        ),
        'principled-architecture',
        'package / structure review',
    ),
    (re.compile(r'app/src/test/java|\bJVM\s+unit\s+test\b|Robolectric', re.I), 'jvm-tests', 'JVM / Robolectric test'),
    (
        re.compile(r'@docs/superpowers/plans/.*\.md|\bexecute\s+(?:the\s+)?plan\b|\bstep[- ]by[- ]step\b', re.I),
        'executing-plans',
        '@docs/superpowers/plans/ plan',
    ),
    (
        re.compile(r'\bprune\s+redundant\s+tests\b|\bfire\s+pruner\b|\baudit\s+test\s+redundancy\b', re.I),
        'auditing-test-redundancy',
        'prune redundant tests',
    ),
    (
        re.compile(
            r'\bbrainstorm\b|\bplacement\s+question\b|where\s+should\s+this\s+(?:test|file|fixture)\s+live', re.I
        ),
        'brainstorming',
        'brainstorm / placement',
    ),
    (
        re.compile(r'\bbulk\s+read\b|\bsummari[sz]e\s+sessions?\b|lots\s+of\s+files', re.I),
        'ask-llm',
        'bulk read / summarise',
    ),
    (
        re.compile(r'\bwrite\s+boilerplate\b|reference\s+file\s+for\s+style', re.I),
        'llm-write',
        'boilerplate generation',
    ),
    (
        re.compile(
            r'tests?\s+fail\s+repeatedly|flake\s+hunt|\bdig\s+into\b\s+\S+\s+(?:test|flake)|systematic\s+debug', re.I
        ),
        'systematic-debugging',
        'repeated test failures',
    ),
    (
        re.compile(r'\bengineering[- ]context\b|context\s+pollution|CE\s+mode|/context[- ]engineer', re.I),
        'engineering-context',
        'context engineering',
    ),
    (
        re.compile(r'\bwriting[- ]plans\b|\bwrite\s+(?:an?\s+)?implementation\s+plan\b', re.I),
        'writing-plans',
        'write a plan',
    ),
    (re.compile(r'\bwriting[- ]skills\b|edit(?:ing)?\s+(?:this\s+)?skill', re.I), 'writing-skills', 'skill authoring'),
    (
        re.compile(r'\bcode[- ]review\b|review\s+(?:this\s+)?(?:pr|pull\s+request|change)', re.I),
        'requesting-code-review',
        'code review',
    ),
]


def _scan_skill_dir(skills_root: Path) -> set[str]:
    try:
        return {p.name for p in skills_root.iterdir() if p.is_dir()}
    except OSError, FileNotFoundError:
        return set()


def _enabled_plugin_paths() -> list[Path]:
    try:
        data = json.loads(PLUGINS_INSTALLED.read_text())
    except OSError, json.JSONDecodeError:
        return []
    out: list[Path] = []
    for entries in (data.get('plugins') or {}).values():
        if not isinstance(entries, list):
            continue
        for entry in entries:
            path = entry.get('installPath') if isinstance(entry, dict) else None
            if path:
                out.append(Path(path))
    return out


def available_skills(cwd: str | None) -> set[str]:
    skills = set(BUILTIN_SKILLS)
    skills |= _scan_skill_dir(HOME / '.claude' / 'skills')
    if cwd:
        skills |= _scan_skill_dir(Path(cwd) / '.claude' / 'skills')
    for plugin_root in _enabled_plugin_paths():
        skills |= _scan_skill_dir(plugin_root / 'skills')
    return skills


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError, ValueError:
        return 0  # silently no-op rather than block
    prompt = payload.get('prompt') or ''
    if not isinstance(prompt, str):
        return 0
    # Only fire on the first ~4000 chars; long prompts often paste large
    # files and the noise outweighs the signal.
    head = prompt[:4000]
    cwd = payload.get('cwd') if isinstance(payload.get('cwd'), str) else None
    skills = available_skills(cwd)
    matched: list[tuple[str, str]] = []
    seen: set[str] = set()
    for pattern, skill, label in TRIGGERS:
        if skill in seen or skill not in skills:
            continue
        if pattern.search(head):
            matched.append((skill, label))
            seen.add(skill)
    if not matched:
        return 0
    lines = [
        '<system-reminder>',
        'Skill-router (UserPromptSubmit hook) matched the following trigger(s) in your prompt.',
        'Invoke the Skill tool with each named skill BEFORE any other tool call (Read, Bash, Edit, Agent, TaskCreate).',
        'Audit context: across 108 recent Android sessions, ~85 loaded zero skills despite exact trigger matches.',
        '',
    ]
    for skill, label in matched:
        lines.append(f'- trigger {label!r} -> Skill: {skill}')
    lines.append('</system-reminder>')
    sys.stdout.write('\n'.join(lines) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
