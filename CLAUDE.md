# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal masterless-Puppet setup that provisions dev environments across Arch Linux, macOS, Windows (Chocolatey), and WSL. `puppet apply` is run locally; there is no Puppet server. Node selection happens by hostname against `manifests/hosts.pp`.

## Running

- Linux / macOS: `./run` (add `clean` to force `git pull` and re-install dependency modules)
- WSL: `./run-wsl`
- Windows: `.\run.ps1` (PowerShell)

All three wrappers do the same dance: conditional `git pull`, conditional `puppet module install` of `puppetlabs-stdlib` / `puppetlabs-vcsrepo` (+ `puppetlabs-chocolatey` on Windows; macOS installs go through `brew` execs, no module), then `puppet apply --modulepath ./modules[:system_modules] manifests/hosts.pp`.

The conditionals are driven by sentinel files in the repo root: `.pull` (refreshed daily) and `.submodules` (refreshed weekly). They're in `.gitignore`. `clean` deletes them.

The `run` script (Linux/macOS) also calls `niri_outputs.py` post-apply if `niri` is running — that's a downstream tool installed by the manifests, not part of this repo.

## Hostname → node mapping

`manifests/hosts.pp` is the entry manifest. Adding a new machine = adding a `node 'hostname' { ... }` block there. WSL is distinguished from Windows by setting `hostnamectl set-hostname ww-wsl` (see README).

`$skip_user = true` is used on hosts (e.g. `ww`/Windows) where the OS already manages the user account — this gates whether `kpi::home` creates the user resource.

## Module layout (`modules/kpi/`)

Only one Puppet module, `kpi`. Classes worth knowing before editing:

- `kpi::os` — sets `$family`, `$is_arch`, `$is_darwin`, `$is_windows` from facts. **Every cross-platform manifest reads from here** rather than checking `$facts['os']` directly.
- `kpi::install` — the central install abstraction. A defined type that dispatches to `kpi::install::linux` (yay/AUR), `kpi::install::macos` (brew, with `cask`/`tap` flags), or `kpi::install::windows` (chocolatey). When adding packages, declare them via `kpi::install { ['pkg1', 'pkg2']: }`, not raw `package {}`, so the same manifest works on all OSes.
- `kpi::packages` — the package group classes (system, common, linux, macos, hyprland, niri, hidpi, optional, windows, ...). The lists themselves are **module Hiera data**, bound to class parameters automatically (`modules/kpi/hiera.yaml`: `data/os/<os.family>.yaml` → `data/common.yaml`). `data/common.yaml` holds names identical in brew and pacman/AUR (`kpi::packages::common::pkgs`, Linux + macOS); OS-specific names go in `data/os/Archlinux.yaml` / `Darwin.yaml` / `windows.yaml`, never in both. Adding a package = editing YAML, not manifests.
- `kpi::install::macos` checks idempotency via `brew list` / `brew tap`, and a fully qualified `owner/tap/formula` name declares its tap automatically. Casks that run a sudo'ed `.pkg` (e.g. `macfuse`) can't prompt from inside puppet (execs run without a tty), so `./run` installs those interactively first.
- `kpi::darwin` (`darwin.pp`) — macOS-only user session setup declared from `kpi::home`: Caps Lock → Control (hidutil LaunchAgent), the outer `wk` tmux server at login (LaunchAgent, counterpart of `tmux.service`), key repeat defaults, docker CLI plugin links, and the iTerm2 dynamic profile (Left Option = Esc+). iTerm hot-reloads dynamic profiles but reads the *default* profile only at launch, so after the first apply iTerm needs a restart (tmux sessions survive); its AppleScript can't switch a live session's profile. Reusable defined types: `kpi::darwin::launch_agent` (renders `launch_agent.plist.epp`, loads it with `launchctl bootstrap`) and `kpi::darwin::default` (idempotent `defaults write`).
- `kpi::base_devel` — meta-class pulling in `os`, `packages`, `packages::system`, `packages::optional`, `repos`, plus the per-OS dev toolchain (`kpi::base_devel::pkgs` in data).
- `kpi::home` — deploys `modules/kpi/files/home/` recursively into `$home_dir`. Windows is a special branch that also copies into `AppData/Roaming/Code/User` and `AppData/Roaming/Zed`. Also clones helper repos (emacs config, oh-my-zsh, fzf), runs `uv tool install dot-tools`, sets up tmux, and creates symlinks into `~/.keys/` and `~/Yandex.Disk/`.
- `kpi::repos`, `kpi::system`, `kpi::tailscale_priv` — OS repo setup, systemd units, tailscale-specific helpers.

`modules/kpi/files/home/` holds the dotfiles shared by every OS and is mirrored into the user's home directory by `kpi::home`. Per-OS overlays are merged on top of it (`sourceselect => all`, `home/` wins on clashes): `linux_home/` (X11/Wayland/KDE configs, systemd user units, hyprland/niri/rofi scripts) and `osx_home/`. Windows only gets `home/.config` plus the editor dirs. Don't put anything under `~/Library` in `osx_home/` — recursion would reset the `0700` dir modes; manage those files explicitly in `kpi::darwin` (sources in `files/darwin/`).

`modules/kpi/templates/*.epp` are Puppet EPP templates (chromium flags, hyprland, makepkg, sshj, tmux).

## Custom facts and the SSHJ knob

`modules/kpi/facts.d/user_data.py` is an external fact script that probes each `/home/*` and `/Users/*` user (only the invoking user's home when not root) for presence of `~/.ssh/id_rsa`, `~/.keys/ready`, `~/Yandex.Disk/wk_ssh2` and emits `<user>_<key>=True/False` facts.

`FACTER_SSHJ_FACT` (preferred) / `FACTER_SSHJ_SPEC` are env vars the `run` script forwards into the puppet apply. They feed the `$sshj_spec` variable in `hosts.pp`, which controls whether `kpi::home::sshj` deploys ssh-jail-style key config. On a fresh node before `~/.keys/` is mounted, you'll need to pass this manually: `FACTER_SSHJ_FACT=something ./run`.

## sync.py — reverse direction

`sync.py` is the **only** flow that copies in the opposite direction (live home → repo). For each file under `modules/kpi/files/home/` (plus `linux_home/` or `osx_home/`) it checks the corresponding file in `$HOME`; if they differ, it shows a diff and prompts to overwrite the repo copy from the live home. Use this to capture local config edits back into git. There's a Windows-specific path map (`Code/User`, `zed` → AppData) so the prompt works correctly on Windows.

## Python tooling (for sync.py and facts only)

- `pyproject.toml` targets Python 3.14, ruff line-length 120, single quotes, py314, imports sorted with `kpi`'s internal modules.
- `uv sync` installs dev deps (ruff, pyrefly, pre-commit, pytest).
- Pre-commit (`.pre-commit-config.yaml`) runs ruff + ruff-format + `uv run pyrefly check` on Python files, plus a battery of `pre-commit-hooks` checks. The `files:` filter restricts most checks to `modules/kpi/files/home/.local/` to avoid scanning the entire dotfile tree.

## Checking manifests without applying them

`test/check` compiles the catalog of every node in `test/facts/` (Arch `home`/`tpad`/`zz`, Windows `ww`, macOS `kpis-macbook-pro`) from any machine, with strict mode on, plus a syntax pass over all manifests and templates. Nothing is applied. Run it after every manifest/data change, especially for an OS you can't test on locally.

- `test/check --diff [REF]` also prints a unified diff of each node's catalog against `REF` (default `HEAD`). Use it to confirm a refactor is a no-op, or that a change only touches the OS it's meant to. Recursively deployed dotfiles don't show up there (they're expanded at apply time), only `File[$home]`'s `source` list.
- `test/check zz ww` limits it to those fixtures. A fixture's basename is the node name matched against `hosts.pp`; it only needs the facts the manifests read (`os`, `identity`, `processors`, `<user>_*`, `sshj_fact`).
- `test/compile_catalog.rb` does the actual compile through the Puppet Ruby API; it needs the stdlib/vcsrepo modules `./run` installs.

The real end-to-end test is still `./run` on a target machine.

## Conventions when editing manifests

- Use `kpi::install` not raw `package {}` to keep cross-platform behavior.
- Gate OS-specific blocks via `$kpi::os::is_arch` / `is_darwin` / `is_windows`, not by re-reading `$facts['os']`.
- On macOS puppet runs as the user (no sudo): no root-only resources, use `$facts['identity']` for the user/uid.
- When adding files under `modules/kpi/files/home/`, they will be deployed automatically by the recursive `file { $home: recurse => remote, ... }` in `kpi::home` — no manifest change needed.
- `kpi::home_repo` is the standard way to ensure a git checkout exists under the user's home (used for emacs config, oh-my-zsh, fzf).
- `kpi::home_link` / `kpi::home::keys_ssh_link` create symlinks into `~/.keys/` and `~/Yandex.Disk/` and assume those mounts exist; guard new ones similarly.
