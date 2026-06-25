#!/bin/bash

# Set up the git identity in ~/.gitconfig.local (untracked, included by the
# tracked ~/.gitconfig). Run this once on a new system, after install.sh, so
# you don't have to type your name/email by hand.
#
# Usage:
#   ./setup-git-identity.sh                       # use the defaults below
#   ./setup-git-identity.sh "Name" "email@x.com"  # override

set -euo pipefail

NAME="${1:-Chaudhry Junaid Anwar}"
EMAIL="${2:-junaidanwar10@gmail.com}"

GITLOCAL="$HOME/.gitconfig.local"

echo "Set git identity to:"
echo "  user.name  = $NAME"
echo "  user.email = $EMAIL"
printf "Write to %s? [y/N] " "$GITLOCAL"
read -r reply || reply=""
case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted; nothing written."; exit 0 ;;
esac

git config -f "$GITLOCAL" user.name "$NAME"
git config -f "$GITLOCAL" user.email "$EMAIL"

echo "Wrote git identity to $GITLOCAL:"
echo "  user.name  = $(git config -f "$GITLOCAL" user.name)"
echo "  user.email = $(git config -f "$GITLOCAL" user.email)"
