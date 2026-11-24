#!/bin/bash

# Set up the git identity and commit signing in ~/.gitconfig (untracked; the
# tracked config is ~/.config/git/config). install.sh runs this after
# linking; run it by hand to change your identity or signing key later.
#
# Signing uses an SSH key (gpg.format = ssh in the tracked config): this
# sets user.signingKey to the key's .pub file, turns on commit.gpgSign and
# tag.gpgSign, and adds the key to ~/.config/git/allowed_signers so
# `git log --show-signature` can verify your own commits. The key is
# $SIGNING_KEY, else ~/.ssh/id_ed25519.pub, else the first ~/.ssh/id_*.pub;
# with none, signing is skipped (create one with ssh-keygen -t ed25519).
# For GitHub to show commits as Verified, add the key there as a signing
# key: gh ssh-key add <key>.pub --type signing.
#
# Usage:
#   setup/git-identity.sh                         # use the defaults below
#   setup/git-identity.sh "Name" "email@x.com"    # override

set -euo pipefail

NAME="${1:-Chaudhry Junaid Anwar}"
EMAIL="${2:-junaidanwar10@gmail.com}"

GITLOCAL="$HOME/.gitconfig"
SIGNERS="${XDG_CONFIG_HOME:-$HOME/.config}/git/allowed_signers"

KEY="${SIGNING_KEY:-}"
if [ -z "$KEY" ]; then
    for k in "$HOME/.ssh/id_ed25519.pub" "$HOME"/.ssh/id_*.pub; do
        if [ -f "$k" ]; then
            KEY=$k
            break
        fi
    done
fi
[ -z "$KEY" ] || [ -f "$KEY" ] || {
    echo "Signing key $KEY not found." >&2
    exit 1
}

echo "Set git identity to:"
echo "  user.name  = $NAME"
echo "  user.email = $EMAIL"
if [ -n "$KEY" ]; then
    echo "and sign commits and tags with:"
    echo "  user.signingKey = $KEY"
else
    echo "(no SSH key in ~/.ssh, so commits won't be signed; ssh-keygen -t ed25519, then rerun)"
fi
printf "Write to %s? [y/N] " "$GITLOCAL"
read -r reply || reply=""
case "$reply" in
    [yY] | [yY][eE][sS]) ;;
    *)
        echo "Aborted; nothing written. git won't commit until an identity is set (rerun this script)."
        exit 0
        ;;
esac

git config -f "$GITLOCAL" user.name "$NAME"
git config -f "$GITLOCAL" user.email "$EMAIL"
if [ -n "$KEY" ]; then
    git config -f "$GITLOCAL" user.signingKey "$KEY"
    git config -f "$GITLOCAL" commit.gpgSign true
    git config -f "$GITLOCAL" tag.gpgSign true
    # "<email> namespaces="git" <key>", once per email and key.
    line="$EMAIL namespaces=\"git\" $(cut -d' ' -f1,2 "$KEY")"
    mkdir -p "$(dirname "$SIGNERS")"
    touch "$SIGNERS"
    grep -qxF -- "$line" "$SIGNERS" || echo "$line" >>"$SIGNERS"
fi

echo "Wrote to $GITLOCAL:"
echo "  user.name  = $(git config -f "$GITLOCAL" user.name)"
echo "  user.email = $(git config -f "$GITLOCAL" user.email)"
if [ -n "$KEY" ]; then
    echo "  user.signingKey = $(git config -f "$GITLOCAL" user.signingKey) (commits and tags signed)"
    echo "Added the key to $SIGNERS. For GitHub's Verified badge, add it as a signing key:"
    echo "  gh ssh-key add $KEY --type signing --title \"$(hostname) signing\""
fi
