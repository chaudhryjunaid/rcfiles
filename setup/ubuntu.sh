#!/bin/bash

# setup/ubuntu.sh — install the dependencies used by these dotfiles on a
# modern Ubuntu (24.04+/26.x) system, including Ubuntu under WSL. Safe to
# re-run; it skips what's already present and treats optional packages as
# best-effort. Under WSL, kitty and the Nerd Fonts are skipped: the terminal
# and its fonts live on the Windows side.
#
# Normally run via ../install.sh.

set -euo pipefail

# shellcheck source=setup/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v apt-get >/dev/null 2>&1 || die "This script targets Ubuntu/Debian (apt-get not found)."
[ "$IS_WSL" -eq 1 ] && log "WSL detected"

log "Updating apt package lists"
$SUDO apt-get update -y

# Core packages (required, reliably in the Ubuntu archive).
CORE_PKGS=(
    zsh git curl unzip ca-certificates fontconfig
    vim-gtk3            # vim built with +clipboard
    neovim
    fzf ripgrep bat
    tmux
    wl-clipboard xclip xsel
)
log "Installing core packages"
$SUDO apt-get install -y "${CORE_PKGS[@]}"

# Optional packages — install each best-effort so a missing one doesn't abort.
OPTIONAL_PKGS=(git-delta duf tmuxinator zoxide eza liquidprompt)
[ "$IS_WSL" -eq 0 ] && OPTIONAL_PKGS+=(kitty)
log "Installing optional packages (best-effort)"
for pkg in "${OPTIONAL_PKGS[@]}"; do
    if $SUDO apt-get install -y "$pkg" >/dev/null 2>&1; then
        info "installed: $pkg"
    else
        warn "'$pkg' unavailable via apt — install manually if you want it"
    fi
done

install_antidote

# fnm (Node version manager). --skip-shell: our rc files handle the env line.
if ! command -v fnm >/dev/null 2>&1 && [ ! -x "$HOME/.local/share/fnm/fnm" ]; then
    log "Installing fnm"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
else
    log "fnm already installed"
fi

# Nerd Fonts (patched with the powerline/icon glyphs kitty and vim-airline use).
FONT_DIR="$HOME/.local/share/fonts"
NERD_FONTS=(JetBrainsMono CascadiaCode Meslo)
NERD_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
[ "$IS_WSL" -eq 1 ] && NERD_FONTS=()
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

# Make zsh the default login shell.
ZSH_BIN="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_BIN" ]; then
    log "Setting zsh as the default shell"
    $SUDO chsh -s "$ZSH_BIN" "$(id -un)" \
        || warn "could not change shell; run: chsh -s $ZSH_BIN"
fi
