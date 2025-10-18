# Local Puppet Setup

Puppet configuration for managing Linux, macOS, Windows, and WSL development environments.

## Supported Platforms

- **Linux** (Arch Linux)
- **macOS**
- **Windows** (with Chocolatey)
- **WSL** (Arch Linux)

## Prerequisites

### Linux (Arch Linux)
```bash
sudo pacman -S puppet git
```

### macOS
```bash
brew install puppet
brew install findutils
export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
```

### Windows
1. Install Puppet: https://puppet.com/docs/puppet/latest/install_windows.html
2. Install Chocolatey: https://chocolatey.org/install
3. Install Git (if not already installed)

### WSL (Arch Linux)
```bash
# Install Puppet and Git
sudo pacman -S puppet git

# Set hostname to distinguish from Windows
sudo hostnamectl set-hostname ww-wsl

# Create Puppet modules directory
sudo mkdir -p /etc/puppetlabs/code/modules

# Install required Puppet modules
sudo puppet module install puppetlabs-stdlib
sudo puppet module install puppetlabs-vcsrepo

# Verify modules are installed
puppet module list
```

## Usage

### Linux / macOS
```bash
./run
```

### Windows (PowerShell)
```powershell
.\run.ps1
```

### WSL
```bash
./run-wsl
```

### Force Update
To force a fresh pull and module update:

**Linux/macOS/WSL:**
```bash
./run clean
```

**Windows:**
```powershell
.\run.ps1 clean
```

## What Gets Installed

### Linux (Arch)
- Full development environment
- Editors: neovim, emacs, vim
- Window managers: Hyprland, Awesome
- Development tools: git, docker, node, go, etc.
- Fonts and themes

### macOS
- Development tools via Homebrew
- Terminal utilities
- Editors: nvim, vim

### Windows
- VSCode and Zed editors with configs
- Essential tools: git, 7zip, PowerShell Core
- Editor configs deployed to AppData

### WSL (Arch)
- Full Linux development environment (same as Linux)
- neovim and emacs with full configs
- All dev tools and utilities

## Node Configuration

Edit `manifests/hosts.pp` to add new machines. Examples:
- `ww` - Windows host
- `ww-wsl` - WSL host
- `home`, `tpad`, `dm4`, `xx`, `zz` - Linux hosts
- macOS hosts use full hostname

---

### macos

```
brew install findutils
export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
```


### sshj

By default should already be set from keys. On new node it won't be set until keys are monted.

```bash
FACTER_SSHJ_FACT=something ./run
```

### coding snippets


```puppet
case $::os['name'] {
  'Archlinux': {
    file { '/etc/pacman.conf':
      source => 'puppet:///modules/kpi/pacman.conf',
    }
    exec {"pacman -Sy":
      provider => shell,
      user => 'root',
      onlyif => '[ $(( $(date +%s) - $(stat -c %Y /var/lib/pacman/sync) )) -gt 1000 ]',
    }
  }
}
```
