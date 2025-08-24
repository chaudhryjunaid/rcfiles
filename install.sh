#!/bin/bash

# Configuration setup script
# Links dotfiles from this directory to home directory

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Create vim directories
mkdir ~/data ~/personal_data ~/projects ~/backups ~/tmp
mkdir -p ~/.vim/backups
mkdir -p ~/.vim/swaps
mkdir -p ~/.vim/undo

# Link configuration files
ln -sf $SCRIPT_DIR/vimrc ~/.vimrc
ln -sf $SCRIPT_DIR/gitignore_global ~/.gitignore_global
ln -sf $SCRIPT_DIR/gitconfig ~/.gitconfig
ln -sf $SCRIPT_DIR/editorconfig ~/.editorconfig
ln -sf $SCRIPT_DIR/tmux.conf ~/.tmux.conf
ln -sf $SCRIPT_DIR/zshrc.local ~/.zshrc.local
