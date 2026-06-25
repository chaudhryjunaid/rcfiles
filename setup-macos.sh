#!/bin/bash

# setup-macos.sh — install the dependencies used by these dotfiles on macOS
# via Homebrew. Safe to re-run; it skips what's already present and treats
# each package as best-effort so one failure doesn't abort the rest.
#
# After this, run:  ./configure.sh  &&  ./setup-git-identity.sh

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script targets macOS (Darwin)." >&2
    exit 1
fi

# Install Homebrew if missing.
if ! command -v brew >/dev/null 2>&1; then
    echo "==> Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for this session (Apple Silicon only).
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "==> Updating Homebrew"
brew update

# Best-effort install of a formula / cask (warn instead of aborting).
brew_formula() {
    local f="$1"
    if brew list --formula "$f" >/dev/null 2>&1; then
        echo "    present: $f"
    elif brew install "$f"; then
        echo "    installed: $f"
    else
        echo "    WARN: could not install formula '$f'" >&2
    fi
}
brew_cask() {
    local c="$1"
    if brew list --cask "$c" >/dev/null 2>&1; then
        echo "    present: $c"
    elif brew install --cask "$c"; then
        echo "    installed: $c"
    else
        echo "    WARN: could not install cask '$c'" >&2
    fi
}

# CLI tools (formulae). zsh ships with macOS; the two zsh plugins are installed
# below as oh-my-zsh custom plugins.
FORMULAE=(
    git vim
    git-delta fzf ripgrep bat
    tmux
    starship
    fnm tmuxinator
)
echo "==> Installing formulae"
for f in "${FORMULAE[@]}"; do
    brew_formula "$f"
done

# Apps and Nerd Fonts (casks).
CASKS=(
    kitty
    font-jetbrains-mono-nerd-font
    font-caskaydia-cove-nerd-font
    font-meslo-lg-nerd-font
)
echo "==> Installing casks (apps and Nerd Fonts)"
for c in "${CASKS[@]}"; do
    brew_cask "$c"
done

# oh-my-zsh (don't run zsh, don't chsh, keep the existing ~/.zshrc).
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "==> Installing oh-my-zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "==> oh-my-zsh already installed"
fi

# zsh plugins as oh-my-zsh custom plugins.
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
clone_plugin() {
    local repo="$1" dest="$2"
    if [ -d "$dest" ]; then
        echo "    present: $(basename "$dest")"
    else
        git clone --depth 1 "$repo" "$dest"
    fi
}
echo "==> Installing zsh plugins"
clone_plugin https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_plugin https://github.com/zsh-users/zsh-autosuggestions     "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

cat <<'NOTE'

Done installing dependencies. Next steps:
  1. ./configure.sh            # symlink the dotfiles into place
  2. ./setup-git-identity.sh   # set your git name/email
  3. Enable the zsh plugins in ~/.zshrc:
        plugins=(... zsh-autosuggestions zsh-syntax-highlighting)
  4. Restart your terminal and set your terminal/kitty font to a Nerd Font,
     e.g. "JetBrainsMono Nerd Font", "CaskaydiaCove Nerd Font", or
     "MesloLGS Nerd Font".
NOTE
