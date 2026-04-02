#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Cross-platform Bootstrap Script (macOS / Debian / Fedora)
# Run after a fresh install (+ iCloud login on macOS)
# Usage: curl -fsSL <your-raw-github-url>/bootstrap.sh | bash
#   or:  git clone <repo> ~/dotfiles && cd ~/dotfiles && ./bootstrap.sh
# =============================================================================

DOTFILES_REPO="https://github.com/samny/dotfiles.git"
DOTFILES_DIR="${HOME}/dotfiles"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
step()  { echo -e "\n${GREEN}==>${NC} $1\n"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Safety: must NOT run as root
# ---------------------------------------------------------------------------
require_non_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    error "Do not run this script as root."
    echo "Run it as your normal user; it will use sudo for the steps that need it."
    echo "Example: ./bootstrap.sh"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Sudo management (best-effort keepalive)
# ---------------------------------------------------------------------------
SUDO_PID=""

sudo_init() {
  # If sudo isn't available (rare on macOS), just continue and let commands fail naturally.
  if ! have sudo; then
    warn "sudo not found; privileged steps may fail."
    return 0
  fi

  # Ask for password early so later steps don't fail mid-stream
  step "Requesting sudo permissions"
  sudo -v

  # Keep sudo alive until script exits
  (
    while true; do
      sleep 60
      sudo -n true 2>/dev/null || exit 0
    done
  ) &
  SUDO_PID="$!"
  info "sudo session active"
}

sudo_cleanup() {
  if [[ -n "${SUDO_PID}" ]]; then
    kill "${SUDO_PID}" 2>/dev/null || true
  fi
}
trap sudo_cleanup EXIT

# ---------------------------------------------------------------------------
# Detect OS and distro
# ---------------------------------------------------------------------------
OS="$(uname -s)"
DISTRO=""

detect_distro() {
  if [[ "$OS" == "Darwin" ]]; then
    DISTRO="macos"
  elif [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
      debian|ubuntu|pop|linuxmint) DISTRO="debian" ;;
      fedora|rhel|centos|rocky|alma) DISTRO="fedora" ;;
      *)
        if [[ "${ID_LIKE:-}" == *"debian"* ]]; then
          DISTRO="debian"
        elif [[ "${ID_LIKE:-}" == *"fedora"* || "${ID_LIKE:-}" == *"rhel"* ]]; then
          DISTRO="fedora"
        else
          error "Unsupported distro: ${ID:-unknown}"
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
    if ! have defaults; then
      warn "defaults command not found; skipping macOS defaults"
      return 0
    fi

    # Finder: always use list view
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" || true
    defaults write com.apple.finder ShowPathbar -bool true || true
    defaults write com.apple.finder ShowStatusBar -bool true || true
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true || true

    # Screen capture location
    mkdir -p "${HOME}/Downloads/Screenshots"
    defaults write com.apple.screencapture location "${HOME}/Downloads/Screenshots" || true

    # Dock: clear all apps, hide recents
    defaults write com.apple.dock persistent-apps -array || true
    defaults write com.apple.dock show-recents -bool false || true
    defaults write com.apple.dock tilesize -int 36 || true

    # Disable Passwords app from AutoFill (may vary by macOS version; don't fail hard)
    defaults write com.apple.WebUI AutoFillPasswords -bool false || true
    defaults write com.apple.Passwords autofillEnabled -bool false || true
    if have pluginkit; then
      pluginkit -e ignore -i com.apple.Passwords || true
    else
      warn "pluginkit not found; skipping Passwords plugin tweak"
    fi

    killall Finder 2>/dev/null || true
    killall Dock 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true

  elif have gsettings; then
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
    return 0
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
      if have xcode-select && xcode-select -p &>/dev/null; then
        info "Xcode CLI tools already installed"
      else
        if have xcode-select; then
          xcode-select --install 2>/dev/null || true
        fi
        echo "Waiting for Xcode CLI tools to finish installing..."
        local timeout=1800  # 30 minutes
        local elapsed=0
        until (have xcode-select && xcode-select -p &>/dev/null); do
          sleep 5
          elapsed=$((elapsed + 5))
          if [[ "$elapsed" -ge "$timeout" ]]; then
            error "Timed out waiting for Xcode CLI tools. Please install manually and rerun."
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
ensure_brew_in_path() {
  # Add brew to current session PATH if present (both macOS and Linuxbrew)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

install_homebrew() {
  step "Installing Homebrew"

  ensure_brew_in_path

  if have brew; then
    info "Homebrew already installed"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ensure_brew_in_path
  fi

  if ! have brew; then
    error "Homebrew installation did not result in a usable 'brew' in PATH."
    echo "Try opening a new shell, or ensure brew is installed at /opt/homebrew (macOS) or /home/linuxbrew/.linuxbrew."
    exit 1
  fi

  brew update
  info "Homebrew ready"
}

# ---------------------------------------------------------------------------
# 4. Packages via Brewfile
# ---------------------------------------------------------------------------
install_packages() {
  step "Installing packages via Brewfile"

  local brewfile="${DOTFILES_DIR}/Brewfile"

  if [[ ! -f "$brewfile" ]]; then
    warn "No Brewfile found at ${brewfile}; skipping brew bundle"
    return 0
  fi

  brew bundle --file="$brewfile"
  info "All packages installed"
}

# ---------------------------------------------------------------------------
# 5. Clone dotfiles & create symlinks
# ---------------------------------------------------------------------------
setup_dotfiles() {
  step "Setting up dotfiles"

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    info "Dotfiles directory already exists, pulling latest"
    git -C "$DOTFILES_DIR" pull
  elif [[ -d "$DOTFILES_DIR" ]]; then
    warn "Dotfiles dir exists but isn't a git repo: ${DOTFILES_DIR}"
    warn "Skipping clone; running install.sh if present"
  else
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi

  if [[ -x "$DOTFILES_DIR/install.sh" ]]; then
    "$DOTFILES_DIR/install.sh"
  else
    warn "install.sh not found or not executable at ${DOTFILES_DIR}/install.sh"
  fi

  info "Dotfiles linked"
}

# ---------------------------------------------------------------------------
# 6. DevPod providers
# ---------------------------------------------------------------------------
configure_devpod() {
  step "Configuring DevPod providers"

  if ! have devpod; then
    warn "devpod not installed; skipping provider configuration"
    return 0
  fi

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

  if ! have brew; then
    warn "brew not found; cannot configure Homebrew zsh"
    return 0
  fi

  local brew_prefix target_zsh user_name
  brew_prefix="$(brew --prefix)"
  target_zsh="${brew_prefix}/bin/zsh"
  user_name="${SUDO_USER:-${USER:-}}"

  if [[ -z "$user_name" ]]; then
    user_name="$(id -un)"
  fi

  if [[ ! -x "$target_zsh" ]]; then
    warn "Homebrew zsh not found at ${target_zsh}; skipping shell change"
    return 0
  fi

  # Add brew zsh to allowed shells if needed
  if [[ -r /etc/shells ]] && ! grep -qF "$target_zsh" /etc/shells; then
    echo "$target_zsh" | sudo tee -a /etc/shells >/dev/null
    info "Added ${target_zsh} to /etc/shells"
  fi

  # Change shell for the invoking user explicitly
  local current_shell
  current_shell="$(getent passwd "$user_name" 2>/dev/null | cut -d: -f7 || true)"
  if [[ -z "$current_shell" ]]; then
    # macOS fallback
    current_shell="$(dscl . -read "/Users/${user_name}" UserShell 2>/dev/null | awk '{print $2}' || true)"
  fi

  if [[ "$SHELL" != "$target_zsh" && "$current_shell" != "$target_zsh" ]]; then
    if chsh -s "$target_zsh" "$user_name" 2>/dev/null; then
      info "Default shell changed to Homebrew zsh for ${user_name}"
    else
      warn "Failed to change shell automatically. You may need to run:"
      echo "  chsh -s \"${target_zsh}\" \"${user_name}\""
    fi
  else
    info "Homebrew zsh already default"
  fi

  # Podman machine is macOS-only — Linux runs podman natively
  if [[ "$DISTRO" == "macos" ]]; then
    if have podman; then
      if ! podman machine info &>/dev/null; then
        podman machine init || true
        podman machine start || true
        info "Podman machine initialized and started"
      else
        info "Podman machine already exists"
      fi
    else
      warn "podman not installed; skipping podman machine setup"
    fi
  fi
}

set_wallpaper() {
  if [[ "$DISTRO" != "macos" ]]; then
    return 0
  fi

  step "Setting wallpaper"

  local wallpaper="${HOME}/.config/wallpaper/wallpaper.jxl"
  if ! have desktoppr; then
    warn "desktoppr not installed; skipping wallpaper"
    return 0
  fi
  if [[ ! -f "$wallpaper" ]]; then
    warn "Wallpaper file not found at ${wallpaper}; skipping"
    return 0
  fi

  desktoppr "$wallpaper" || true
  info "Wallpaper set"
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

  require_non_root
  detect_distro
  sudo_init

  configure_desktop
  install_prerequisites

  # Ensure brew exists before running anything that might depend on it
  install_homebrew

  # Install Brewfile packages before running dotfiles install (often depends on brew tools)
  setup_dotfiles
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
