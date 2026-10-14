#!/bin/bash

# run.sh — set up a machine straight from GitHub: clone this repo (or update
# the clone), run install.sh, update the fonts (setup/ensure-fonts.sh, and
# install JetBrainsMono Nerd Font if it's missing), then set kitty, Alacritty
# and Sublime Text to it (set-font.sh). Safe to re-run.
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

    if [ -d "$DIR/.git" ]; then
        log "Updating $DIR"
        git -C "$DIR" pull --ff-only || warn "couldn't update $DIR; using it as is"
    elif [ -e "$DIR" ] && [ -n "$(ls -A "$DIR")" ]; then
        die "$DIR is in the way; move it or set RCFILES_DIR to clone elsewhere."
    else
        log "Cloning rcfiles to $DIR"
        mkdir -p "$(dirname "$DIR")"
        git clone "$REPO_URL" "$DIR"
    fi

    "$DIR/install.sh"

    # The mise tools install.sh installed (jq, for the font scripts) are only
    # on PATH in new shells.
    if command -v mise >/dev/null 2>&1; then
        eval "$(mise activate bash --shims)"
    fi

    # A font that won't download (a site being down, say) shouldn't stop the
    # rest.
    log "Updating fonts (setup/ensure-fonts.sh)"
    "$DIR/setup/ensure-fonts.sh" || warn "some fonts didn't update"
    # ensure-fonts.sh only updates fonts that are already installed.
    if [ -z "$(fc-list "$FONT" family 2>/dev/null)" ]; then
        log "Installing $FONT"
        "$DIR/setup/install-fonts.sh" --nerd JetBrainsMono || warn "couldn't install $FONT"
    fi

    log "Setting every app to $FONT $FONT_SIZE (set-font.sh)"
    "$DIR/set-font.sh" --all --apply "$FONT" "$FONT_SIZE"
}

# Piped into bash, stdin is this script: give the prompts in install.sh (the
# git identity) the terminal instead.
if [ ! -t 0 ] && { : </dev/tty; } 2>/dev/null; then
    main </dev/tty
else
    main
fi
