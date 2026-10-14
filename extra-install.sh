#!/bin/bash

# extra-install.sh — install the apps in cli-apps.manifest.csv and
# gui-apps.manifest.csv that this distro's own repos have: the packages in the
# manifests' ubuntu or fedora column, with apt or dnf. Apps with that column
# empty need a vendor repo, a .deb, a snap, Flathub or an installer, so they're
# only listed, to install by hand. Apps already installed as a snap or Flatpak
# are skipped. Optional: install.sh doesn't run it. Safe to re-run.
#
# Usage: ./extra-install.sh [--dry-run] [--cli-only]

set -euo pipefail

REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck source=setup/lib.sh
. "$REPO/setup/lib.sh"

DRY_RUN=0
MANIFESTS=("$REPO/cli-apps.manifest.csv" "$REPO/gui-apps.manifest.csv")
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        --cli-only)   MANIFESTS=("$REPO/cli-apps.manifest.csv") ;;
        -h|--help)    sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)            echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

DISTRO=$(detect_distro) || die "Only Ubuntu and Fedora are supported."
command -v python3 >/dev/null 2>&1 || die "python3 not found (it reads the manifests)."

case "$DISTRO" in
    ubuntu)
        is_installed() { [ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" = "ii " ]; }
        # --no-remove: fail rather than remove a package that conflicts, such
        # as one from a vendor repo.
        pkg_install() { $SUDO apt-get install -y --no-remove "$@"; } ;;
    fedora)
        is_installed() { rpm -q --quiet "$1"; }
        pkg_install() { $SUDO dnf install -y "$@"; } ;;
esac

# join <array...>: print the arguments separated by ", ".
join() {
    local out
    printf -v out '%s, ' "$@"
    echo "${out%, }"
}

# Snaps and Flatpaks installed here, by name (a Flatpak by the last part of
# its ID), so an app that's installed that way isn't installed twice.
declare -A elsewhere=()
while read -r name; do
    [ -n "$name" ] && elsewhere[$name]=1
done < <({ snap list 2>/dev/null | awk 'NR > 1 { print $1 }'
           flatpak list --app --columns=application 2>/dev/null |
               awk -F. '{ print tolower($NF) }'; } || true)

# Each manifest row as "name<TAB>packages for this distro".
rows=$(python3 -I - "$DISTRO" "${MANIFESTS[@]}" <<'EOF'
import csv, sys
distro, *paths = sys.argv[1:]
for path in paths:
    with open(path, newline='', encoding='utf-8') as f:
        for row in csv.DictReader(f):
            print(row['name'], ' '.join(row[distro].split()), sep='\t')
EOF
)

todo_apps=() todo_pkgs=() by_hand=() as_other=()
present=0
while IFS=$'\t' read -r name pkgs; do
    [ -n "$name" ] || continue
    if [ -z "$pkgs" ]; then by_hand+=("$name"); continue; fi
    read -ra pkg_list <<< "$pkgs"
    key=${name,,}
    for n in "${key// /}" "${pkg_list[@]}"; do
        if [ -n "${elsewhere[$n]:-}" ]; then as_other+=("$name"); continue 2; fi
    done
    missing=()
    for p in "${pkg_list[@]}"; do
        is_installed "$p" || missing+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ]; then present=$((present + 1)); continue; fi
    todo_apps+=("$name")
    todo_pkgs+=("${missing[*]}")
done <<< "$rows"

log "Apps from the manifests ($DISTRO)"
info "already installed: $present"
if [ "${#as_other[@]}" -gt 0 ]; then
    info "installed as a snap or Flatpak, so skipped: $(join "${as_other[@]}")"
fi
if [ "${#by_hand[@]}" -gt 0 ]; then
    info "not in the $DISTRO repos, to install by hand: $(join "${by_hand[@]}")"
fi
info "to install: ${#todo_apps[@]}"
for i in "${!todo_apps[@]}"; do
    info "    ${todo_apps[i]} (${todo_pkgs[i]})"
done

if [ "${#todo_apps[@]}" -eq 0 ]; then
    log "Nothing to install."
    exit 0
fi
if [ "$DRY_RUN" -eq 1 ]; then
    echo "(dry run: nothing was installed)"
    exit 0
fi

if [ "$DISTRO" = ubuntu ]; then
    log "Updating apt package lists"
    $SUDO apt-get update -y
fi

all=()
for pkgs in "${todo_pkgs[@]}"; do
    read -ra pkg_list <<< "$pkgs"
    all+=("${pkg_list[@]}")
done
log "Installing ${#all[@]} package$([ "${#all[@]}" -eq 1 ] || echo s)"
if pkg_install "${all[@]}"; then
    exit 0
fi

# One package that's missing or conflicts fails the whole batch, so retry app
# by app to install the rest.
failed=()
if [ "${#todo_apps[@]}" -eq 1 ]; then
    failed=("${todo_apps[0]}")
else
    warn "installing them together failed; trying one app at a time"
    for i in "${!todo_apps[@]}"; do
        read -ra pkg_list <<< "${todo_pkgs[i]}"
        log "Installing ${todo_apps[i]}"
        pkg_install "${pkg_list[@]}" || failed+=("${todo_apps[i]}")
    done
fi
if [ "${#failed[@]}" -gt 0 ]; then
    warn "couldn't install: $(join "${failed[@]}")"
    exit 1
fi
