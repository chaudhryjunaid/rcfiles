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

FONT_DIR="$HOME/.local/share/fonts"

# Print the distro to set up (ubuntu or fedora) from /etc/os-release: its ID,
# else the first supported ID_LIKE entry (e.g. Linux Mint -> ubuntu).
detect_distro() {
    local ids id
    [ -r /etc/os-release ] || return 1
    # shellcheck disable=SC1091
    ids=$(. /etc/os-release && echo "${ID:-} ${ID_LIKE:-}")
    for id in $ids; do
        case "$id" in
            ubuntu|fedora) echo "$id"; return 0 ;;
        esac
    done
    return 1
}

# install_nerd_font <name>: download the latest Nerd Fonts release asset
# <name>.zip (e.g. JetBrainsMono) and unpack it as $FONT_DIR/<name>, replacing
# what was there only once that worked. Run fc-cache afterwards.
install_nerd_font() {
    local dest="$FONT_DIR/$1" zip rc=0
    case "$1" in ''|*/*|.*) return 2 ;; esac   # $dest gets rm -rf'd
    zip=$(mktemp --suffix=.zip) || return
    rm -rf "$dest.new" && mkdir -p "$dest.new" &&
        curl -fsSL -o "$zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$1.zip" &&
        unzip -q "$zip" -d "$dest.new" &&
        rm -rf "$dest" && mv "$dest.new" "$dest" || rc=$?
    rm -rf "$zip" "$dest.new"
    return "$rc"
}

# nerd_catalog: print the Nerd Fonts catalog, JSON with a .fonts[] entry per
# font (.folderName is its release asset name).
nerd_catalog() {
    curl -fsSL https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/bin/scripts/lib/fonts.json
}

# google_get <path>: fetch a fonts.google.com JSON endpoint, minus the )]}'
# line some of them start with (an anti-XSSI guard). metadata/fonts lists
# every family (.familyMetadataList[].family).
google_get() {
    curl -fsSL "https://fonts.google.com/$1" | sed "1{/^)]}'/d;}"
}

# clone_once <repo-url> <dest> [git-clone-args...]: shallow-clone unless dest
# already exists.
clone_once() {
    local url="$1" dest="$2"
    shift 2
    if [ -d "$dest" ]; then
        log "$(basename "$dest") already installed"
    else
        log "Installing $(basename "$dest")"
        mkdir -p "$(dirname "$dest")"
        git clone --depth=1 "$@" "$url" "$dest"
    fi
}
