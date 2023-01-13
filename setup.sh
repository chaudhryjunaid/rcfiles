#!/bin/sh

mkdir -p ~/.config/nvim

ln -sf $PWD/nvim/init.vim ~/.config/nvim/init.vim

ln -sf $PWD/gitconfig ~/.gitconfig
cp gitconfig-work ~/.gitconfig-work
ln -sf $PWD/gitconfig-projects ~/.gitconfig-projects
ln -sf $PWD/gitexcludes ~/.gitexcludes

ln -sf $PWD/zshrc.custom ~/.zshrc.custom

