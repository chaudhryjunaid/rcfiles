#!/bin/bash

# Configuration setup script
# Links dotfiles from this directory to the home directory based on platform.

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
        ln -sf "$file" "$HOME/.$(basename "$file")"
    done
done

echo "Done."
