#!/bin/bash

# install.sh — set up a machine end to end:
#   1. install dependencies  (setup/<distro>.sh, then setup/common.sh)
#   2. symlink the dotfiles  (link.sh)
#   3. set the git identity  (setup/git-identity.sh), unless already set
# Every step is safe to re-run. Step 1 supports Ubuntu and Fedora (and their
# derivatives); with --skip-deps the rest works on any system.
#
# Usage: ./install.sh [--skip-deps] [--skip-identity]

set -euo pipefail

REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SKIP_DEPS=0
SKIP_IDENTITY=0
for arg in "$@"; do
    case "$arg" in
        --skip-deps)     SKIP_DEPS=1 ;;
        --skip-identity) SKIP_IDENTITY=1 ;;
        -h|--help)       sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)               echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

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

if [ "$SKIP_DEPS" -eq 0 ]; then
    if ! DISTRO=$(detect_distro); then
        echo "Only Ubuntu and Fedora are supported. Install the dependencies" >&2
        echo "listed in the README by hand, then rerun with --skip-deps." >&2
        exit 1
    fi
    echo "### Installing $DISTRO packages (setup/$DISTRO.sh)"
    "$REPO/setup/$DISTRO.sh"
    echo "### Installing common dependencies (setup/common.sh)"
    "$REPO/setup/common.sh"
fi

echo "### Linking dotfiles"
"$REPO/link.sh"

# Only prompt for an identity while ~/.gitconfig.local still has the placeholder.
if [ "$SKIP_IDENTITY" -eq 0 ] \
    && [ "$(git config -f "$HOME/.gitconfig.local" user.name 2>/dev/null || true)" = "Your Name" ]; then
    echo "### Setting git identity"
    "$REPO/setup/git-identity.sh"
fi

cat <<'NOTE'

All done. Restart your terminal (or log out/in) to pick up zsh and new fonts,
and set the terminal font to a Nerd Font such as "JetBrainsMono Nerd Font".
On WSL, install the Nerd Font on Windows and select it in Windows Terminal.
Machine-specific shell lines go in ~/.zshrc.machine / ~/.bashrc.machine.
NOTE
