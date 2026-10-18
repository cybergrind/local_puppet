# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal masterless-Puppet setup that provisions dev environments across Arch Linux, macOS, Windows (Chocolatey), and WSL. `puppet apply` is run locally; there is no Puppet server. Node selection happens by hostname against `manifests/hosts.pp`.

## Running

- Linux / macOS: `./run` (add `clean` to force `git pull` and re-install dependency modules)
- WSL: `./run` (`./run-wsl` is a thin wrapper around it)
- Windows: `.\run.ps1` (PowerShell)

All three wrappers do the same dance: conditional `git pull`, conditional `puppet module install` of `puppetlabs-stdlib` / `puppetlabs-vcsrepo` (+ `puppetlabs-chocolatey` on Windows; macOS installs go through `brew` execs, no module), then `puppet apply --modulepath ./modules[:system_modules] manifests/hosts.pp`.

The conditionals are driven by sentinel files in the repo root: `.pull` (refreshed daily) and `.submodules` (refreshed weekly). They're in `.gitignore`. `clean` deletes them.

The `run` script (Linux/macOS) also calls `niri_outputs.py` post-apply if `niri` is running — that's a downstream tool installed by the manifests, not part of this repo.

## Hosts and per-host settings

`manifests/hosts.pp` is a single `node default` that includes `kpi::base_devel` and `kpi::home` on every machine. Everything that differs per host is Hiera data bound to class parameters (mostly `kpi::home::*`): `modules/kpi/data/nodes/<networking.hostname>.yaml` → `data/os/<os.family>.yaml` → `data/common.yaml`. The short hostname is used, so a Mac matches whether it's `.local` or a tailnet FQDN.

- A new machine needs no change unless it differs from its OS defaults; then add `data/nodes/<host>.yaml` (and a `test/facts/<host>.yaml` fixture).
- Knobs (see the header of `kpi::home`): `skip_user` (OS owns the account; set for Windows), `hidpi`, `node_hostname` (enables `tailscale_priv`, names the sshj tunnel), `msx_hub`, `sshj` (false on Windows/WSL), `sshj_spec`, `uid`, `home_dir` (per-OS default).
- WSL is told apart from Windows by `os.family` plus its `ww-wsl` hostname (`hostnamectl set-hostname ww-wsl`, see README).

## Module layout (`modules/kpi/`)

Only one Puppet module, `kpi`, in the standard autoloader layout: one class or defined type per file, `kpi::linux::user_service` in `manifests/linux/user_service.pp` (puppet-lint enforces it). Classes worth knowing before editing:

- `kpi::os` — sets `$family`, `$is_arch`, `$is_darwin`, `$is_windows` from facts. **Every cross-platform manifest reads from here** rather than checking `$facts['os']` directly.
- `kpi::install` — the central install abstraction. A defined type that dispatches to `kpi::install::linux` (yay/AUR), `kpi::install::macos` (brew, with `cask`/`tap` flags), or `kpi::install::windows` (chocolatey). When adding packages, declare them via `kpi::install { ['pkg1', 'pkg2']: }`, not raw `package {}`, so the same manifest works on all OSes.
- `kpi::packages` — the package group classes (system, common, linux, macos, hyprland, niri, hidpi, optional, windows, ...). The lists themselves are **module Hiera data**, bound to class parameters automatically (`modules/kpi/hiera.yaml`: `data/os/<os.family>.yaml` → `data/common.yaml`). `data/common.yaml` holds names identical in brew and pacman/AUR (`kpi::packages::common::pkgs`, Linux + macOS); OS-specific names go in `data/os/Archlinux.yaml` / `Darwin.yaml` / `windows.yaml`, never in both. Adding a package = editing YAML, not manifests.
- `kpi::install` skips packages already listed in the `kpi_packages` / `kpi_brew_taps` facts (`facts.d/installed_packages.py`: one `pacman -Qq` or `brew list` per run), so use canonical brew names in data, not aliases. Otherwise `kpi::install::macos` checks via `brew list` / `brew tap`, and a fully qualified `owner/tap/formula` name declares its tap automatically. Casks that run a sudo'ed `.pkg` (e.g. `macfuse`) can't prompt from inside puppet (execs run without a tty), so `./run` installs those interactively first.
- `kpi::darwin` (`darwin.pp`) — macOS-only user session setup declared from `kpi::home`: keyboard remaps (hidutil LaunchAgent `com.kpi.keyboard`: Caps Lock → Control, Right Command → F18, and F18 bound to "next input source" like Right Alt's `grp:toggle` on Linux), the outer `wk` tmux server at login (LaunchAgent, counterpart of `tmux.service`), Syncthing (`com.kpi.syncthing`, KeepAlive), key repeat / no smart quotes / Finder defaults, docker CLI plugin links. The terminal is kitty with the shared `kitty.conf` (`macos_option_as_alt left` so tmux gets M-0..M-9; kitty ignores `macos_*` on Linux). Reusable defined types (`manifests/darwin/`): `kpi::darwin::launch_agent` (renders `launch_agent.plist.epp`, loads it with `launchctl bootstrap`) and `kpi::darwin::default` (idempotent `defaults write`).
- `kpi::darwin::system` — the root-only macOS bits (Touch ID for sudo via `/etc/pam.d/sudo_local` + `pam_reattach` for tmux, Spotlight indexing off). It's in no node: `./run` applies it with `sudo puppet apply -e 'include kpi::darwin::system'` only when one of them is out of date. `sudo_local` references `/opt/homebrew/lib/pam/pam_reattach.so`; if that file disappears sudo can't initialise PAM, so don't drop `pam-reattach` from the data without removing the line (recovery: `osascript -e 'do shell script "rm /etc/pam.d/sudo_local" with administrator privileges'`).
- `kpi::base_devel` — meta-class pulling in `os`, `packages`, `packages::system`, `packages::optional`, `repos`, plus the per-OS dev toolchain (`kpi::base_devel::pkgs` in data).
- `kpi::home` — deploys `modules/kpi/files/home/` recursively into `$home_dir`. Windows is a special branch that also copies into `AppData/Roaming/Code/User` and `AppData/Roaming/Zed`. Also clones helper repos (`kpi::home::repo`: emacs config, oh-my-zsh, fzf), runs `uv tool install dot-tools`, renders the tmux configs (`kpi::home::tmux`), creates symlinks into `~/.keys/` and `~/Yandex.Disk/` (`kpi::home::symlinks`), and declares `kpi::linux` or `kpi::darwin`. Only cross-platform things belong here.
- `kpi::linux` (`linux.pp`) — the Arch counterpart of `kpi::darwin`, declared from `kpi::home`: sshj tunnel, `tailscale_priv`, hyprland/glimpse configs, localsearch masking, linger, the `tmux`/`syncthing`/`msx-hub` user units, hiDPI, chrome flags. Each part is a class in `manifests/linux/` that reads `$kpi::linux::user` / `home_dir` and is `contain`ed by `kpi::linux`; knobs stay on `kpi::home`. Manage systemd **user** units with `kpi::linux::user_service { 'foo.service': user => $user }` (`enable`, `ensure => 'running' | 'unmanaged'`), not ad-hoc `systemctl --user` execs — core `service` only talks to the system manager.
- `kpi::repos`, `kpi::system`, `kpi::tailscale_priv` — OS repo setup (`pacman -Sy` / daily `brew update`), system-level systemd/udev/PAM files, the private-tailnet tailscaled.

`modules/kpi/files/home/` holds the dotfiles shared by every OS and is mirrored into the user's home directory by `kpi::home`. Per-OS overlays are merged on top of it (`sourceselect => all`, `home/` wins on clashes): `linux_home/` (X11/Wayland/KDE configs, systemd user units, hyprland/niri/rofi scripts) and `osx_home/`. Windows only gets `home/.config` plus the editor dirs. Don't put anything under `~/Library` in `osx_home/` — recursion would reset the `0700` dir modes; manage those files explicitly in `kpi::darwin`.

`modules/kpi/templates/*.epp` are Puppet EPP templates (chromium flags, hyprland, makepkg, sshj, tmux).

## Custom facts and the SSHJ knob

`modules/kpi/facts.d/user_data.py` is an external fact script that probes each `/home/*` and `/Users/*` user (only the invoking user's home when not root) for presence of `~/.ssh/id_rsa`, `~/.keys/ready`, `~/Yandex.Disk/wk_ssh2` and emits `<user>_<key>=True/False` facts, plus `<user>_uid` (the default of `kpi::home::uid`).

`FACTER_SSHJ_FACT` (preferred) / `FACTER_SSHJ_SPEC` are env vars the `run` script forwards into the puppet apply. They're the default of `kpi::home::sshj_spec`, which (with `kpi::home::sshj`) controls whether `kpi::home::sshj` deploys the ssh tunnel unit. On a fresh node before `~/.keys/` is mounted, you'll need to pass this manually: `FACTER_SSHJ_FACT=something ./run`.

## FUSE mounts on macOS

A dead FUSE mount on macOS blocks every stat on it forever. `.zshrc`, `run` and `facts.d/user_data.py` therefore only look inside `~/.keys` while it's in the mount table; keep that guard for anything new that reads it at shell startup or fact time.

## sync.py — reverse direction

`sync.py` is the **only** flow that copies in the opposite direction (live home → repo). For each file under `modules/kpi/files/home/` (plus `linux_home/` or `osx_home/`) it checks the corresponding file in `$HOME`; if they differ, it shows a diff and prompts to overwrite the repo copy from the live home. Use this to capture local config edits back into git. There's a Windows-specific path map (`Code/User`, `zed` → AppData) so the prompt works correctly on Windows.

## Python tooling (for sync.py and facts only)

- `pyproject.toml` targets Python 3.14, ruff line-length 120, single quotes, py314, imports sorted with `kpi`'s internal modules.
- `uv sync` installs dev deps (ruff, pyrefly, pre-commit, pytest).
- Pre-commit (`.pre-commit-config.yaml`, not installed by default: `uvx pre-commit install`) runs ruff + ruff-format + `uv run pyrefly check` on Python files, a battery of `pre-commit-hooks` checks on the whole repo, and `test/check` (hook `puppet-check`) when manifests, data, templates, facts or fixtures change. On a machine without puppet/bash (Windows): `SKIP=puppet-check git commit`.
- Known conflict: ruff targets py314 and writes `except A, B:`, which pre-commit's `check-ast` / `debug-statements` (CPython 3.12) can't parse (`.local/bin/mouse_battery.py`). `facts.d/*.py` are pinned to py39 in ruff because facter runs them with the OS python3.

## Checking manifests without applying them

`test/check` compiles the catalog of every node in `test/facts/` (Arch `home`/`tpad`/`zz`, Windows `ww`, macOS `kpis-macbook-pro`) from any machine, with strict mode on, plus a syntax pass over all manifests and templates and `puppet-lint` (version pinned in `test/check`, installed into the gitignored `test/.gems` on first use, settings in `.puppet-lint.rc`; skipped if it can't be installed, never in CI). Nothing is applied. Run it after every manifest/data change, especially for an OS you can't test on locally.

- `test/check --diff [REF]` also prints a unified diff of each node's catalog against `REF` (default `HEAD`). Use it to confirm a refactor is a no-op, or that a change only touches the OS it's meant to. Recursively deployed dotfiles don't show up there (they're expanded at apply time), only `File[$home]`'s `source` list.
- `test/check zz ww` limits it to those fixtures. A fixture's basename is the node name matched against `hosts.pp`; it only needs the facts the manifests read (`os`, `identity`, `processors`, `<user>_*`, `sshj_fact`).
- `test/compile_catalog.rb` does the actual compile through the Puppet Ruby API; it needs the stdlib/vcsrepo modules `./run` installs.

GitHub Actions (`.github/workflows/check.yml`) runs `test/check` on every push and PR, with the puppet gem and the same stdlib/vcsrepo versions as locally (`KPI_MODULEPATH` points `test/check` at them).

The real end-to-end test is still `./run` on a target machine.

## Conventions when editing manifests

- Use `kpi::install` not raw `package {}` to keep cross-platform behavior.
- Gate OS-specific blocks via `$kpi::os::is_arch` / `is_darwin` / `is_windows`, not by re-reading `$facts['os']`.
- On macOS puppet runs as the user (no sudo): no root-only resources, use `$facts['identity']` for the user/uid.
- When adding files under `modules/kpi/files/home/`, they will be deployed automatically by the recursive `file { $home: recurse => remote, ... }` in `kpi::home` — no manifest change needed.
- `kpi::home::repo { '<dir>': repo => 'owner/name' }` is the standard way to ensure a git checkout exists under the user's home (used for emacs config, oh-my-zsh, fzf).
- `kpi::home::link { '<path>': target => '<path>' }` (both relative to home) makes a symlink in the user's home. The ones into `~/.keys/` and `~/Yandex.Disk/` sit in `kpi::home::symlinks` behind the `<user>_keys` / `<user>_yad` facts; guard new ones similarly.
- A new class or defined type gets its own file under `manifests/` matching its name, typed parameters and a comment above it; `test/check` lints all of that. A part used once (a config file, a service) is a class, not a defined type with a made-up title; private parts read their parent class's variables (`$kpi::linux::user`).
