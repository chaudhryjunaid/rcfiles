#!/bin/bash

# setup/common.sh — the distro-independent part of the setup: git-lfs's
# filters, antidote, liquidprompt, rustup, the mise tools (and gh's and
# btop's settings), zsh as the login
# shell, and hiding terminal programs' launchers from the app grid. Run it after setup/<distro>.sh has installed the system
# packages and mise. Safe to re-run.
#
# Normally run via ../install.sh.

set -euo pipefail

# shellcheck source=setup/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)

# mise may be in ~/.local/bin (its installer), which a fresh shell lacks.
export PATH="$HOME/.local/bin:$PATH"
for cmd in git curl zsh mise; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found; run setup/<distro>.sh first."
done

# git-lfs filters, in /etc/gitconfig, so every user and the first-run order
# (this runs before link.sh creates ~/.gitconfig) don't matter.
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

# tmux session save/restore plugins, loaded by ~/.config/tmux/tmux.conf.
clone_once https://github.com/tmux-plugins/tmux-resurrect.git \
    "$HOME/.config/tmux/plugins/tmux-resurrect"
clone_once https://github.com/tmux-plugins/tmux-continuum.git \
    "$HOME/.config/tmux/plugins/tmux-continuum"

# rustup, for the cargo that mise builds tokei with (it has no release
# binaries past 12.x).
if command -v cargo >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/cargo" ]; then
    log "cargo already installed"
else
    log "Installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
        sh -s -- -y --no-modify-path --profile minimal
fi
export PATH="$HOME/.cargo/bin:$PATH"

# CLI tools (neovim, node, fzf, ripgrep, ...) from the repo's mise config,
# pointed at directly since link.sh may not have run yet.
log "Installing tools with mise"
MISE_GLOBAL_CONFIG_FILE="$REPO/home/.config/mise/config.toml" mise install --yes

# Settings for tools that rewrite their own config files, so the files
# aren't tracked: gh clones and checks out over SSH, like the rest of the git
# setup; btop gets vim keys (hjkl) and the One Dark theme (the theme file is
# tracked: home/.config/btop/themes). Re-running resets these three, nothing
# else.
log "Setting gh and btop options"
MISE_GLOBAL_CONFIG_FILE="$REPO/home/.config/mise/config.toml" mise exec -- \
    gh config set git_protocol ssh || warn "couldn't set gh's git_protocol"
btop_conf=${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf
mkdir -p "$(dirname "$btop_conf")"
for setting in 'color_theme = "onedark"' 'vim_keys = true'; do
    key=${setting%% =*}
    if grep -q "^$key *=" "$btop_conf" 2>/dev/null; then
        sed -i "s|^$key *=.*|$setting|" "$btop_conf"
    else
        echo "$setting" >>"$btop_conf"
    fi
done

# Make zsh the default login shell, by a path /etc/shells lists: on Fedora,
# where sbin is merged into bin, `command -v zsh` can answer /usr/sbin/zsh.
case "$(getent passwd "$(id -un)" | cut -d: -f7)" in
    */zsh) log "zsh is already the default shell" ;;
    *)
        ZSH_BIN=$(grep -m1 '/zsh$' /etc/shells || command -v zsh)
        log "Setting zsh as the default shell"
        $SUDO chsh -s "$ZSH_BIN" "$(id -un)" ||
            warn "could not change shell; run: chsh -s $ZSH_BIN"
        ;;
esac

# Hide launchers that only open a terminal program from the app grid: vim
# and nvim (you start them from a shell), info and texdoctk (dependencies of
# ubuntu-standard and texlive). A copy in ~/.local/share/applications with
# NoDisplay=true overrides the system one; delete the copy to bring it back.
# A copy that's already there is left alone.
HIDE_LAUNCHERS=(vim nvim info texdoctk)
apps_dir=${XDG_DATA_HOME:-$HOME/.local/share}/applications
log "Hiding terminal-program launchers"
for name in "${HIDE_LAUNCHERS[@]}"; do
    src=/usr/share/applications/$name.desktop
    dest=$apps_dir/$name.desktop
    if [ -f "$src" ] && [ ! -e "$dest" ]; then
        mkdir -p "$apps_dir"
        sed '/^\[Desktop Entry\]/a NoDisplay=true' "$src" >"$dest"
        info "hid $name"
    fi
done
