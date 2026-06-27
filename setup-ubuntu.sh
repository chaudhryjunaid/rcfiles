#!/bin/bash

# setup-ubuntu.sh — install the dependencies used by these dotfiles on a
# modern Ubuntu (24.04+/26.x) system. Safe to re-run; it skips what's already
# present and treats optional packages as best-effort.
#
# After this, run:  ./configure.sh  &&  ./setup-git-identity.sh

set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script targets Ubuntu/Debian (apt-get not found)." >&2
    exit 1
fi

# Use sudo only when not already root.
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "==> Updating apt package lists"
$SUDO apt-get update -y

# Core packages (required, reliably in the Ubuntu archive).
CORE_PKGS=(
    zsh git curl unzip ca-certificates fontconfig
    vim-gtk3            # vim built with +clipboard
    fzf ripgrep bat
    tmux
    wl-clipboard xclip xsel
)
echo "==> Installing core packages"
$SUDO apt-get install -y "${CORE_PKGS[@]}"

# Optional packages — install each best-effort so a missing one doesn't abort.
OPTIONAL_PKGS=(git-delta duf tmuxinator kitty zoxide eza liquidprompt)
echo "==> Installing optional packages (best-effort)"
for pkg in "${OPTIONAL_PKGS[@]}"; do
    if $SUDO apt-get install -y "$pkg" >/dev/null 2>&1; then
        echo "    installed: $pkg"
    else
        echo "    WARN: '$pkg' unavailable via apt — install manually if you want it" >&2
    fi
done

git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-~}/.antidote

# fnm (Node version manager). --skip-shell: our rc files handle the env line.
if ! command -v fnm >/dev/null 2>&1; then
    echo "==> Installing fnm"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
else
    echo "==> fnm already installed"
fi

# Nerd Fonts (patched with the powerline/icon glyphs kitty and vim-airline use).
FONT_DIR="$HOME/.local/share/fonts"
NERD_FONTS=(JetBrainsMono CascadiaCode Meslo)
NERD_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
fonts_changed=0
for font in "${NERD_FONTS[@]}"; do
    dest="$FONT_DIR/$font"
    if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
        echo "==> $font Nerd Font already installed"
        continue
    fi
    echo "==> Installing $font Nerd Font"
    mkdir -p "$dest"
    tmpzip=$(mktemp --suffix=.zip)
    curl -fsSL -o "$tmpzip" "$NERD_BASE/$font.zip"
    unzip -o "$tmpzip" -d "$dest" >/dev/null
    rm -f "$tmpzip"
    fonts_changed=1
done
[ "$fonts_changed" -eq 1 ] && fc-cache -f "$FONT_DIR" >/dev/null

# Make zsh the default login shell.
ZSH_BIN="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_BIN" ]; then
    echo "==> Setting zsh as the default shell"
    $SUDO chsh -s "$ZSH_BIN" "$(id -un)" \
        || echo "    WARN: could not change shell; run: chsh -s $ZSH_BIN" >&2
fi

cat <<'NOTE'

Done installing dependencies. Next steps:
  1. ./configure.sh            # symlink the dotfiles into place (incl. ~/.zshrc)
  2. ./setup-git-identity.sh   # set your git name/email
  3. Log out/in (or restart your terminal) to pick up zsh and the new fonts.
     Set your terminal font to a Nerd Font, e.g. "JetBrainsMono Nerd Font",
     "CaskaydiaCove Nerd Font" (Cascadia Code), or "MesloLGS Nerd Font".
NOTE
