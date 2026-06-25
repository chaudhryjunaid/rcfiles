# rcfiles
Set of good enough system configuration/rc files for macOS/Linux.

# after setup
Set your git identity in `~/.gitconfig.local` (created by `install.sh`, untracked,
included by the tracked `~/.gitconfig`):
```
git config -f ~/.gitconfig.local user.name "Your Name"
git config -f ~/.gitconfig.local user.email "your.email@example.com"
```

# Notes
- uses oh-my-zsh, fzf, fnm, zsh-syntax-highlighting, zsh-autosuggestions and
  liquidprompt
- zsh customizations as provided as zshrc.local intended to be sourced at the end of the .zshrc file

