#!/bin/sh

mkdir -p ~/.config/nvim

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# link nvim config
ln -sf $SCRIPT_DIR/nvim/init.vim ~/.config/nvim/init.vim

# link git configs
ln -sf $SCRIPT_DIR/gitexcludes ~/.gitexcludes
ln -sf $SCRIPT_DIR/gitconfig-projects ~/.gitconfig-projects
if [ -f ~/.gitconfig-work ];
then
  echo ".gitconfig-work already present, omitting update.";
else
  cp gitconfig-work ~/.gitconfig-work;
fi
ln -sf $SCRIPT_DIR/gitconfig ~/.gitconfig

# link zsh config
ln -sf $SCRIPT_DIR/zshrc.custom ~/.zshrc.custom
