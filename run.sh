#!/bin/bash

# run.sh — set up a machine straight from GitHub: clone this repo (or update
# the clone), run install.sh, install the programming fonts
# (setup/ensure-fonts.sh: JetBrainsMono Nerd Font and nine others), then, on
# the first run only (a fresh clone), set kitty, Alacritty, Ghostty and
# Sublime Text to JetBrainsMono Nerd Font (set-font.sh). Later runs leave the font settings alone, since set-font.sh
# edits tracked files and a machine's own pick shouldn't be reset. Safe to
# re-run.
#
# The clone goes to $RCFILES_DIR (default ~/setup/rcfiles) and has to stay
# there: link.sh symlinks the dotfiles in $HOME into it.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/chaudhryjunaid/rcfiles/master/run.sh | bash
#    or: wget -qO- https://raw.githubusercontent.com/chaudhryjunaid/rcfiles/master/run.sh | bash

set -euo pipefail

REPO_URL=https://github.com/chaudhryjunaid/rcfiles.git
DIR=${RCFILES_DIR:-$HOME/setup/rcfiles}
FONT="JetBrainsMono Nerd Font"
FONT_SIZE=16

log()  { echo "==> $*"; }
warn() { echo "    WARN: $*" >&2; }
die()  { echo "$*" >&2; exit 1; }

# Everything runs from main, called on the last line, so bash has read the
# whole script before running any of it: a download cut short runs nothing.
main() {
    local sudo=""
    if [ "$(id -u)" -ne 0 ]; then sudo="sudo"; fi

    if ! command -v git >/dev/null 2>&1; then
        log "Installing git"
        if command -v apt-get >/dev/null 2>&1; then
            $sudo apt-get update -q && $sudo apt-get install -y git
        elif command -v dnf >/dev/null 2>&1; then
            $sudo dnf install -y git
        else
            die "git not found; install it and rerun."
        fi
    fi

    local fresh=0
    if [ -d "$DIR/.git" ]; then
        log "Updating $DIR"
        # --autostash: local edits (a font set-font.sh picked, say) don't block
        # the update.
        git -C "$DIR" pull --ff-only --autostash || warn "couldn't update $DIR; using it as is"
    elif [ -e "$DIR" ] && [ -n "$(ls -A "$DIR")" ]; then
        die "$DIR is in the way; move it or set RCFILES_DIR to clone elsewhere."
    else
        log "Cloning rcfiles to $DIR"
        mkdir -p "$(dirname "$DIR")"
        git clone "$REPO_URL" "$DIR"
        fresh=1
    fi

    "$DIR/install.sh"

    # The mise tools install.sh installed (fzf, jq, ...) are only on PATH in
    # new shells.
    if command -v mise >/dev/null 2>&1; then
        eval "$(mise activate bash --shims)"
    fi

    # The programming fonts (JetBrainsMono Nerd Font among them). A font that
    # won't download (GitHub being down, say) shouldn't stop the rest.
    log "Installing fonts (setup/ensure-fonts.sh)"
    "$DIR/setup/ensure-fonts.sh" || warn "some fonts didn't install"

    if [ "$fresh" -eq 1 ]; then
        log "Setting every app to $FONT $FONT_SIZE (set-font.sh)"
        "$DIR/set-font.sh" all "$FONT" "$FONT_SIZE"
    else
        log "Leaving the font settings alone (existing clone); change them with $DIR/set-font.sh"
    fi
}

# Piped into bash, stdin is this script: give the prompts in install.sh (the
# git identity) the terminal instead.
if [ ! -t 0 ] && { : </dev/tty; } 2>/dev/null; then
    main </dev/tty
else
    main
fi
