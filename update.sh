#!/bin/bash

# update.sh — update everything this repo sets up, in one go:
#   1. this checkout (git pull) and the links (link.sh)
#   2. mise itself and the mise tools set to "latest" (mise upgrade)
#   3. zsh plugins (antidote), liquidprompt, the tmux plugins
#   4. nvim plugins (lazy.nvim, which rewrites lazy-lock.json in this
#      checkout) and treesitter parsers
#   5. the fonts (setup/ensure-fonts.sh) and the tldr pages
# A step that fails is reported and the rest still run. System packages are
# left to apt/dnf (and unattended-upgrades). Ends by listing what changed in
# this checkout (e.g. lazy-lock.json) for you to review and commit.
#
# Usage: ./update.sh [--no-pull] [--no-fonts]

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=setup/lib.sh
. "$REPO/setup/lib.sh"

PULL=1
FONTS=1
for arg in "$@"; do
    case "$arg" in
        --no-pull) PULL=0 ;;
        --no-fonts) FONTS=0 ;;
        -h | --help)
            sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

# mise's tools (nvim, tldr, ...) for this non-interactive shell.
export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash --shims)"
fi

failed=()
# step <name> <command...>: run one step; on failure note it and go on.
step() {
    local name=$1
    shift
    log "$name"
    if ! "$@"; then
        warn "$name failed"
        failed+=("$name")
    fi
}

# The update_* functions run inside step's `if`, where set -e is off: each
# one checks its commands itself, so a failure makes the step fail.

# git_pull_dir <dir>: fast-forward a plugin clone, if it's there.
git_pull_dir() {
    local out
    [ -d "$1/.git" ] || return 0
    if out=$(git -C "$1" pull --ff-only --quiet 2>&1); then
        info "$(basename "$1"): $(git -C "$1" log -1 --format='%h %cr')"
    else
        warn "$(basename "$1"): $out"
        return 1
    fi
}

update_repo() {
    git -C "$REPO" pull --ff-only --autostash
}

update_mise() {
    # Installed by its installer (Ubuntu) it can update itself; from the rpm
    # repo (Fedora) dnf does that, and self-update refuses.
    mise self-update --yes 2>/dev/null || info "mise itself: left to the package manager"
    mise upgrade --yes
}

update_shell_plugins() {
    local dir rc=0
    if [ -f "$HOME/sh/antidote/antidote.zsh" ] && command -v zsh >/dev/null 2>&1; then
        zsh -c 'source ~/sh/antidote/antidote.zsh && antidote update' || rc=1
    fi
    git_pull_dir "$HOME/sh/liquidprompt" || rc=1
    for dir in "$HOME"/.config/tmux/plugins/*/; do
        git_pull_dir "${dir%/}" || rc=1
    done
    return "$rc"
}

update_nvim() {
    command -v nvim >/dev/null 2>&1 || {
        info "nvim not found"
        return 0
    }
    # Lazy sync: install missing, update to the newest commits, clean removed
    # ones, and write the new commits to lazy-lock.json.
    nvim --headless "+Lazy! sync" +qa || return
    nvim --headless "+lua require('nvim-treesitter').update():wait(600000)" +qa
}

update_tldr() {
    command -v tldr >/dev/null 2>&1 || return 0
    tldr --update --quiet
}

[ "$PULL" -eq 0 ] || step "Updating this checkout (git pull)" update_repo
step "Linking dotfiles" "$REPO/link.sh"
command -v mise >/dev/null 2>&1 && step "Updating mise and its tools" update_mise
step "Updating antidote, liquidprompt and the tmux plugins" update_shell_plugins
step "Updating nvim plugins and treesitter parsers" update_nvim
[ "$FONTS" -eq 0 ] || step "Updating fonts" "$REPO/setup/ensure-fonts.sh"
step "Updating tldr pages" update_tldr

echo
if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
    log "Changed in this checkout (review, then commit):"
    git -C "$REPO" status --short | sed 's/^/    /'
fi
if [ "${#failed[@]}" -gt 0 ]; then
    warn "failed: $(printf '%s; ' "${failed[@]}")"
    exit 1
fi
log "Everything is up to date."
