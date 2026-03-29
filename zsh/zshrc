# ──────────────────────────────────────────────────────────────────────────────
# .zshrc — your config goes here
# ──────────────────────────────────────────────────────────────────────────────

# Homebrew (macOS Apple Silicon / macOS Intel / Linux)
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Starship prompt
eval "$(starship init zsh)"

# fnm (Node version manager)
eval "$(fnm env --use-on-cd --shell zsh)"

# ── Your aliases, functions, etc below ───────────────────────────────────────


# --- XDG base dirs (optional but common) ---
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# --- Completion ---
autoload -Uz compinit
compinit

# --- Autosuggestions (fish-like) ---
# Apple Silicon Homebrew path:
if [ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -f /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# --- Syntax highlighting (fish-like) ---
# Must be loaded LAST.
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Find the real binaries (so our functions can call them)
NPM_BIN="$(command -v npm)"
YARN_BIN="$(command -v yarn)"

# Helper: run a command with VOLVO_CARS_PAT injected
_op_with_pat() {
  op run --env-file "$HOME/.config/volvo/op.env" -- "$@"
}

# Shadow npm: inject token only for install commands
npm() {
  local subcmd="${1:-}"
  case "$subcmd" in
    install|i|ci)
      _op_with_pat "$NPM_BIN" "$@"
      ;;
    *)
      "$NPM_BIN" "$@"
      ;;
  esac
}

# Shadow yarn: inject for install commands (including bare "yarn")
yarn() {
  local subcmd="${1:-}"
  case "$subcmd" in
    ""|install|add)
      _op_with_pat "$YARN_BIN" "$@"
      ;;
    *)
      "$YARN_BIN" "$@"
      ;;
  esac
}

# On-demand: load VOLVO_CARS_PAT from 1Password
loadpat() {
  if ! command -v op >/dev/null 2>&1; then
    echo "op CLI not found. Install with: brew install --cask 1password-cli" >&2
    return 127
  fi

  local pat
  pat="$(op read 'op://Private/GitHub/personal_access_token_packages')" || return $?
  export VOLVO_CARS_PAT="$pat"
  export SUPPORT_SHARED_GITHUB_TOKEN="$pat"
  echo "VOLVO_CARS_PAT loaded into environment for this shell."
}

work_on() {
  loadpat || return $?
  
  local workspace_name repo_path provider ide
  workspace_name=$(basename "$1" | tr ' ' '-' | tr -cd '[:alnum:]-_')
  repo_path=$(echo "$1" | tr ' ' '-' | tr -cd '[:alnum:]-_/')
  provider=${2:-podman}
  ide=${3:-zed}
  
  # Shift away consumed positional arguments
  if [[ $# -ge 3 ]]; then
    shift 3
  else
    shift $#
  fi

  devpod up \
    "https://github.com/$repo_path" \
    --workspace-env-file <(echo "VOLVO_CARS_PAT=$VOLVO_CARS_PAT") \
    --provider "$provider" \
    --ide "$ide" \
    --id "${workspace_name}-${provider}" \
    "$@"
}

alias docker=podman
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
export PATH="/opt/homebrew/opt/gradle@8/bin:$PATH"
