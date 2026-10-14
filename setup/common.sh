#!/bin/bash

# setup/common.sh — the distro-independent part of the setup: antidote,
# liquidprompt, rustup, the mise tools, the Nerd Fonts, and zsh as the login
# shell. Run it after setup/<distro>.sh has installed the system packages and
# mise. Safe to re-run. Under WSL, the Nerd Fonts are skipped: the terminal
# and its fonts live on the Windows side.
#
# Normally run via ../install.sh.

set -euo pipefail

# shellcheck source=setup/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )

for cmd in git curl unzip zsh mise; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found; run setup/<distro>.sh first."
done

# Antidote (zsh plugin manager) — sourced from ~/sh/antidote by .zshrc.
clone_once https://github.com/mattmc3/antidote.git "$HOME/sh/antidote"

# liquidprompt (prompt), latest release — sourced from ~/sh/liquidprompt by
# .zshrc and .bashrc.
clone_once https://github.com/liquidprompt/liquidprompt.git \
    "$HOME/sh/liquidprompt" --branch stable

# rustup, for the cargo that mise builds tokei with (it has no release
# binaries past 12.x).
if command -v cargo >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/cargo" ]; then
    log "cargo already installed"
else
    log "Installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --profile minimal
fi
export PATH="$HOME/.cargo/bin:$PATH"

# CLI tools (neovim, node, fzf, ripgrep, ...) from the repo's mise config,
# pointed at directly since link.sh may not have run yet.
log "Installing tools with mise"
MISE_GLOBAL_CONFIG_FILE="$REPO/home/.config/mise/config.toml" mise install --yes

# Nerd Fonts (patched with the powerline/icon glyphs kitty and vim-airline use).
FONT_DIR="$HOME/.local/share/fonts"
NERD_FONTS=(JetBrainsMono CascadiaCode Meslo)
NERD_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
if [ "$IS_WSL" -eq 1 ]; then
    log "WSL detected: skipping the Nerd Fonts"
    NERD_FONTS=()
fi
fonts_changed=0
for font in "${NERD_FONTS[@]}"; do
    dest="$FONT_DIR/$font"
    if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
        log "$font Nerd Font already installed"
        continue
    fi
    log "Installing $font Nerd Font"
    mkdir -p "$dest"
    tmpzip=$(mktemp --suffix=.zip)
    curl -fsSL -o "$tmpzip" "$NERD_BASE/$font.zip"
    unzip -o "$tmpzip" -d "$dest" >/dev/null
    rm -f "$tmpzip"
    fonts_changed=1
done
if [ "$fonts_changed" -eq 1 ]; then fc-cache -f "$FONT_DIR" >/dev/null; fi

# Make zsh the default login shell, by a path /etc/shells lists: on Fedora,
# where sbin is merged into bin, `command -v zsh` can answer /usr/sbin/zsh.
case "$(getent passwd "$(id -un)" | cut -d: -f7)" in
    */zsh) log "zsh is already the default shell" ;;
    *)
        ZSH_BIN=$(grep -m1 '/zsh$' /etc/shells || command -v zsh)
        log "Setting zsh as the default shell"
        $SUDO chsh -s "$ZSH_BIN" "$(id -un)" \
            || warn "could not change shell; run: chsh -s $ZSH_BIN"
        ;;
esac
