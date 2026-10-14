#!/bin/bash
# shellcheck disable=SC2329 # the edit_* functions are called as "edit_$app"
# set-font.sh — set the font family and size in the app configs under home/.
#
# Prints the change as a diff and writes nothing unless --apply is given.
# Apps: kitty, alacritty, sublime (Sublime Text); --all does every one. The
# configs are symlinked into $HOME, so --apply changes the live config too.
#
# FONT is an alias (see --help), an installed family name, or words from one
# ("caskaydia mono"); if several installed fonts match, it asks which.
#
# Usage: ./set-font.sh [--apply] (APP... | --all) FONT SIZE
#   e.g. ./set-font.sh kitty jetbrains 14
#        ./set-font.sh --all --apply "caskaydia mono" 13.5

set -euo pipefail

REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
APPS=(kitty alacritty sublime)

# Short names for common Nerd Fonts (setup/install-fonts.sh installs them; the
# setup scripts don't). The -mono ones are the Nerd Font Mono variants, whose
# icons are squeezed to one cell wide.
# Nerd Fonts renames Cascadia Code to CaskaydiaCove, hence both spellings.
FONT_ALIASES=(
    "jetbrains=JetBrainsMono Nerd Font"
    "jetbrains-mono=JetBrainsMono Nerd Font Mono"
    "caskaydia=CaskaydiaCove Nerd Font"
    "caskaydia-mono=CaskaydiaCove Nerd Font Mono"
    "cascadia=CaskaydiaCove Nerd Font"
    "cascadia-mono=CaskaydiaCove Nerd Font Mono"
    "meslo=MesloLGS Nerd Font"
    "meslo-mono=MesloLGS Nerd Font Mono"
)

print_help() {
    local entry
    sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
    echo
    echo "Font aliases:"
    for entry in "${FONT_ALIASES[@]}"; do
        printf '  %-15s %s\n' "${entry%%=*}" "${entry#*=}"
    done
}

usage_error() {
    echo "$*" >&2
    echo "Usage: ./set-font.sh [--apply] (APP... | --all) FONT SIZE  (apps: ${APPS[*]})" >&2
    exit 2
}

config_for() {
    case "$1" in
        kitty)     echo "home/.config/kitty/kitty.conf" ;;
        alacritty) echo "home/.config/alacritty/alacritty.toml" ;;
        sublime)   echo "home/.config/sublime-text/Packages/User/Preferences.sublime-settings" ;;
    esac
}

# resolve_font <query>: print the font family <query> stands for: an alias,
# a name fontconfig knows (as is), or else the installed family whose name has
# every word of <query> in it, case-insensitively. Asks if several do.
resolve_font() {
    local query=$1 entry name word
    local -a words matches=()

    for entry in "${FONT_ALIASES[@]}"; do
        if [ "${entry%%=*}" = "${query,,}" ]; then echo "${entry#*=}"; return; fi
    done

    if ! command -v fc-list >/dev/null 2>&1; then echo "$query"; return; fi
    # Every name counts here, including short ones like "JetBrainsMono NF".
    # (No grep -q: with pipefail, its early exit would fail the pipeline.)
    if fc-list : family | tr ',' '\n' | grep -Fx -- "$query" >/dev/null; then
        echo "$query"; return
    fi

    # Only each font's main family (the first name on its line) is offered;
    # the rest are short names and per-weight families of the same font.
    read -ra words <<< "${query,,}"
    while IFS= read -r name; do
        if [ "${name,,}" = "${query,,}" ]; then echo "$name"; return; fi
        for word in "${words[@]}"; do
            [[ "${name,,}" == *"$word"* ]] || continue 2
        done
        matches+=("$name")
    done < <(fc-list : family | cut -d, -f1 | sort -u)

    case "${#matches[@]}" in
        0)  echo "warning: no installed font matches '$query'; using it as given" >&2
            echo "$query" ;;
        1)  echo "${matches[0]}" ;;
        *)  if ! [ -t 0 ] || ! [ -t 2 ]; then
                echo "'$query' matches ${#matches[@]} installed fonts; give more of the name:" >&2
                printf '  %s\n' "${matches[@]}" >&2
                return 2
            fi
            # select draws its menu on stderr, so only the pick reaches stdout.
            echo "'$query' matches ${#matches[@]} installed fonts:" >&2
            local PS3="Which one (1-${#matches[@]})? "
            select name in "${matches[@]}"; do
                if [ -n "$name" ]; then echo "$name"; return; fi
            done
            echo >&2
            return 1 ;;  # ctrl-d at the prompt
    esac
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

APPLY=0
ALL=0
args=()
for arg in "$@"; do
    case "$arg" in
        --apply)   APPLY=1 ;;
        --all)     ALL=1 ;;
        -h|--help) print_help; exit 0 ;;
        -*)        usage_error "Unknown option: $arg" ;;
        *)         args+=("$arg") ;;
    esac
done

[ "${#args[@]}" -ge 2 ] || usage_error "Missing FONT and SIZE."
n=$(( ${#args[@]} - 2 ))
FONT=${args[n]}
SIZE=${args[n + 1]}
apps=("${args[@]:0:n}")

if [ "$ALL" -eq 1 ]; then
    [ "${#apps[@]}" -eq 0 ] || usage_error "Give app names or --all, not both."
    apps=("${APPS[@]}")
fi
[ "${#apps[@]}" -gt 0 ] || usage_error "Name at least one app, or use --all."
for i in "${!apps[@]}"; do
    case "${apps[i]}" in
        kitty|alacritty|sublime) ;;
        sublime-text) apps[i]=sublime ;;
        *) usage_error "Unknown app: ${apps[i]}" ;;
    esac
done

[[ "$SIZE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || usage_error "SIZE must be a number, got '$SIZE'."
case "$FONT" in
    *[\"\\]*)         usage_error "FONT can't contain quotes or backslashes." ;;
    *[![:space:]]*)   ;;
    *)                usage_error "FONT is empty." ;;
esac

# A typo'd name isn't an error to the apps (they silently fall back), so
# resolve_font warns when nothing installed matches.
query=$FONT
FONT=$(resolve_font "$query") || exit
[ "$FONT" = "$query" ] || echo "font: $query -> $FONT" >&2

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

status=0 changed=0
for app in "${apps[@]}"; do
    file=$(config_for "$app")
    if ! "edit_$app" "$REPO/$file" > "$tmp"; then
        echo "$app: font settings not found in $file; left alone" >&2
        status=1
        continue
    fi
    if cmp -s "$REPO/$file" "$tmp"; then
        echo "$app: already set ($file)"
        continue
    fi
    diff -u --color=auto --label "a/$file" --label "b/$file" "$REPO/$file" "$tmp" || true
    if [ "$APPLY" -eq 1 ]; then
        # Overwrite in place (not mv) so the file keeps its mode.
        cat "$tmp" > "$REPO/$file"
        echo "$app: updated $file"
    fi
    changed=$((changed + 1))
done

if [ "$APPLY" -eq 0 ] && [ "$changed" -gt 0 ]; then
    echo "(dry run: nothing was changed; re-run with --apply to write)"
fi
exit "$status"
