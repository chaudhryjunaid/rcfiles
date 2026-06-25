#!/bin/bash

# Configuration setup script
# Links dotfiles from this directory to the home directory based on platform.

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Pick the platform-specific directory.
case "$(uname -s)" in
    Linux)  PLATFORM_DIR="linux" ;;
    Darwin) PLATFORM_DIR="macos" ;;
    *)      echo "Unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac

echo "Installing dotfiles for $PLATFORM_DIR"

# Create vim directories.
mkdir -p "$HOME/.vim/backups" "$HOME/.vim/swaps" "$HOME/.vim/undo"

# Link _common/* and <platform>/* to ~/.<filename>
for dir in "$SCRIPT_DIR/_common" "$SCRIPT_DIR/$PLATFORM_DIR"; do
    for file in "$dir"/*; do
        [ -f "$file" ] || continue
        target="$HOME/.$(basename "$file")"
        # Back up an existing real file (not one of our own symlinks) before replacing it.
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            backup="$target.bak.$(date +%s)"
            mv "$target" "$backup"
            echo "Backed up $target -> $backup"
        fi
        ln -sf "$file" "$target"
    done
done

# Ensure ~/.zshrc sources ~/.zshrc.local (idempotent).
# The symlinked ~/.zshrc.local does nothing unless ~/.zshrc sources it.
SOURCE_LINE='[ -f ~/.zshrc.local ] && source ~/.zshrc.local'
if ! grep -qF 'zshrc.local' "$HOME/.zshrc" 2>/dev/null; then
    printf '\n%s\n' "$SOURCE_LINE" >> "$HOME/.zshrc"
    echo "Added zshrc.local source line to ~/.zshrc"
fi

# Create the untracked per-machine git identity file (included by ~/.gitconfig).
# Edit this file with your name/email; it is never committed to this repo.
GITLOCAL="$HOME/.gitconfig.local"
if [ ! -f "$GITLOCAL" ]; then
    cat > "$GITLOCAL" <<'EOF'
[user]
	name = Your Name
	email = your.email@example.com
EOF
    echo "Created $GITLOCAL — set your name/email there."
fi

echo "Done."
