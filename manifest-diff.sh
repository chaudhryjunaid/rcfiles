#!/bin/bash

# manifest-diff.sh — compare the app manifests (gui-apps.manifest.csv,
# cli-apps.manifest.csv) with what's installed on this machine. Read-only.
# Lists
#   - manifest apps that aren't found here (install them, or drop the row)
#   - GUI apps and CLI tools installed here that no row covers (add a row,
#     or let ./manifest-update.sh add them)
# "Installed here" means put there by a person rather than the OS installer:
# Flatpaks, snaps Ubuntu doesn't seed, AppImages, GNOME Shell extensions,
# distro packages installed by hand after the OS, cargo/go/npm/uv/pip --user
# tools, files in /usr/local/bin and ~/.local/bin. The details are in
# setup/manifests.py. Matching is by package, then name, so the odd row may
# need a look by hand.
#
# Usage: ./manifest-diff.sh

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=setup/lib.sh
. "$REPO/setup/lib.sh"

case "${1:-}" in
    "") ;;
    -h | --help)
        sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 2
        ;;
esac

DISTRO=$(detect_distro) || die "Only Ubuntu and Fedora are supported."
command -v python3 >/dev/null 2>&1 || die "python3 not found."

exec python3 -I "$REPO/setup/manifests.py" diff "$DISTRO" "$REPO"
