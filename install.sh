#!/bin/bash

# Configuration setup script
# Links dotfiles from this directory to home directory

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Create vim directories
mkdir -p "$HOME/.vim/backups"
mkdir -p "$HOME/.vim/swaps"
mkdir -p "$HOME/.vim/undo"

# Link configuration files
ln -sf "$SCRIPT_DIR/vimrc" "$HOME/.vimrc"
ln -sf "$SCRIPT_DIR/gitignore_global" "$HOME/.gitignore_global"
ln -sf "$SCRIPT_DIR/gitconfig" "$HOME/.gitconfig"
ln -sf "$SCRIPT_DIR/editorconfig" "$HOME/.editorconfig"
ln -sf "$SCRIPT_DIR/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$SCRIPT_DIR/zshrc.local" "$HOME/.zshrc.local"
ln -sf "$SCRIPT_DIR/zprofile" "$HOME/.zprofile"
