#!/bin/bash

# setup/macos.sh — install the dependencies used by these dotfiles on macOS
# via Homebrew. Safe to re-run; it skips what's already present and treats
# each package as best-effort so one failure doesn't abort the rest.
#
# Normally run via ../install.sh.

set -euo pipefail

# shellcheck source=setup/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "$(uname -s)" = "Darwin" ] || die "This script targets macOS (Darwin)."

# Install Homebrew if missing.
if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for this session (Apple Silicon only).
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

log "Updating Homebrew"
brew update

# Best-effort install of a formula / cask (warn instead of aborting).
brew_formula() {
    local f="$1"
    if brew list --formula "$f" >/dev/null 2>&1; then
        info "present: $f"
    elif brew install "$f"; then
        info "installed: $f"
    else
        warn "could not install formula '$f'"
    fi
}
brew_cask() {
    local c="$1"
    if brew list --cask "$c" >/dev/null 2>&1; then
        info "present: $c"
    elif brew install --cask "$c"; then
        info "installed: $c"
    else
        warn "could not install cask '$c'"
    fi
}

# CLI tools (formulae). zsh ships with macOS; its plugins come via antidote.
# Neovim itself is installed by bob (below); tree-sitter-cli builds
# nvim-treesitter parsers.
FORMULAE=(
    git vim bob tree-sitter-cli
    git-delta fzf ripgrep bat
    tmux
    liquidprompt
    zoxide eza
    fnm tmuxinator
)
log "Installing formulae"
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
log "Installing casks (apps and Nerd Fonts)"
for c in "${CASKS[@]}"; do
    brew_cask "$c"
done

install_antidote
install_neovim
