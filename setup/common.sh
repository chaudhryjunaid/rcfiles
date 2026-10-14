#!/bin/bash

# setup/common.sh — the distro-independent part of the setup: git-lfs's
# filters, antidote, liquidprompt, rustup, the mise tools, and zsh as the
# login shell. Run it after setup/<distro>.sh has installed the system
# packages and mise. Safe to re-run.
#
# Normally run via ../install.sh.

set -euo pipefail

# shellcheck source=setup/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )

for cmd in git curl zsh mise; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found; run setup/<distro>.sh first."
done

# git-lfs filters, in /etc/gitconfig: a plain `git lfs install` would write
# them into ~/.gitconfig, which is linked to the tracked home/.gitconfig.
if command -v git-lfs >/dev/null 2>&1; then
    log "Registering git-lfs filters system-wide"
    $SUDO git lfs install --system --skip-repo >/dev/null
fi

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
