#!/bin/bash

# install.sh — set up a machine end to end:
#   1. install dependencies  (setup/ubuntu.sh)
#   2. symlink the dotfiles  (link.sh)
#   3. set the git identity  (setup/git-identity.sh), unless already set
# Every step is safe to re-run.
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
        -h|--help)       sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)               echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

if [ "$(uname -s)" != Linux ] || ! command -v apt-get >/dev/null 2>&1; then
    echo "Only Ubuntu/Debian Linux is supported." >&2
    exit 1
fi
SETUP="$REPO/setup/ubuntu.sh"

if [ "$SKIP_DEPS" -eq 0 ]; then
    echo "### Installing dependencies ($(basename "$SETUP"))"
    "$SETUP"
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
