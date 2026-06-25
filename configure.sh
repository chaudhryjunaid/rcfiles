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

# Symlink $1 -> $2, backing up an existing real file (not one of our own symlinks).
link_file() {
    local src="$1" target="$2"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup="$target.bak.$(date +%s)"
        mv "$target" "$backup"
        echo "Backed up $target -> $backup"
    fi
    ln -sf "$src" "$target"
}

# Link _common/* and <platform>/* to ~/.<filename>
for dir in "$SCRIPT_DIR/_common" "$SCRIPT_DIR/$PLATFORM_DIR"; do
    for file in "$dir"/*; do
        [ -f "$file" ] || continue
        case "$(basename "$file")" in
            kitty.conf) continue ;;  # linked into ~/.config/kitty below
        esac
        link_file "$file" "$HOME/.$(basename "$file")"
    done
done

# Link kitty config into its XDG location (~/.config/kitty/kitty.conf).
if [ -f "$SCRIPT_DIR/_common/kitty.conf" ]; then
    mkdir -p "$HOME/.config/kitty"
    link_file "$SCRIPT_DIR/_common/kitty.conf" "$HOME/.config/kitty/kitty.conf"
fi

# The platform `zshrc` is linked straight to ~/.zshrc by the loop above (it is
# the entry point and sources ~/.zshrc.common itself). Any prior real ~/.zshrc
# (e.g. an oh-my-zsh one) is backed up by link_file. Remove a stale
# ~/.zshrc.local symlink left over from the old two-file layout.
[ -L "$HOME/.zshrc.local" ] && rm -f "$HOME/.zshrc.local"

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
