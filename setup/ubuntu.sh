#!/bin/bash

# setup/ubuntu.sh — install the system packages these dotfiles need on a
# modern Ubuntu (24.04+/26.x) system, including Ubuntu under WSL, and mise
# (into ~/.local/bin, with its installer). Safe to re-run; optional packages are best-effort.
# setup/common.sh does the distro-independent rest.
#
# Normally run via ../install.sh.

set -euo pipefail

# shellcheck source=setup/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v apt-get >/dev/null 2>&1 || die "This script targets Ubuntu (apt-get not found)."

log "Updating apt package lists"
$SUDO apt-get update -y

# Core packages (required, reliably in the Ubuntu archive). CLI tools such as
# neovim, node, fzf and ripgrep come from mise (see setup/common.sh).
CORE_PKGS=(
    zsh git curl unzip ca-certificates fontconfig
    git-crypt git-lfs
    build-essential     # C compiler for nvim-treesitter parsers and cargo
    tmux
    wl-clipboard xclip xsel
)
log "Installing core packages"
$SUDO apt-get install -y "${CORE_PKGS[@]}"

# Optional packages — install each best-effort so a missing one doesn't abort.
OPTIONAL_PKGS=(tmuxinator)
log "Installing optional packages (best-effort)"
for pkg in "${OPTIONAL_PKGS[@]}"; do
    if $SUDO apt-get install -y "$pkg" >/dev/null 2>&1; then
        info "installed: $pkg"
    else
        warn "'$pkg' unavailable via apt — install manually if you want it"
    fi
done

# mise (tool version manager), with its installer into ~/.local/bin (on PATH
# via .profile and .shellrc.sh, which also run `mise activate`); update it
# with `mise self-update`.
export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
    log "mise already installed"
else
    log "Installing mise"
    curl -fsSL https://mise.run | sh
fi

