#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "textual>=3.0",
# ]
# ///
"""TUI to browse and resume Claude Code sessions for the current directory."""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.widgets import Footer, Header, ListItem, ListView, Static


CLAUDE_DIR = Path.home() / ".claude"
PROJECTS_DIR = CLAUDE_DIR / "projects"


def encode_project_path(cwd: str) -> str:
    return re.sub(r"[^a-zA-Z0-9-]", "-", cwd)


def load_sessions(cwd: str) -> list[dict]:
    project_dir = PROJECTS_DIR / encode_project_path(cwd)
    if not project_dir.is_dir():
        return []

    sessions = []
    for jsonl_file in project_dir.glob("*.jsonl"):
        session_id = jsonl_file.stem
        # Skip files that don't look like UUIDs
        if len(session_id) < 30:
            continue

        first_user = None
        last_messages: list[dict] = []
        started_at = None

        with open(jsonl_file, "r", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    continue

                msg_type = msg.get("type")
                if msg_type not in ("user", "assistant"):
                    continue

                ts = msg.get("timestamp")
                if ts and started_at is None:
                    started_at = ts

                if msg_type == "user" and first_user is None:
                    content = msg.get("message", {}).get("content", "")
                    if isinstance(content, list):
                        content = " ".join(
                            c.get("text", "") for c in content if c.get("type") == "text"
                        )
                    first_user = content.strip()

                # Keep a rolling window of last messages
                content = msg.get("message", {}).get("content", "")
                if isinstance(content, list):
                    parts = []
                    for c in content:
                        if c.get("type") == "text":
                            parts.append(c.get("text", ""))
                        elif c.get("type") == "tool_use":
                            parts.append(f"[tool: {c.get('name', '?')}]")
                    content = " ".join(parts)

                last_messages.append(
                    {"type": msg_type, "content": content.strip(), "timestamp": ts}
                )

        if not first_user:
            continue

        # Parse started_at
        if started_at:
            try:
                dt = datetime.fromisoformat(started_at.replace("Z", "+00:00"))
            except (ValueError, AttributeError):
                dt = datetime.now(timezone.utc)
        else:
            dt = datetime.now(timezone.utc)

        sessions.append(
            {
                "session_id": session_id,
                "started_at": dt,
                "first_user_message": first_user,
                "last_messages": last_messages[-10:],
            }
        )

    sessions.sort(key=lambda s: s["started_at"], reverse=True)
    return sessions


def format_time(dt: datetime) -> str:
    now = datetime.now(timezone.utc)
    delta = now - dt
    if delta.days == 0:
        hours = delta.seconds // 3600
        if hours == 0:
            mins = delta.seconds // 60
            return f"{mins}m ago"
        return f"{hours}h ago"
    if delta.days < 30:
        return f"{delta.days}d ago"
    return dt.strftime("%Y-%m-%d")


def truncate(text: str, width: int) -> str:
    text = text.replace("\n", " ").strip()
    if len(text) <= width:
        return text
    return text[: width - 1] + "…"


class SessionItem(ListItem):
    def __init__(self, session: dict, index: int) -> None:
        self.session = session
        super().__init__(id=f"session-{index}")

    def compose(self) -> ComposeResult:
        s = self.session
        label = f"{format_time(s['started_at']):>8}  {truncate(s['first_user_message'], 60)}"
        yield Static(label)


class SessionsApp(App):
    CSS = """
    #main {
        width: 100%;
        height: 1fr;
    }
    #left {
        width: 1fr;
        min-width: 30;
        border-right: solid $accent;
    }
    #right {
        width: 2fr;
        padding: 1 2;
        overflow-y: auto;
    }
    ListView {
        height: 100%;
    }
    ListView > ListItem {
        padding: 0 1;
    }
    #detail {
        width: 100%;
    }
    """

    BINDINGS = [
        Binding("j", "cursor_down", "Down", show=False),
        Binding("k", "cursor_up", "Up", show=False),
        Binding("enter", "resume", "Resume session"),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(self, sessions: list[dict], cwd: str) -> None:
        super().__init__()
        self.sessions = sessions
        self.cwd = cwd
        self._selected_session_id: str | None = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal(id="main"):
            lv = ListView(
                *(SessionItem(s, i) for i, s in enumerate(self.sessions)),
                id="left",
            )
            yield lv
            yield Static("Select a session", id="right")
        yield Footer()

    def on_mount(self) -> None:
        self.title = f"Claude Sessions — {self.cwd}"
        if self.sessions:
            self._show_detail(0)

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        if event.item and isinstance(event.item, SessionItem):
            idx = self.sessions.index(event.item.session)
            self._show_detail(idx)

    def _show_detail(self, idx: int) -> None:
        s = self.sessions[idx]
        self._selected_session_id = s["session_id"]

        lines: list[str] = []
        lines.append(f"[bold]Session:[/] {s['session_id']}")
        lines.append(f"[bold]Started:[/] {s['started_at'].strftime('%Y-%m-%d %H:%M:%S UTC')}")
        lines.append("")
        lines.append("[bold underline]First message:[/]")
        lines.append(s["first_user_message"][:2000])
        lines.append("")
        lines.append("[bold underline]Latest messages:[/]")

        for m in s["last_messages"]:
            role = "[bold cyan]You:[/]" if m["type"] == "user" else "[bold green]Claude:[/]"
            text = truncate(m["content"], 500) if m["content"] else "(empty)"
            lines.append(f"{role} {text}")
            lines.append("")

        detail = self.query_one("#right", Static)
        detail.update("\n".join(lines))

    def action_cursor_down(self) -> None:
        lv = self.query_one("#left", ListView)
        lv.action_cursor_down()

    def action_cursor_up(self) -> None:
        lv = self.query_one("#left", ListView)
        lv.action_cursor_up()

    def action_resume(self) -> None:
        if self._selected_session_id:
            self.exit(result=self._selected_session_id)


def main() -> None:
    cwd = os.getcwd()
    sessions = load_sessions(cwd)

    if not sessions:
        print(f"No Claude sessions found for {cwd}")
        sys.exit(1)

    app = SessionsApp(sessions, cwd)
    session_id = app.run()

    if session_id:
        print(f"Resuming session {session_id}...")
        os.execvp("claude", ["claude", "--resume", session_id])


if __name__ == "__main__":
    main()
