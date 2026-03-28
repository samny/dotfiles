#!/bin/bash
set -euo pipefail

# =============================================================================
# Dotfiles symlink installer
# Maps files from this repo to their expected locations
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

link_file() {
  local src="$1"
  local dest="$2"

  # Create parent directory if needed
  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -f "$dest" ]]; then
    mv "$dest" "${dest}.backup"
    echo -e "${YELLOW}[!]${NC} Backed up existing $dest → ${dest}.backup"
  fi

  ln -s "$src" "$dest"
  echo -e "${GREEN}[✓]${NC} $dest → $src"
}

# ── Zsh ──────────────────────────────────────────────────────────────────────
link_file "$DOTFILES_DIR/zsh/.zshrc"       "$HOME/.config/zsh/.zshrc"
link_file "$DOTFILES_DIR/zsh/.zshenv"      "$HOME/.zshenv"

# ── Starship ─────────────────────────────────────────────────────────────────
link_file "$DOTFILES_DIR/starship/starship.toml"  "$HOME/.config/starship.toml"

# ── Git ──────────────────────────────────────────────────────────────────────
link_file "$DOTFILES_DIR/git/.gitconfig"   "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/git/.gitignore"   "$HOME/.gitignore"

# ── OpenCode ─────────────────────────────────────────────────────────────────
link_file "$DOTFILES_DIR/opencode/config.json"  "$HOME/.config/opencode/config.json"

# ── DevPod ───────────────────────────────────────────────────────────────────
link_file "$DOTFILES_DIR/devpod/config.yaml" "$HOME/.devpod/config.yaml"

# ── Zed ───────────────────────────────────────────────────────────────────
link_file "$DOTFILES_DIR/zed/settings.json" "$HOME/.config/zed/settings.json"

echo ""
echo "All dotfiles linked!"
