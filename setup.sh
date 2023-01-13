#!/bin/sh

mkdir -p ~/.config/nvim

CURR_DIR = $PWD

ln -s $CURR_DIR/nvim/init.vim ~/.config/nvim/init.vim

ln -s $CURR_DIR/gitconfig ~/.gitconfig
cp gitconfig-work ~/.gitconfig-work
ln -s $CURR_DIR/gitconfig-projects ~/.gitconfig-projects
ln -s $CURR_DIR/gitexcludes ~/.gitexcludes

ln -s $CURR_DIR/zshrc.custom ~/.zshrc.custom

