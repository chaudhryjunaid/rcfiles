#!/bin/bash

# manifest-update.sh — regenerate gui-apps.manifest.csv and
# cli-apps.manifest.csv from what's installed on this machine, to commit.
# Rows already there are kept as they are (your categories, homepages and
# descriptions); apps installed here that no row covers get a new row, filled
# in from the package, snap, Flatpak or extension metadata and placed in its
# category (Uncategorized when there's no good guess). Rows for apps not found
# here are kept unless --prune is given. It prints what changed and which new
# rows still need a hand-written homepage, description or category; review
# with git diff before committing. ./manifest-diff.sh shows the same without
# writing. What counts as installed: see setup/manifests.py.
#
# Usage: ./manifest-update.sh [--prune] [--dry-run]

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=setup/lib.sh
. "$REPO/setup/lib.sh"

OPTS=()
for arg in "$@"; do
    case "$arg" in
        --prune) OPTS+=(--prune) ;;
        -n | --dry-run) OPTS+=(--dry-run) ;;
        -h | --help)
            sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

DISTRO=$(detect_distro) || die "Only Ubuntu and Fedora are supported."
command -v python3 >/dev/null 2>&1 || die "python3 not found."

exec python3 -I "$REPO/setup/manifests.py" update "$DISTRO" "$REPO" "${OPTS[@]}"
