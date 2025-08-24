# Zsh Plugins from Homebrew
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Enable completions
if type brew &>/dev/null; then
    FPATH=/opt/homebrew/share/zsh-completions:$FPATH
    autoload -Uz compinit && compinit
fi

eval "$(starship init zsh)"

# FZF Configuration
export FZF_DEFAULT_COMMAND='fd --type file --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type directory --hidden --follow --exclude .git'

# FZF theme (Nord inspired)
export FZF_DEFAULT_OPTS='
  --height 40% --layout=reverse --border
  --color=bg+:#3B4252,bg:#2E3440,spinner:#81A1C1,hl:#616E88
  --color=fg:#D8DEE9,header:#616E88,info:#81A1C1,pointer:#81A1C1
  --color=marker:#81A1C1,fg+:#D8DEE9,prompt:#81A1C1,hl+:#81A1C1
'

# Enable FZF key bindings and completion
source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
source /opt/homebrew/opt/fzf/shell/completion.zsh


# FNM (Fast Node Manager) Configuration
eval "$(fnm env --use-on-cd)"
export FNM_DIR="$HOME/.fnm"
export FNM_ARCH="arm64"
export FNM_COREPACK_ENABLED="true"
export FNM_LOGLEVEL="info"


# Modern CLI replacements
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
#alias cat='bat'
#alias find='fd'
#alias grep='rg'

# Git aliases with delta
alias gdiff='git diff'
alias gshow='git show'

# FZF powered aliases
alias preview="fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'"
alias vf='vim $(fzf --height 40% --preview "bat --style=numbers --color=always {}")'
alias cdf='cd $(fd --type d | fzf --preview "ls -la {}")'

# Ripgrep with preview
alias rgf='rg --line-number --no-heading --color=always --smart-case "" | fzf -d ":" --preview "bat --color=always {1} --highlight-line {2}" --preview-window "right:60%:wrap"'


# History Configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS

# Directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Completion settings
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select

# Key bindings

# Useful functions
mkcd() { mkdir -p "$1" && cd "$1" }
backup() { cp "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)" }

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'



# History substring search plugin
source /opt/homebrew/share/zsh-history-substring-search/zsh-history-substring-search.zsh

# Bind keys for history substring search
bindkey '^[[A' history-substring-search-up    # Up arrow
bindkey '^[[B' history-substring-search-down  # Down arrow
bindkey '^P' history-substring-search-up      # Ctrl+P
bindkey '^N' history-substring-search-down    # Ctrl+N

# Also bind in vi mode if you use it
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

source ~/.zshrc.local

