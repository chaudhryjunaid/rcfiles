#!/bin/bash

# setup/ensure-fonts.sh — update every font this machine got from a package,
# Nerd Fonts or Google Fonts to its latest version, via install-fonts.sh.
# Optional, like install-fonts.sh. Fonts it copied from a local folder are left
# alone. Updates
#   - the installed font packages (apt: fonts-*, ttf-*, otf-*; dnf: *fonts*)
#   - the Nerd Fonts in ~/.local/share/fonts/<Name>/
#   - the Google Fonts in ~/.local/share/fonts/google/<Family>/
# and moves loose font files in ~/.local/share/fonts whose family is on Google
# Fonts over to google/<Family>/: once Google's version is installed, the loose
# files go to ~/.rcfiles-backup/<timestamp>/.local/share/fonts/.
#
# Usage: setup/ensure-fonts.sh [--dry-run]

set -euo pipefail

SETUP=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck source=setup/lib.sh
. "$SETUP/lib.sh"

BACKUP_DIR="$HOME/.rcfiles-backup/$(date +%Y%m%d-%H%M%S)/.local/share/fonts"

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        -h|--help)    sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)            echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

for cmd in curl jq fc-scan; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found."
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

log "Looking for fonts to update"
nerd_catalog | jq -r '.fonts[].folderName' > "$TMP/nerd" \
    || die "Couldn't get the Nerd Fonts catalog."
google_get metadata/fonts | jq -r '.familyMetadataList[].family' > "$TMP/google" \
    || die "Couldn't get the Google Fonts catalog."

pkgs=()
if command -v apt-get >/dev/null 2>&1; then
    # shellcheck disable=SC2016 # ${db:...} is a dpkg-query format, not shell
    mapfile -t pkgs < <({ dpkg-query -W -f='${db:Status-Abbrev}\t${Package}\n' \
        'fonts-*' 'ttf-*' 'otf-*' 2>/dev/null || true; } | awk -F'\t' '$1 ~ /^ii/ { print $2 }')
elif command -v dnf >/dev/null 2>&1; then
    mapfile -t pkgs < <(rpm -qa --qf '%{name}\n' '*fonts*' | sort -u)
fi

# Loose files: "family<TAB>file" for each font file right in $FONT_DIR whose
# family is a Google Fonts family.
{ find "$FONT_DIR" -maxdepth 1 -type f \
      \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.otc' \) \
      -exec fc-scan --format '%{family[0]}\t%{file}\n' {} + 2>/dev/null || true; } |
    sort -u | awk -F'\t' '!seen[$2]++' |
    awk -F'\t' 'NR == FNR { google[$0] = 1; next } $1 in google' "$TMP/google" - > "$TMP/loose"
mapfile -t migrate < <(cut -f1 "$TMP/loose" | sort -u)
declare -A migrating=()
for family in "${migrate[@]}"; do migrating[$family]=1; done

nerd=()
for dir in "$FONT_DIR"/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    if grep -Fxq -- "$name" "$TMP/nerd"; then nerd+=("$name"); fi
done

google=()
for dir in "$FONT_DIR"/google/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    family=${name//_/ }
    if ! grep -Fxq -- "$family" "$TMP/google"; then
        warn "google/$name isn't a Google Fonts family; leaving it"
    elif [ -z "${migrating[$family]:-}" ]; then   # else migrating installs it
        google+=("$family")
    fi
done

info "packages (${#pkgs[@]}): ${pkgs[*]}"
info "Nerd Fonts (${#nerd[@]}): ${nerd[*]}"
info "Google Fonts (${#google[@]}): ${google[*]}"
info "loose files to move to Google Fonts (${#migrate[@]}):"
for family in "${migrate[@]}"; do
    count=$(FAMILY=$family awk -F'\t' '$1 == ENVIRON["FAMILY"]' "$TMP/loose" | wc -l)
    info "    $family ($count file$([ "$count" -eq 1 ] || echo s))"
done

if [ $((${#pkgs[@]} + ${#nerd[@]} + ${#google[@]} + ${#migrate[@]})) -eq 0 ]; then
    log "Nothing to update."
    exit 0
fi
if [ "$DRY_RUN" -eq 1 ]; then
    echo "(dry run: nothing was changed)"
    exit 0
fi

status=0
args=()
for name in "${pkgs[@]}"; do args+=(--package "$name"); done
for name in "${nerd[@]}"; do args+=(--nerd "$name"); done
for family in "${google[@]}"; do args+=(--google "$family"); done
if [ "${#args[@]}" -gt 0 ]; then
    "$SETUP/install-fonts.sh" "${args[@]}" || status=1
fi

# One family at a time, so its loose files are only moved once Google's
# version of it is in.
moved=0
for family in "${migrate[@]}"; do
    if ! "$SETUP/install-fonts.sh" --google "$family"; then
        warn "kept the loose $family files"
        status=1
        continue
    fi
    mkdir -p "$BACKUP_DIR"
    while IFS= read -r file; do
        info "move $file -> $BACKUP_DIR/"
        mv -- "$file" "$BACKUP_DIR/"
        moved=1
    done < <(FAMILY=$family awk -F'\t' '$1 == ENVIRON["FAMILY"] { print $2 }' "$TMP/loose")
done
if [ "$moved" -eq 1 ]; then
    log "Updating the font cache"
    fc-cache -f "$FONT_DIR" >/dev/null
fi

if [ "$status" -ne 0 ]; then
    warn "some fonts didn't update; see above"
fi
exit "$status"
