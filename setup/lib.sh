# Helpers shared by the setup scripts. Source it, don't run it:
#   . "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck shell=bash

log()  { echo "==> $*"; }
info() { echo "    $*"; }
warn() { echo "    WARN: $*" >&2; }
die()  { echo "$*" >&2; exit 1; }

# Use sudo only when not already root.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi
export SUDO

IS_WSL=0
if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=1
fi
export IS_WSL

# clone_once <repo-url> <dest>: shallow-clone unless dest already exists.
clone_once() {
    local url="$1" dest="$2"
    if [ -d "$dest" ]; then
        log "$(basename "$dest") already installed"
    else
        log "Installing $(basename "$dest")"
        mkdir -p "$(dirname "$dest")"
        git clone --depth=1 "$url" "$dest"
    fi
}

# Antidote (zsh plugin manager) — sourced from ~/sh/antidote by .zshrc.common.
install_antidote() {
    clone_once https://github.com/mattmc3/antidote.git "$HOME/sh/antidote"
}
