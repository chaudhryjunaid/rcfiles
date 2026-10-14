#!/bin/bash

# setup/install-fonts.sh — search for a font by name and install it. Optional:
# install.sh doesn't run it.
#
# Asks for a font name (or words from one) and lists the matches from
#   - the distro's packages (apt or dnf)
#   - the Nerd Fonts releases
#   - Google Fonts
#   - font files under FOLDER, searched recursively (default ~/media/fonts)
# then installs the ones you pick: packages system-wide, the rest into
# ~/.local/share/fonts (Nerd Fonts in <Name>/, the others in google/, local/).
# Given --package/--nerd/--google, it installs those without asking (for
# setup/ensure-fonts.sh). Either way, installed ones are updated to the latest.
#
# Usage: setup/install-fonts.sh [FOLDER]
#        setup/install-fonts.sh [--package NAME] [--nerd NAME] [--google FAMILY]...

set -euo pipefail

# shellcheck source=setup/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage_error() {
    echo "$*" >&2
    sed -n '16,17p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
}

# srcs/ids: the fonts to install, by source (packages, nerd, google, local)
# and id; given here or picked from the search below.
FOLDER="" srcs=() ids=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help) sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --package|--nerd|--google)
            [ "$#" -ge 2 ] || usage_error "$1 needs a name."
            case "$1" in --package) srcs+=(packages) ;; *) srcs+=("${1#--}") ;; esac
            ids+=("$2")
            shift 2 ;;
        -*) usage_error "Unknown option: $1" ;;
        *)  [ -z "$FOLDER" ] || usage_error "Give one FOLDER."
            FOLDER=$1
            shift ;;
    esac
done
[ -z "$FOLDER" ] || [ "${#ids[@]}" -eq 0 ] || usage_error "FOLDER is only for searching."
FOLDER=${FOLDER:-$HOME/media/fonts}
FOLDER=${FOLDER%/}

if command -v apt-get >/dev/null 2>&1; then PKG=apt
elif command -v dnf >/dev/null 2>&1; then PKG=dnf
else PKG=""
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---- catalogs ---------------------------------------------------------------
# catalog_<source> prints one line per font, as tab-separated: the text to
# match the query against, the id to install it by, and the label to list.

catalog_packages() {
    case "$PKG" in
        apt)
            apt-cache search --names-only '^(fonts|ttf|otf)-' |
                awk '{ name = $1; sub(/^[^ ]+ - /, ""); print name "\t" name "\t" name " — " $0 }' ;;
        dnf)
            # A real tab: dnf5 doesn't expand "\t" in --qf (dnf4 also adds a
            # newline of its own, hence NF to skip the blank lines).
            dnf -q repoquery --qf $'%{name}\t%{summary}\n' '*fonts*' | sort -u |
                awk -F'\t' 'NF { print $1 "\t" $1 "\t" $1 " — " $2 }' ;;
    esac
}

catalog_nerd() {
    nerd_catalog | jq -r '.fonts[]
        | [ "\(.unpatchedName) \(.patchedName) \(.folderName)",
            .folderName,
            "\(.patchedName) Nerd Font"
              + (if .patchedName == .unpatchedName then "" else " (\(.unpatchedName))" end)
              + " — \(.description | gsub("&amp;"; "&"))" ]
        | @tsv'
}

catalog_google() {
    google_get metadata/fonts | jq -r '.familyMetadataList[]
        | [.family, .family, "\(.family) — \(.category | ascii_downcase)"] | @tsv'
}

# One entry per font family (as fc-scan reads it from the files), so a family's
# weights and styles install together. Also writes "family<TAB>file" lines to
# $TMP/local-files.tsv for install_local_font.
catalog_local() {
    find "$FOLDER" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.otc' \) \
        -exec fc-scan --format '%{family[0]}\t%{file}\n' {} + | sort -u |
        awk -F'\t' '!seen[$2]++' > "$TMP/local-all.tsv" || true
    # Leave out a family's static/ copies when it has other files too (the
    # variable fonts, in Google's zips), as install_google_font does.
    awk -F'\t' 'NR == FNR { if ($2 !~ /\/static\//) has_main[$1] = 1; next }
                !(has_main[$1] && $2 ~ /\/static\//)' \
        "$TMP/local-all.tsv" "$TMP/local-all.tsv" > "$TMP/local-files.tsv"
    ROOT="$FOLDER/" awk -F'\t' '
        {
            rel = substr($2, length(ENVIRON["ROOT"]) + 1)
            dir = rel; if (!sub(/\/[^\/]*$/, "", dir)) dir = "."
            if (!($1 in count)) { order[++families] = $1; where[$1] = dir }
            else if (where[$1] != dir) elsewhere[$1] = ", ..."
            count[$1]++; paths[$1] = paths[$1] " " rel
        }
        END {
            for (i = 1; i <= families; i++) {
                f = order[i]
                printf "%s%s\t%s\t%s — %d file%s in %s%s\n", f, paths[f], f, f,
                    count[f], (count[f] > 1 ? "s" : ""), where[f], elsewhere[f]
            }
        }' "$TMP/local-files.tsv"
}

title() {
    case "$1" in
        packages) echo "$PKG packages" ;;
        nerd)     echo "Nerd Fonts" ;;
        google)   echo "Google Fonts" ;;
        local)    echo "${FOLDER/#$HOME/\~}" ;;
    esac
}

has() {
    local cmd
    for cmd in "$@"; do command -v "$cmd" >/dev/null 2>&1 || return 1; done
}

# ---- installers -------------------------------------------------------------
# Each returns non-zero on failure. They're called from if statements, where
# set -e is off, so every step checks its own status.

# install_google_font <family>: download its font files as
# $FONT_DIR/google/<Family>, replacing what was there only once that worked.
# Where a family has variable fonts plus static/ copies, only the variable ones
# keep the family's name (Inter's static ones are "Inter 18pt", ...), so the
# static/ copies are only taken when there is nothing else.
install_google_font() {
    local list dest name url n=0
    case "$1" in ''|*/*|.*) return 2 ;; esac   # $dest gets rm -rf'd
    dest="$FONT_DIR/google/${1// /_}"
    list=$(google_get "download/list?family=$(jq -rn --arg f "$1" '$f | @uri')") || return
    rm -rf "$dest.new" && mkdir -p "$dest.new" || return
    while IFS=$'\t' read -r name url; do
        curl -fsSL -o "$dest.new/$name" "$url" || { rm -rf "$dest.new"; return 1; }
        n=$((n + 1))
    done < <(jq -r '.manifest.fileRefs
        | map(select(.filename | startswith("static/") | not)) as $main
        | (if ($main | length) > 0 then $main else . end)[]
        | select(.filename | test("\\.(ttf|otf)$"))
        | [(.filename | split("/") | last), .url] | @tsv' <<< "$list")
    if [ "$n" -eq 0 ]; then rm -rf "$dest.new"; return 1; fi
    rm -rf "$dest" && mv "$dest.new" "$dest"
}

pkg_installed() {
    # shellcheck disable=SC2016 # ${db:...} is a dpkg-query format, not shell
    case "$PKG" in
        apt) [[ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" == ii* ]] ;;
        dnf) rpm -q "$1" >/dev/null 2>&1 ;;
    esac
}

# install_packages <name...>: install the missing ones and update the
# installed ones to the latest version. (--only-upgrade, unlike a plain
# install, leaves apt's automatically-installed mark alone.)
install_packages() {
    local pkg new=() old=()
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then old+=("$pkg"); else new+=("$pkg"); fi
    done
    case "$PKG" in
        apt) $SUDO apt-get update -qq &&
                 { [ "${#new[@]}" -eq 0 ] || $SUDO apt-get install -y "${new[@]}"; } &&
                 { [ "${#old[@]}" -eq 0 ] || $SUDO apt-get install -y --only-upgrade "${old[@]}"; } ;;
        dnf) { [ "${#new[@]}" -eq 0 ] || $SUDO dnf install -y "${new[@]}"; } &&
                 { [ "${#old[@]}" -eq 0 ] || $SUDO dnf upgrade -y "${old[@]}"; } ;;
        *)   return 1 ;;
    esac
}

# install_local_font <family>: copy its files from $FOLDER into $FONT_DIR/local/.
install_local_font() {
    local dest="$FONT_DIR/local/${1//\//_}" file
    mkdir -p "$dest" || return
    while IFS= read -r file; do
        cp -- "$file" "$dest/" || return
    done < <(FAMILY=$1 awk -F'\t' '$1 == ENVIRON["FAMILY"] { print $2 }' "$TMP/local-files.tsv")
}

# ---- load -------------------------------------------------------------------

SOURCES=()
# load <source>: build $TMP/<source>.tsv, sorted by label.
load() {
    if "catalog_$1" | sort -t $'\t' -k3,3f > "$TMP/$1.tsv"; then
        info "$(title "$1"): $(wc -l < "$TMP/$1.tsv") fonts"
        SOURCES+=("$1")
    else
        warn "couldn't list the $(title "$1"); leaving them out"
    fi
}

load_sources() {
    if [ "$IS_WSL" -eq 1 ]; then
        warn "WSL: fonts installed here only reach Linux GUI apps; the terminal's fonts live on Windows"
    fi
    log "Listing fonts"
    if [ -n "$PKG" ]; then load packages; else info "no apt or dnf: leaving out packages"; fi
    if has curl jq unzip; then load nerd; else info "needs curl, jq and unzip: leaving out Nerd Fonts"; fi
    if has curl jq; then load google; else info "needs curl and jq: leaving out Google Fonts"; fi
    if [ -d "$FOLDER" ] && has fc-scan; then load local; else info "no $FOLDER (or no fc-scan): leaving it out"; fi
    [ "${#SOURCES[@]}" -gt 0 ] || die "Nothing to search."
}

# ---- search and pick --------------------------------------------------------

# filter_words <query>: keep the stdin lines whose match text (field 1) has
# every word of <query> in it, case-insensitively.
filter_words() {
    QUERY=$1 awk -F'\t' '
        BEGIN { n = split(tolower(ENVIRON["QUERY"]), words, " ") }
        { text = tolower($1); for (i = 1; i <= n; i++) if (!index(text, words[i])) next; print }'
}

# ask_picks <count>: read a choice like "1 3 5-7" and print the picked
# indexes (0-based), one per line. Fails on an empty answer.
ask_picks() {
    local answer tok lo hi i
    local -a toks picks
    while :; do
        read -rp "Install which (e.g. 1 3 5-7; Enter to search again)? " answer || return 1
        read -ra toks <<< "${answer//,/ }"
        [ "${#toks[@]}" -gt 0 ] || return 1
        picks=()
        for tok in "${toks[@]}"; do
            if [[ "$tok" =~ ^([0-9]+)(-([0-9]+))?$ ]]; then
                lo=$((10#${BASH_REMATCH[1]})) hi=$((10#${BASH_REMATCH[3]:-${BASH_REMATCH[1]}}))
                if [ "$lo" -ge 1 ] && [ "$lo" -le "$hi" ] && [ "$hi" -le "$1" ]; then
                    for ((i = lo; i <= hi; i++)); do picks+=("$((i - 1))"); done
                    continue
                fi
            fi
            echo "Not one of 1-$1: $tok" >&2
            continue 2
        done
        printf '%s\n' "${picks[@]}" | awk '!seen[$0]++'
        return 0
    done
}

# search_and_pick: ask for a query until something matches and gets picked;
# sets srcs/ids to the matches and $picked to the chosen indexes.
search_and_pick() {
    local query src id label i prev
    local -a words labels
    while :; do
        echo
        read -rp "Font to search for (Enter to quit): " query || { echo; exit 0; }
        read -ra words <<< "$query"
        [ "${#words[@]}" -gt 0 ] || exit 0

        srcs=() ids=() labels=()
        for src in "${SOURCES[@]}"; do
            while IFS=$'\t' read -r _ id label; do
                srcs+=("$src") ids+=("$id") labels+=("$label")
            done < <(filter_words "$query" < "$TMP/$src.tsv")
        done
        if [ "${#ids[@]}" -eq 0 ]; then
            echo "Nothing matches '$query'."
            continue
        fi

        prev=""
        for i in "${!ids[@]}"; do
            if [ "${srcs[i]}" != "$prev" ]; then
                prev=${srcs[i]}
                printf '\n%s:\n' "$(title "$prev")"
            fi
            printf '%4d) %s\n' "$((i + 1))" "${labels[i]}"
        done
        echo

        picked=$(ask_picks "${#ids[@]}") || continue
        return
    done
}

# ---- main -------------------------------------------------------------------

if [ "${#ids[@]}" -eq 0 ]; then
    asked=1
    load_sources
    search_and_pick
else
    asked=0
    picked=$(seq 0 $((${#ids[@]} - 1)))
fi

pkgs=() failed=() user_fonts=0
while IFS= read -r i; do
    id=${ids[i]}
    case "${srcs[i]}" in
        packages)
            pkgs+=("$id") ;;
        nerd)
            log "Installing $id Nerd Font"
            if install_nerd_font "$id"; then user_fonts=1; else failed+=("$id Nerd Font"); fi ;;
        google)
            log "Installing $id from Google Fonts"
            if install_google_font "$id"; then user_fonts=1; else failed+=("$id (Google Fonts)"); fi ;;
        local)
            log "Copying $id from $(title local)"
            if install_local_font "$id"; then user_fonts=1; else failed+=("$id ($(title local))"); fi ;;
    esac
done <<< "$picked"

if [ "${#pkgs[@]}" -gt 0 ]; then
    log "Installing ${pkgs[*]}"
    install_packages "${pkgs[@]}" || failed+=("${pkgs[@]}")
fi

if [ "$user_fonts" -eq 1 ]; then
    log "Updating the font cache"
    fc-cache -f "$FONT_DIR" >/dev/null
fi

if [ "${#failed[@]}" -gt 0 ]; then
    warn "failed: ${failed[*]}"
    exit 1
fi
if [ "$asked" -eq 1 ]; then
    log "Done. To use it: ./set-font.sh APP|--all FONT SIZE (partial names work)"
fi
