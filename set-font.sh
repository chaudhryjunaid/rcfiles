#!/bin/bash
# shellcheck disable=SC2329 # the edit_*/current_* functions are called as "edit_$app"
# set-font.sh — set the font family and size in the app configs under home/.
#
# Interactive (no arguments):
#   1. pick the app from a numbered menu (kitty, Alacritty, Ghostty,
#      Sublime Text, or all of them)
#   2. pick the font in fzf from every font family installed on this system
#      (type to filter, Enter or Tab to choose; the preview lists its styles)
#   3. type the size (Enter keeps the current one)
#
# Scripted (run.sh uses this):  ./set-font.sh APP|all FONT SIZE
#   FONT must be the exact family name, as fc-list prints it.
#
# The configs are symlinked into $HOME, so this changes the live config too,
# and signals running kitty and Ghostty instances to reload it (Alacritty and
# Sublime Text reload on their own).

set -euo pipefail

REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
APPS=(kitty alacritty ghostty sublime)

print_help() {
    sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
}

die() { echo "$*" >&2; exit 1; }

config_for() {
    case "$1" in
        kitty)     echo "home/.config/kitty/kitty.conf" ;;
        alacritty) echo "home/.config/alacritty/alacritty.toml" ;;
        ghostty)   echo "home/.config/ghostty/config.ghostty" ;;
        sublime)   echo "home/.config/sublime-text/Packages/User/Preferences.sublime-settings" ;;
    esac
}

label_for() {
    case "$1" in
        kitty)     echo "kitty" ;;
        alacritty) echo "Alacritty" ;;
        ghostty)   echo "Ghostty" ;;
        sublime)   echo "Sublime Text" ;;
    esac
}

# current_<app> <file>: print "<family>\t<size>" as the config has them.
current_kitty() {
    awk '/^font_family[ \t]/ { sub(/^font_family[ \t]+/, ""); f = $0 }
         /^font_size[ \t]/   { sub(/^font_size[ \t]+/, "");   s = $0 }
         END { print f "\t" s }' "$1"
}
current_alacritty() {
    awk '/^[ \t]*\[/ { section = $0; gsub(/[ \t]/, "", section) }
         section == "[font]" && /^[ \t]*size[ \t]*=/ { sub(/^[^=]*=[ \t]*/, ""); s = $0 }
         section == "[font.normal]" && /^[ \t]*family[ \t]*=/ { sub(/^[^=]*=[ \t]*/, ""); gsub(/"/, ""); f = $0 }
         END { print f "\t" s }' "$1"
}
current_ghostty() {
    awk '/^font-family[ \t]*=/ { sub(/^[^=]*=[ \t]*/, ""); f = $0 }
         /^font-size[ \t]*=/   { sub(/^[^=]*=[ \t]*/, ""); s = $0 }
         END { print f "\t" s }' "$1"
}
current_sublime() {
    awk '/^[ \t]*"font_face"[ \t]*:/ { sub(/^[^:]*:[ \t]*"/, ""); sub(/".*$/, ""); f = $0 }
         /^[ \t]*"font_size"[ \t]*:/ { sub(/^[^:]*:[ \t]*/, ""); sub(/[ \t]*,?[ \t]*$/, ""); s = $0 }
         END { print f "\t" s }' "$1"
}

# 16 -> 16.0, matching how kitty and alacritty sizes are written.
as_float() {
    case "$1" in *.*) echo "$1" ;; *) echo "$1.0" ;; esac
}

# edit_<app> <file>: print the file with the font set. Exits non-zero if the
# expected keys aren't there. The font name is passed through the environment
# because awk -v would mangle backslashes.

# bold/italic_font stay "auto", i.e. derived from font_family.
edit_kitty() {
    FONT_NAME=$FONT FONT_SIZE=$(as_float "$SIZE") awk '
        /^font_family[ \t]/ { match($0, /^font_family[ \t]+/); $0 = substr($0, 1, RLENGTH) ENVIRON["FONT_NAME"]; f++ }
        /^font_size[ \t]/   { match($0, /^font_size[ \t]+/);   $0 = substr($0, 1, RLENGTH) ENVIRON["FONT_SIZE"]; s++ }
        { print }
        END { exit !(f && s) }
    ' "$1"
}

# size lives in [font]; family is repeated in [font.normal], [font.bold], ...
edit_alacritty() {
    FONT_NAME=$FONT FONT_SIZE=$(as_float "$SIZE") awk '
        /^[ \t]*\[/ { section = $0; sub(/^[ \t]*/, "", section); sub(/[ \t]*(#.*)?$/, "", section) }
        section == "[font]" && /^[ \t]*size[ \t]*=/ {
            match($0, /^[ \t]*size[ \t]*=[ \t]*/)
            $0 = substr($0, 1, RLENGTH) ENVIRON["FONT_SIZE"]; s++
        }
        section ~ /^\[font\.(normal|bold|italic|bold_italic)\]$/ && /^[ \t]*family[ \t]*=/ {
            match($0, /^[ \t]*family[ \t]*=[ \t]*/)
            $0 = substr($0, 1, RLENGTH) "\"" ENVIRON["FONT_NAME"] "\""; f++
        }
        { print }
        END { exit !(f && s) }
    ' "$1"
}

# bold/italic families default to font-family.
edit_ghostty() {
    FONT_NAME=$FONT FONT_SIZE=$SIZE awk '
        /^font-family[ \t]*=/ { match($0, /^font-family[ \t]*=[ \t]*/); $0 = substr($0, 1, RLENGTH) ENVIRON["FONT_NAME"]; f++ }
        /^font-size[ \t]*=/   { match($0, /^font-size[ \t]*=[ \t]*/);   $0 = substr($0, 1, RLENGTH) ENVIRON["FONT_SIZE"]; s++ }
        { print }
        END { exit !(f && s) }
    ' "$1"
}

# default_font_size is what "Reset Size" goes back to, so it follows font_size.
edit_sublime() {
    FONT_NAME=$FONT FONT_SIZE=$SIZE awk '
        function set(value,    comma) {
            comma = ($0 ~ /,[ \t]*$/) ? "," : ""
            match($0, /^[ \t]*"[a-z_]+"[ \t]*:[ \t]*/)
            $0 = substr($0, 1, RLENGTH) value comma
        }
        /^[ \t]*"font_face"[ \t]*:/             { set("\"" ENVIRON["FONT_NAME"] "\""); f++ }
        /^[ \t]*"(default_)?font_size"[ \t]*:/ { set(ENVIRON["FONT_SIZE"]); s++ }
        { print }
        END { exit !(f && s) }
    ' "$1"
}

# Every installed font family, by its main name (fontconfig's first family
# name; the others are short names and per-weight families of the same font).
list_fonts() {
    fc-list --format '%{family[0]}\n' | sort -u
}

# pick_app: numbered menu; sets the global "apps".
pick_app() {
    local -a labels=()
    local app cur choice
    for app in "${APPS[@]}"; do
        cur=$("current_$app" "$REPO/$(config_for "$app")")
        labels+=("$(printf '%-13s (now: %s %s)' "$(label_for "$app")" "${cur%%$'\t'*}" "${cur#*$'\t'}")")
    done
    labels+=("All of them")
    echo "Set the font for:" >&2
    local PS3="Option (1-${#labels[@]}): "
    select choice in "${labels[@]}"; do
        if [ -z "$choice" ]; then echo "Pick a number from 1 to ${#labels[@]}." >&2; continue; fi
        if [ "$REPLY" -eq "${#labels[@]}" ]; then
            apps=("${APPS[@]}")
        else
            apps=("${APPS[REPLY - 1]}")
        fi
        return 0
    done
    exit 1  # ctrl-d at the prompt
}

# pick_font <current family>: fzf over the installed families; prints the pick.
pick_font() {
    local current=$1
    # The preview lists the chosen family's styles (Regular, Bold, ...).
    list_fonts | fzf \
        --prompt="Font> " \
        --header="Enter or Tab to choose, Esc to cancel. Now: ${current:-?}" \
        --height=60% --layout=reverse --border \
        --bind 'tab:accept' \
        --preview "fc-list --format '%{family[0]}\t%{style[0]}\n' | awk -F'\t' -v f={} '\$1 == f { print \$2 }' | sort -u" \
        --preview-window 'right,40%,border-left' \
        --preview-label ' styles '
}

# ask_size <current size>: prompt until a number (or Enter for the current).
ask_size() {
    local current=$1 size
    while true; do
        read -rp "Font size${current:+ [$current]}: " size || exit 1
        size=${size:-$current}
        if [[ "$size" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [ "${size%%.*}" -gt 0 ]; then
            echo "$size"
            return
        fi
        echo "Enter a number, e.g. 14 or 13.5." >&2
    done
}

apply() {
    local app file status=0 before
    # Global, not local: the EXIT trap runs after this function returns.
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    for app in "${apps[@]}"; do
        file=$(config_for "$app")
        before=$("current_$app" "$REPO/$file")
        if ! "edit_$app" "$REPO/$file" > "$tmp"; then
            echo "$(label_for "$app"): font settings not found in $file; left alone" >&2
            status=1
            continue
        fi
        if cmp -s "$REPO/$file" "$tmp"; then
            echo "$(label_for "$app"): already $FONT $SIZE"
            continue
        fi
        # Overwrite in place (not mv) so the file keeps its mode.
        cat "$tmp" > "$REPO/$file"
        echo "$(label_for "$app"): ${before%%$'\t'*} ${before#*$'\t'} -> $FONT $SIZE ($file)"
        # kitty and Ghostty reload their config on SIGUSR1 and SIGUSR2.
        if [ "$app" = kitty ] && pkill -USR1 -x kitty; then
            echo "  reloaded the running kitty instances"
        fi
        if [ "$app" = ghostty ] && pkill -USR2 -x ghostty; then
            echo "  reloaded the running Ghostty instances"
        fi
    done
    return "$status"
}

check_font_name() {
    case "$FONT" in
        *[\"\\]*)        die "The font name can't contain quotes or backslashes." ;;
        *[![:space:]]*)  ;;
        *)               die "The font name is empty." ;;
    esac
}

apps=()
case "${1:-}" in
    -h|--help)
        print_help
        exit 0 ;;
    "")
        # Interactive.
        [ -t 0 ] && [ -t 2 ] || die "Run it in a terminal, or: ./set-font.sh APP|all FONT SIZE"
        command -v fzf >/dev/null 2>&1 || die "fzf not found (mise install)."
        command -v fc-list >/dev/null 2>&1 || die "fc-list not found (install fontconfig)."
        pick_app
        # The first app's current font and size are the defaults shown.
        cur=$("current_${apps[0]}" "$REPO/$(config_for "${apps[0]}")")
        FONT=$(pick_font "${cur%%$'\t'*}") || die "No font chosen; nothing changed."
        check_font_name
        echo "Font: $FONT" >&2
        SIZE=$(ask_size "${cur#*$'\t'}")
        ;;
    *)
        # Scripted: APP|all FONT SIZE.
        [ "$#" -eq 3 ] || die "Usage: ./set-font.sh APP|all FONT SIZE  (apps: ${APPS[*]}), or no arguments for the menus"
        case "$1" in
            all) apps=("${APPS[@]}") ;;
            kitty|alacritty|ghostty|sublime) apps=("$1") ;;
            *) die "Unknown app: $1 (apps: ${APPS[*]}, or all)" ;;
        esac
        FONT=$2
        SIZE=$3
        check_font_name
        [[ "$SIZE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "SIZE must be a number, got '$SIZE'."
        # (No grep -q: with pipefail, its early exit would fail the pipeline.)
        if command -v fc-list >/dev/null 2>&1 && ! list_fonts | grep -Fx -- "$FONT" >/dev/null; then
            echo "warning: no installed font family is named '$FONT'; setting it anyway" >&2
        fi
        ;;
esac

apply
