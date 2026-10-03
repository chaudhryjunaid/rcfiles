# zsh config. Symlinked to ~/.zshrc by link.sh.
# Don't let installers append here; put machine-specific lines in ~/.zshrc.machine.

set -o emacs

# Keep PATH/FPATH free of duplicates (re-applied at the end of this file).
typeset -U path fpath

# Env, aliases and functions shared with bash.
[ -f ~/.shellrc.sh ] && source ~/.shellrc.sh

# Key sequence timeout (15 = 150ms).
KEYTIMEOUT=15

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

setopt share_history        # Share history across sessions (implies append + incremental)
setopt extended_history     # Save timestamps and durations
setopt hist_ignore_all_dups # Remove older duplicate entries
setopt hist_ignore_space    # Don't store commands starting with a space
setopt hist_expire_dups_first # Expire older duplicates first
setopt hist_find_no_dups    # Don't show duplicate history entries in search
setopt hist_save_no_dups    # Don't save duplicate entries
setopt hist_reduce_blanks   # Remove extra blanks from commands
setopt hist_verify          # Show command before executing from history

# Directory navigation
setopt auto_cd            # `foo/bar` alone cds into it
setopt auto_pushd         # every cd pushes onto the dir stack (cd -<Tab>)
setopt pushd_ignore_dups  # no duplicate stack entries
setopt pushd_silent       # don't print the stack on every cd

# Shell quality-of-life
setopt interactive_comments  # allow `# comments` when typing commands
setopt extended_glob         # ^, ~, # in globs (e.g. ls ^*.bak)
setopt numeric_glob_sort     # file9 before file10
unsetopt correct
unsetopt correct_all
# Make Ctrl-W delete a single path component, not the whole path
WORDCHARS=${WORDCHARS//[\/]}

# fzf key-bindings. Loaded before the plugins so fzf-tab, not fzf, owns Tab.
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

# Completion styles (read when completion runs, so fine to set before compinit).
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'  # case-insensitive, then partial-word
zstyle ':completion:*' menu no                       # fzf-tab does the selecting
zstyle ':completion:*:descriptions' format '[%d]'    # group headers (fzf-tab shows them)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*:git-checkout:*' sort false     # keep git's recency order
zstyle ':fzf-tab:*' switch-group '<' '>'             # cycle completion groups
# Preview directories when completing cd/z/ls.
if command -v eza >/dev/null 2>&1; then
  zstyle ':fzf-tab:complete:(cd|z|__zoxide_z|ls|eza):*' fzf-preview 'eza -1 --color=always --group-directories-first $realpath'
else
  zstyle ':fzf-tab:complete:(cd|z|__zoxide_z|ls):*' fzf-preview 'ls -1 --color=always $realpath'
fi

# Antidote plugin manager (completion, fzf-tab, autosuggestions, highlighting).
# ~/.zsh_plugins.txt starts with ez-compinit, which runs compinit for us.
# Install: git clone --depth=1 https://github.com/mattmc3/antidote.git ~/sh/antidote
if [ -f ~/sh/antidote/antidote.zsh ]; then
  source ~/sh/antidote/antidote.zsh
  antidote load ~/.zsh_plugins.txt
else
  autoload -Uz compinit && compinit
fi

# zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# Up/Down: move inside a multi-line command first, then search history for
# entries starting with what's typed so far (empty line = plain history).
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
for key in "${terminfo[kcuu1]}" '^[[A' '^[OA'; do
  [ -n "$key" ] && bindkey "$key" up-line-or-beginning-search
done
for key in "${terminfo[kcud1]}" '^[[B' '^[OB'; do
  [ -n "$key" ] && bindkey "$key" down-line-or-beginning-search
done
unset key

if test -n "$KITTY_INSTALLATION_DIR"; then
  export KITTY_SHELL_INTEGRATION="enabled"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

# .zshrc is only sourced by interactive shells, so no interactivity guard needed.
[ -f /usr/share/liquidprompt/liquidprompt ] && . /usr/share/liquidprompt/liquidprompt

# Per-machine overrides (untracked); last so they win.
[ -f ~/.zshrc.machine ] && source ~/.zshrc.machine

# typeset -U only dedupes array assignments; apply it to PATH=... edits above.
path=($path)
