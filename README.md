# dotfiles

Cross-platform setup for macOS, Debian, and Fedora.

## Fresh install

1. **(macOS only)** Sign in to iCloud
2. Run the bootstrap:

```bash
# Option A: one-liner
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/dotfiles/main/bootstrap.sh | bash

# Option B: clone first
git clone https://github.com/YOUR_USER/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

## What it does

| Step | macOS | Debian/Fedora |
|------|-------|---------------|
| Desktop defaults (list view, clean dock) | ✅ Finder + Dock | ✅ GNOME (Nautilus + Dash) |
| Build tools | ✅ Xcode CLI | ✅ apt/dnf build-essential |
| Homebrew | ✅ | ✅ Linuxbrew |
| CLI tools (zsh, podman, starship, fnm, devpod) | ✅ via Brewfile | ✅ via Brewfile.linux |
| GUI apps (Ghostty, 1Password, VS Code, Zed, …) | ✅ via casks | ❌ Manual |
| Dotfiles symlinked | ✅ | ✅ |
| DevPod providers (podman + ssh) | ✅ | ✅ |
| Homebrew zsh as default shell | ✅ | ✅ |
| Podman machine init | ✅ | — (native) |

## Re-linking dotfiles only

```bash
cd ~/dotfiles
./install.sh
```

## Structure

```
dotfiles/
├── bootstrap.sh          # Cross-platform setup script
├── install.sh            # Symlink-only script
├── Brewfile              # macOS: CLI + GUI apps
├── Brewfile.linux        # Linux: CLI tools only
├── zsh/
│   ├── .zshrc
│   └── .zshenv
├── starship/
│   └── starship.toml
├── git/
│   ├── .gitconfig
│   └── .gitignore
├── opencode/
│   └── config.json
└── devpod/
    └── (provider configs)
```
