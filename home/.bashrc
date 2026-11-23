# Entry point for bash on Linux. Symlinked to ~/.bashrc by link.sh.
# Don't let installers append here; put machine-specific lines in ~/.bashrc.machine.

# If not running interactively, don't do anything.
case $- in
  *i*) ;;
  *) return ;;
esac

# History: ignore space-prefixed commands, drop older duplicates, keep
# timestamps, append across sessions.
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T '
HISTSIZE=100000
HISTFILESIZE=200000
shopt -s histappend

# Update LINES/COLUMNS after each command if the window was resized.
shopt -s checkwinsize

# Programmable completion (git, docker, ...).
[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

# Env, aliases and functions shared with zsh.
[ -f ~/.shellrc.sh ] && . ~/.shellrc.sh

# Make Ctrl-W delete a single path component, not the whole path.
stty werase undef 2>/dev/null
bind '"\C-w": unix-filename-rubout'

# zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

# fzf key-bindings and completion.
command -v fzf >/dev/null 2>&1 && source <(fzf --bash)

# liquidprompt, cloned to ~/sh/liquidprompt by setup/common.sh.
[ -f ~/sh/liquidprompt/liquidprompt ] && . ~/sh/liquidprompt/liquidprompt

# Per-machine overrides (untracked); last so they win.
[ -f ~/.bashrc.machine ] && . ~/.bashrc.machine
