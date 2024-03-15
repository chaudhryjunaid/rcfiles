#!/bin/sh

# please use the ansible playbook at https://github.com/chaudhryjunaid/setup-macos to configure
# this script is only for special use

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# link tmux config
ln -sf $SCRIPT_DIR/tmux.conf ~/.tmux.conf

# link vim config
ln -sf $SCRIPT_DIR/vimrc ~/.vimrc

# link git configs
ln -sf $SCRIPT_DIR/gitexcludes ~/.gitexcludes
ln -sf $SCRIPT_DIR/gitconfig-default ~/.gitconfig-default
if [ -f ~/.gitconfig-work ];
then
  echo ".gitconfig-work already present, omitting update.";
else
  cp gitconfig-work ~/.gitconfig-work;
fi
ln -sf $SCRIPT_DIR/gitconfig ~/.gitconfig

# link zsh config
ln -sf $SCRIPT_DIR/zshrc.custom ~/.zshrc.custom

ln -sf $SCRIPT_DIR/liquidpromptrc ~/.liquidpromptrc

