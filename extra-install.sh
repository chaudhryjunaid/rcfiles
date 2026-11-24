#!/bin/bash

# extra-install.sh — install the apps in cli-apps.manifest.csv and
# gui-apps.manifest.csv that can be installed unattended: the packages in the
# manifests' ubuntu or fedora column (this distro's own repos) with apt or
# dnf, and the rows whose install column is "snap: <name> [--classic]" or
# "flatpak: <app id>" (from Flathub, added if missing) when snap or flatpak
# is there (flatpak also when this run installs it: packages go first). The rest (a vendor repo, a .deb, a GNOME extension, an
# installer) are listed with their install column, to do by hand. Apps
# already installed as a snap or Flatpak are skipped. Optional: install.sh
# doesn't run it. Safe to re-run.
#
# Usage: ./extra-install.sh [--dry-run] [--cli-only]

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=setup/lib.sh
. "$REPO/setup/lib.sh"

DRY_RUN=0
MANIFESTS=("$REPO/cli-apps.manifest.csv" "$REPO/gui-apps.manifest.csv")
for arg in "$@"; do
    case "$arg" in
        -n | --dry-run) DRY_RUN=1 ;;
        --cli-only) MANIFESTS=("$REPO/cli-apps.manifest.csv") ;;
        -h | --help)
            sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

DISTRO=$(detect_distro) || die "Only Ubuntu and Fedora are supported."
command -v python3 >/dev/null 2>&1 || die "python3 not found (it reads the manifests)."

case "$DISTRO" in
    ubuntu)
        is_installed() { [ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" = "ii " ]; }
        # --no-remove: fail rather than remove a package that conflicts, such
        # as one from a vendor repo.
        pkg_install() { $SUDO apt-get install -y --no-remove "$@"; }
        ;;
    fedora)
        is_installed() { rpm -q --quiet "$1"; }
        pkg_install() { $SUDO dnf install -y "$@"; }
        ;;
esac
has() { command -v "$1" >/dev/null 2>&1; }

# join <array...>: print the arguments separated by ", ".
join() {
    local out
    printf -v out '%s, ' "$@"
    echo "${out%, }"
}

# Snaps and Flatpaks installed here, by name (a Flatpak by its ID and by the
# last part of it), so an app that's installed that way isn't installed twice.
declare -A elsewhere=()
while read -r name; do
    [ -n "$name" ] && elsewhere[$name]=1
done < <({
    snap list 2>/dev/null | awk 'NR > 1 { print $1 }'
    flatpak list --app --columns=application 2>/dev/null |
        awk -F. '{ print; print tolower($NF) }'
} || true)

# Each manifest row as "name, packages for this distro, install", separated
# by \x1f (not a tab: read would merge a tab around an empty field).
rows=$(
    python3 -I - "$DISTRO" "${MANIFESTS[@]}" <<'EOF'
import csv, sys
distro, *paths = sys.argv[1:]
for path in paths:
    with open(path, newline='', encoding='utf-8') as f:
        for row in csv.DictReader(f):
            print(row['name'], ' '.join(row[distro].split()),
                  ' '.join(row.get('install', '').split()), sep='\x1f')
EOF
)

# Apps to install: distro packages (todo_apps/todo_pkgs), snaps ("name|args")
# and Flatpaks ("name|app id").
todo_apps=() todo_pkgs=() snaps=() flatpaks=() by_hand=() as_other=()
# Flatpak rows while flatpak isn't installed: installed after it if one of
# the packages below is flatpak, else listed to do by hand.
no_flatpak=()
present=0
while IFS=$'\x1f' read -r name pkgs install; do
    [ -n "$name" ] || continue
    if [ -z "$pkgs" ]; then
        what=${install#*: }
        case "$install" in
            snap:*)
                if has snap; then
                    if [ -n "${elsewhere[${what%% *}]:-}" ]; then
                        present=$((present + 1))
                    else
                        snaps+=("$name|$what")
                    fi
                    continue
                fi
                ;;
            flatpak:*)
                if ! has flatpak; then
                    no_flatpak+=("$name|$what")
                elif [ -n "${elsewhere[$what]:-}" ]; then
                    present=$((present + 1))
                else
                    flatpaks+=("$name|$what")
                fi
                continue
                ;;
        esac
        by_hand+=("$name${install:+ ($install)}")
        continue
    fi
    read -ra pkg_list <<<"$pkgs"
    key=${name,,}
    for n in "${key// /}" "${pkg_list[@]}"; do
        if [ -n "${elsewhere[$n]:-}" ]; then
            as_other+=("$name")
            continue 2
        fi
    done
    missing=()
    for p in "${pkg_list[@]}"; do
        is_installed "$p" || missing+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        present=$((present + 1))
        continue
    fi
    todo_apps+=("$name")
    todo_pkgs+=("${missing[*]}")
done <<<"$rows"

if [ "${#no_flatpak[@]}" -gt 0 ]; then
    if [[ " ${todo_pkgs[*]} " == *" flatpak "* ]]; then
        flatpaks+=("${no_flatpak[@]}")
    else
        for app in "${no_flatpak[@]}"; do by_hand+=("${app%%|*} (flatpak: ${app#*|})"); done
    fi
fi

total=$((${#todo_apps[@]} + ${#snaps[@]} + ${#flatpaks[@]}))
log "Apps from the manifests ($DISTRO)"
info "already installed: $present"
if [ "${#as_other[@]}" -gt 0 ]; then
    info "installed as a snap or Flatpak, so skipped: $(join "${as_other[@]}")"
fi
if [ "${#by_hand[@]}" -gt 0 ]; then
    info "to install by hand: ${#by_hand[@]}"
    for app in "${by_hand[@]}"; do info "    $app"; done
fi
info "to install: $total"
for i in "${!todo_apps[@]}"; do
    info "    ${todo_apps[i]} ($DISTRO: ${todo_pkgs[i]})"
done
for app in "${snaps[@]}"; do info "    ${app%%|*} (snap: ${app#*|})"; done
for app in "${flatpaks[@]}"; do info "    ${app%%|*} (flatpak: ${app#*|})"; done

if [ "$total" -eq 0 ]; then
    log "Nothing to install."
    exit 0
fi
if [ "$DRY_RUN" -eq 1 ]; then
    echo "(dry run: nothing was installed)"
    exit 0
fi

# Distro packages first: flatpak may be one of them.
failed=()
if [ "${#todo_apps[@]}" -gt 0 ]; then
    if [ "$DISTRO" = ubuntu ]; then
        log "Updating apt package lists"
        $SUDO apt-get update -y
    fi
    all=()
    for pkgs in "${todo_pkgs[@]}"; do
        read -ra pkg_list <<<"$pkgs"
        all+=("${pkg_list[@]}")
    done
    log "Installing ${#all[@]} package$([ "${#all[@]}" -eq 1 ] || echo s)"
    if ! pkg_install "${all[@]}"; then
        # One package that's missing or conflicts fails the whole batch, so
        # retry app by app to install the rest.
        if [ "${#todo_apps[@]}" -eq 1 ]; then
            failed+=("${todo_apps[0]}")
        else
            warn "installing them together failed; trying one app at a time"
            for i in "${!todo_apps[@]}"; do
                read -ra pkg_list <<<"${todo_pkgs[i]}"
                log "Installing ${todo_apps[i]}"
                pkg_install "${pkg_list[@]}" || failed+=("${todo_apps[i]}")
            done
        fi
    fi
fi

for app in "${snaps[@]}"; do
    log "Installing ${app%%|*} (snap)"
    read -ra args <<<"${app#*|}"
    $SUDO snap install "${args[@]}" || failed+=("${app%%|*}")
done
if [ "${#flatpaks[@]}" -gt 0 ]; then
    log "Installing ${#flatpaks[@]} Flatpak(s) from Flathub"
    if ! has flatpak; then
        warn "flatpak isn't installed"
        for app in "${flatpaks[@]}"; do failed+=("${app%%|*}"); done
    elif ! $SUDO flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        warn "couldn't add the Flathub remote"
        for app in "${flatpaks[@]}"; do failed+=("${app%%|*}"); done
    else
        for app in "${flatpaks[@]}"; do
            $SUDO flatpak install -y --noninteractive flathub "${app#*|}" || failed+=("${app%%|*}")
        done
    fi
fi

if [ "${#failed[@]}" -gt 0 ]; then
    warn "couldn't install: $(join "${failed[@]}")"
    exit 1
fi
