#!/bin/bash

# setup/fedora.sh — install the system packages these dotfiles need on a
# current Fedora (tested on 44), including Fedora under WSL, and mise from
# its rpm repo. liquidprompt isn't packaged for Fedora, so it's cloned from
# git. Safe to re-run. setup/common.sh does the distro-independent rest.
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
    util-linux          # chsh, missing from minimal installs
    gcc gcc-c++ make    # C compiler for nvim-treesitter parsers and cargo
    tmux
    wl-clipboard xclip xsel
)
log "Installing core packages"
$SUDO dnf install -y "${CORE_PKGS[@]}"

# mise (tool version manager), from its rpm repo so dnf keeps it updated.
if command -v mise >/dev/null 2>&1; then
    log "mise already installed"
else
    log "Installing mise"
    curl -fsSL https://mise.jdx.dev/rpm/mise.repo \
        | $SUDO tee /etc/yum.repos.d/mise.repo >/dev/null
    $SUDO dnf install -y mise
fi

# The rc files look for liquidprompt here when the distro doesn't ship it.
clone_once https://github.com/liquidprompt/liquidprompt.git \
    "$HOME/sh/liquidprompt" --branch stable

info "tmuxinator isn't packaged for Fedora; 'gem install tmuxinator' if you want it"
