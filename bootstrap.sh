#!/bin/bash
set -euo pipefail

# =============================================================================
# Cross-platform Bootstrap Script (macOS / Debian / Fedora)
# Run after a fresh install (+ iCloud login on macOS)
# Usage: curl -fsSL <your-raw-github-url>/bootstrap.sh | bash
#   or:  git clone <repo> ~/dotfiles && cd ~/dotfiles && ./bootstrap.sh
# =============================================================================

DOTFILES_REPO="https://github.com/samny/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
step()  { echo -e "\n${GREEN}==>${NC} $1\n"; }

# ---------------------------------------------------------------------------
# Detect OS and distro
# ---------------------------------------------------------------------------
OS="$(uname -s)"
DISTRO=""

detect_distro() {
  if [[ "$OS" == "Darwin" ]]; then
    DISTRO="macos"
  elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      debian|ubuntu|pop|linuxmint) DISTRO="debian" ;;
      fedora|rhel|centos|rocky|alma) DISTRO="fedora" ;;
      *)
        if [[ "${ID_LIKE:-}" == *"debian"* ]]; then
          DISTRO="debian"
        elif [[ "${ID_LIKE:-}" == *"fedora"* || "${ID_LIKE:-}" == *"rhel"* ]]; then
          DISTRO="fedora"
        else
          error "Unsupported distro: $ID"
          exit 1
        fi
        ;;
    esac
  else
    error "Cannot detect OS"
    exit 1
  fi

  info "Detected: $DISTRO"
}

# ---------------------------------------------------------------------------
# 1. Desktop defaults
# ---------------------------------------------------------------------------
configure_desktop() {
  step "Configuring desktop defaults"

  if [[ "$DISTRO" == "macos" ]]; then
    # Finder: always use list view
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true

    # Screen capture location
    mkdir -p ~/Downloads/Screenshots
    defaults write com.apple.screencapture location ~/Downloads/Screenshots

    # Dock: clear all apps, hide recents
    defaults write com.apple.dock persistent-apps -array
    defaults write com.apple.dock show-recents -bool false
    defaults write com.apple.dock tilesize -int 36

    # Disable Passwords app from AutoFill
    # TODO: This doesn't seem to work completely, is still get recommendation to save passwords in Safari
    defaults write com.apple.WebUI AutoFillPasswords -bool false
    defaults write com.apple.Passwords autofillEnabled -bool false
    pluginkit -e ignore -i com.apple.Passwords

    killall Finder 2>/dev/null || true
    killall Dock 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true

  elif command -v gsettings &>/dev/null; then
    # GNOME: Nautilus always list view
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view' 2>/dev/null || true

    # Dash / Dock: small icons, hide trash & mounts
    gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 36 2>/dev/null || true
    gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false 2>/dev/null || true
    gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false 2>/dev/null || true

    # Clear pinned/favorite apps from the dock
    gsettings set org.gnome.shell favorite-apps '[]' 2>/dev/null || true

  else
    warn "No supported desktop environment detected, skipping"
    return
  fi

  info "Desktop defaults applied"
}

# ---------------------------------------------------------------------------
# 2. System prerequisites
# ---------------------------------------------------------------------------
install_prerequisites() {
  step "Installing system prerequisites"

  case "$DISTRO" in
    macos)
      if xcode-select -p &>/dev/null; then
        info "Xcode CLI tools already installed"
      else
        xcode-select --install 2>/dev/null || true
        echo "Waiting for Xcode CLI tools to finish installing..."
        local timeout=1800  # 30 minutes
        local elapsed=0
        until xcode-select -p &>/dev/null; do
          sleep 5
          elapsed=$((elapsed + 5))
          if [ "$elapsed" -ge "$timeout" ]; then
            echo "Timed out waiting for Xcode CLI tools. Please install manually and rerun."
            exit 1
          fi
        done
        info "Xcode CLI tools installed."
      fi
      ;;
    debian)
      sudo apt-get update
      sudo apt-get install -y build-essential procps curl file git zsh
      ;;
    fedora)
      sudo dnf groupinstall -y "Development Tools"
      sudo dnf install -y procps-ng curl file git zsh
      ;;
  esac

  info "Prerequisites installed"
}

# ---------------------------------------------------------------------------
# 3. Homebrew (works on both macOS and Linux)
# ---------------------------------------------------------------------------
install_homebrew() {
  step "Installing Homebrew"

  if command -v brew &>/dev/null; then
    info "Homebrew already installed"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to current session PATH
    if [[ "$DISTRO" == "macos" && -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  fi

  brew update
  info "Homebrew ready"
}

# ---------------------------------------------------------------------------
# 4. Packages via Brewfile
# ---------------------------------------------------------------------------
install_packages() {
  step "Installing packages via Brewfile"

  local brewfile="$DOTFILES_DIR/Brewfile"

  brew bundle --file="$brewfile"

  info "All packages installed"
}

# ---------------------------------------------------------------------------
# 5. Clone dotfiles & create symlinks
# ---------------------------------------------------------------------------
setup_dotfiles() {
  step "Setting up dotfiles"

  if [[ -d "$DOTFILES_DIR" ]]; then
    info "Dotfiles directory already exists, pulling latest"
    git -C "$DOTFILES_DIR" pull
  else
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi

  "$DOTFILES_DIR/install.sh"

  info "Dotfiles linked"
}

# ---------------------------------------------------------------------------
# 6. DevPod providers
# ---------------------------------------------------------------------------
configure_devpod() {
  step "Configuring DevPod providers"

  devpod provider add docker --force --name podman \
    -o DOCKER_PATH=/opt/homebrew/bin/podman 2>/dev/null || true
  info "DevPod podman provider configured"

  devpod provider add ssh --force --name devpods-remote --option HOST=developer@devpods 2>/dev/null || true
  info "DevPod SSH provider added for host devpods"
}

# ---------------------------------------------------------------------------
# 7. Shell setup
# ---------------------------------------------------------------------------
configure_shell() {
  step "Configuring shell"

  local target_zsh
  target_zsh="$(brew --prefix)/bin/zsh"

  # Add brew zsh to allowed shells if needed
  if ! grep -qF "$target_zsh" /etc/shells; then
    echo "$target_zsh" | sudo tee -a /etc/shells
  fi

  if [[ "$SHELL" != "$target_zsh" ]]; then
    chsh -s "$target_zsh"
    info "Default shell changed to Homebrew zsh"
  else
    info "Homebrew zsh already default"
  fi

  # Podman machine is macOS-only — Linux runs podman natively
  if [[ "$DISTRO" == "macos" ]]; then
    if ! podman machine info &>/dev/null; then
      podman machine init
      podman machine start
      info "Podman machine initialized and started"
    else
      info "Podman machine already exists"
    fi
  fi
}

set_wallpaper() {
  if [[ "$DISTRO" == "macos" ]]; then
    step "Setting wallpaper"
    desktoppr ~/.config/wallpaper/wallpaper.jxl
    info "Wallpaper set"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║      Cross-platform Bootstrap        ║"
  echo "╚══════════════════════════════════════╝"
  echo ""

  detect_distro

  configure_desktop
  install_prerequisites
  setup_dotfiles
  install_homebrew
  install_packages
  configure_shell
  configure_devpod
  set_wallpaper

  echo ""
  step "All done! Open a new terminal to load your config."
  echo "  Remaining manual steps:"
  if [[ "$DISTRO" == "macos" ]]; then
    echo "  • Sign in to 1Password"
    echo "  • Install 1Password for Safari"
    echo "  • Allow 1Password to control the computer in System Settings / Privacy & Security / Accessibility"
    echo "  • Disable autofill Passwords in System Settings / General / AutoFill & Passwords and in Safari Settings / Autofill"
    echo "  • Set DuckDuckGo as search engine"
    echo "  • Enable Zoom in System Settings / Accessibility / Zoom"
  else
    echo "  • Install GUI apps manually (1Password, VS Codium, Zed, etc.)"
  fi
  echo ""
}

main "$@"
