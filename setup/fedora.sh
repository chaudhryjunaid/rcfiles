#!/bin/bash

# setup/fedora.sh — install the system packages these dotfiles need on a
# current Fedora (tested on 44), including Fedora under WSL, and mise from
# its rpm repo. Safe to re-run. setup/common.sh does the distro-independent
# rest.
#
# Normally run via ../install.sh.

set -euo pipefail

# shellcheck source=setup/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v dnf >/dev/null 2>&1 || die "This script targets Fedora (dnf not found)."

# Core packages (dnf refreshes its metadata itself). CLI tools such as neovim,
# node, fzf and ripgrep come from mise (see setup/common.sh).
CORE_PKGS=(
    zsh git curl unzip ca-certificates fontconfig
    git-crypt git-lfs
    util-linux       # chsh, missing from minimal installs
    gcc gcc-c++ make # C compiler for nvim-treesitter parsers and cargo
    tmux
    wl-clipboard xclip xsel
    neovim # system editor (root, sudo -i); you get mise's nvim
)
log "Installing core packages"
$SUDO dnf install -y "${CORE_PKGS[@]}"

# Make nvim the system default editor. Fedora picks it with a package that
# provides system-default-editor (nano-default-editor by default), whose
# /etc/profile.d script sets EDITOR in login shells; there's no neovim one,
# so this script, sorted after nano's, takes over from it. It leaves an
# EDITOR/VISUAL set to anything other than nano alone.
log "Setting nvim as the default editor (/etc/profile.d/zz-nvim-default-editor.sh)"
$SUDO tee /etc/profile.d/zz-nvim-default-editor.sh >/dev/null <<'EOF'
# Installed by rcfiles' setup/fedora.sh: nvim as the default editor. Runs
# after nano-default-editor.sh and overrides only nano (or nothing).
case "${EDITOR:-}" in
    ""|nano|/usr/bin/nano) EDITOR=/usr/bin/nvim; export EDITOR ;;
esac
case "${VISUAL:-}" in
    ""|nano|/usr/bin/nano) VISUAL=/usr/bin/nvim; export VISUAL ;;
esac
EOF

# mise (tool version manager), from its rpm repo so dnf keeps it updated.
if command -v mise >/dev/null 2>&1; then
    log "mise already installed"
else
    log "Installing mise"
    curl -fsSL https://mise.jdx.dev/rpm/mise.repo |
        $SUDO tee /etc/yum.repos.d/mise.repo >/dev/null
    $SUDO dnf install -y mise
fi

info "tmuxinator isn't packaged for Fedora; 'gem install tmuxinator' if you want it"
