# Entry point for bash on Linux. Symlinked to ~/.bashrc by link.sh.
# Don't let installers append here; put machine-specific lines in ~/.bashrc.machine.

# If not running interactively, don't do anything.
case $- in
  *i*) ;;
  *) return ;;
esac

# History: ignore duplicates and space-prefixed commands, append across sessions.
HISTCONTROL=ignoreboth
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

if [ -n "$KITTY_INSTALLATION_DIR" ]; then
  export KITTY_SHELL_INTEGRATION="enabled"
  source "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"
fi

[ -f /usr/share/liquidprompt/liquidprompt ] && . /usr/share/liquidprompt/liquidprompt

# Per-machine overrides (untracked); last so they win.
[ -f ~/.bashrc.machine ] && . ~/.bashrc.machine
