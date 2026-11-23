#!/bin/bash

# setup/ensure-fonts.sh — download and install the programming fonts below,
# the Nerd Fonts builds (with the icon glyphs the tmux status bar and nvim's
# lualine use), from the latest Nerd Fonts release on GitHub. Each goes to
# ~/.local/share/fonts/<Name>/. run.sh runs it; it's safe to re-run:
#   - fonts that aren't installed are downloaded
#   - installed ones are re-downloaded only when a newer Nerd Fonts release is
#     out (the release they came from is kept in <Name>/.nerd-fonts-release),
#     or always with --update
# Other fonts in ~/.local/share/fonts (loose files, google/, ...) are left
# alone. For other fonts, use setup/install-fonts.sh.
#
# Usage: setup/ensure-fonts.sh [--dry-run] [--update]

set -euo pipefail

SETUP=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck source=setup/lib.sh
. "$SETUP/lib.sh"

# Nerd Fonts release asset names (<Name>.zip), and the family each installs.
FONTS=(
    "JetBrainsMono=JetBrainsMono Nerd Font"
    "CascadiaCode=CaskaydiaCove Nerd Font"
    "FiraCode=FiraCode Nerd Font"
    "Hack=Hack Nerd Font"
    "SourceCodePro=SauceCodePro Nerd Font"
    "Meslo=MesloLGS Nerd Font"
    "UbuntuMono=UbuntuMono Nerd Font"
    "IBMPlexMono=BlexMono Nerd Font"
    "VictorMono=VictorMono Nerd Font"
    "CommitMono=CommitMono Nerd Font"
)
STAMP=.nerd-fonts-release

DRY_RUN=0
UPDATE=0
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        -u|--update)  UPDATE=1 ;;
        -h|--help)    sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)            echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

for cmd in curl unzip fc-cache; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found."
done

# The latest release's tag (e.g. v3.5.1), or empty if GitHub can't be asked
# (then only missing fonts are installed).
latest=$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest 2>/dev/null |
    sed -n 's/^ *"tag_name": *"\([^"]*\)".*/\1/p' | head -n1) || latest=""
if [ -n "$latest" ]; then
    log "Nerd Fonts release: $latest"
else
    warn "couldn't look up the latest Nerd Fonts release; installing missing fonts only"
fi

todo=()
for entry in "${FONTS[@]}"; do
    name=${entry%%=*}
    dir="$FONT_DIR/$name"
    have=""
    [ -r "$dir/$STAMP" ] && have=$(< "$dir/$STAMP")
    if [ ! -d "$dir" ]; then
        reason="not installed"
    elif [ "$UPDATE" -eq 1 ]; then
        reason="--update"
    elif [ -n "$latest" ] && [ "$have" != "$latest" ]; then
        reason="${have:-unknown release} -> $latest"
    else
        info "ok       ${entry#*=} (${have:-installed})"
        continue
    fi
    info "install  ${entry#*=} ($reason)"
    todo+=("$name")
done

if [ "${#todo[@]}" -eq 0 ]; then
    log "All ${#FONTS[@]} fonts are installed and up to date."
    exit 0
fi
if [ "$DRY_RUN" -eq 1 ]; then
    echo "(dry run: nothing was downloaded)"
    exit 0
fi

failed=()
for name in "${todo[@]}"; do
    log "Downloading $name.zip"
    if install_nerd_font "$name"; then
        # The release the latest/download URL served (the tag looked up above,
        # barring a release in between).
        [ -z "$latest" ] || echo "$latest" > "$FONT_DIR/$name/$STAMP"
    else
        warn "couldn't install $name"
        failed+=("$name")
    fi
done

log "Updating the font cache"
fc-cache -f "$FONT_DIR" >/dev/null

if [ "${#failed[@]}" -gt 0 ]; then
    warn "failed: ${failed[*]}"
    exit 1
fi
log "Installed ${#todo[@]} font$([ "${#todo[@]}" -eq 1 ] || echo s); pick one with ./set-font.sh"
