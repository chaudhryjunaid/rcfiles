# Settings shared by bash and zsh: env, aliases and helper functions.
# Symlinked to ~/.shellrc.sh by link.sh and sourced by ~/.zshrc.common
# and ~/.bashrc. Keep it to syntax both shells understand.

# Default editor.
export EDITOR=nvim
export VISUAL=nvim

alias vim='nvim'
alias vi='nvim'
alias v='nvim'
alias nv='nvim'
alias nvi='nvim'

# Prefer US English and use UTF-8. LANG only: exporting LC_ALL overrides every
# category and spews setlocale warnings where en_US.UTF-8 isn't generated.
export LANG='en_US.UTF-8'

export LESS="-FRX"
export PAGER='less'
export MANPAGER="less -R --use-color -Dd+r -Du+b"
# disable annoying docker menu at the bottom
export COMPOSE_MENU=false

export NODE_REPL_HISTORY=~/.node_history
export NODE_REPL_HISTORY_SIZE='32768'
export NODE_REPL_MODE='sloppy'

# Make Python use UTF-8 encoding for output to stdin, stdout, and stderr.
export PYTHONIOENCODING='UTF-8'

export CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=2
export CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=4
export CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1
export CLAUDE_CODE_FORK_SUBAGENT=0

# PATH: user bins first. fnm's install dir is added so `fnm env` can run.
export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$PATH"
[ -d "$HOME/.local/share/fnm" ] && export PATH="$HOME/.local/share/fnm:$PATH"
# Neovim managed by bob (`bob use stable`, `bob ls`); ahead of any system nvim.
[ -d "$HOME/.local/share/bob/nvim-bin" ] && export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

# fzf defaults (key-bindings are loaded per shell).
command -v rg >/dev/null 2>&1 && export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
[ -n "${FZF_DEFAULT_COMMAND:-}" ] && export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border'

# git aliases (a curated subset of the oh-my-zsh `git` plugin, vendored so we
# don't need a framework just for these).
alias g='git'
alias gst='git status'
alias gss='git status -s'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'
alias gcm='git commit -m'
alias gca='git commit -v -a'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gsw='git switch'
alias gb='git branch'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gd='git diff'
alias gds='git diff --staged'
alias gdca='git diff --cached'
alias gl='git pull'
alias gp='git push'
alias gf='git fetch'
alias gcl='git clone'
alias glog='git log --oneline --graph --decorate'
alias glga='git log --oneline --graph --decorate --all'
alias glo='git log --oneline --decorate'
alias glol="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"
alias glod="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'"
alias glola="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all"
alias gloda="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset' --all"
alias grh='git reset HEAD'
alias grhh='git reset --hard'
alias gstash='git stash'
alias gstp='git stash pop'

# oh-my-zsh helpers required by gbda: resolve the repo's trunk/develop branch
# so we never try to delete them when pruning merged branches.
git_main_branch() {
  command git rev-parse --git-dir >/dev/null 2>&1 || return
  local ref
  for ref in refs/heads/{main,trunk,mainline,default,stable,master} \
             refs/remotes/{origin,upstream}/{main,trunk,mainline,default,stable,master}; do
    if command git show-ref -q --verify "$ref"; then
      echo "${ref##*/}"
      return 0
    fi
  done
  echo master
  return 1
}

git_develop_branch() {
  command git rev-parse --git-dir >/dev/null 2>&1 || return
  local branch
  for branch in dev devel develop development; do
    if command git show-ref -q --verify "refs/heads/$branch"; then
      echo "$branch"
      return 0
    fi
  done
  echo develop
  return 1
}

# gbda: delete all local branches that have already been merged, skipping the
# main and develop branches.
gbda() {
  git branch --no-color --merged | command grep -vE "^([+*]|\s*($(git_main_branch)|$(git_develop_branch))\s*$)" | command xargs -r git branch --delete
}

# Use eza as a drop-in replacement for ls when available, else fall back.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias l='eza -1 --group-directories-first'
  alias ll='eza -lh --group-directories-first --git'
  alias la='eza -lah --group-directories-first --git'
  alias lt='eza --tree --level=2 --group-directories-first'
else
  alias ls='ls --color=auto'
  alias ll='ls -lh'
  alias la='ls -lah'
fi
alias grep='grep --color=auto'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias c='clear'
alias r='reset'
alias ports='ss -tulpn'
alias myip='curl ifconfig.me'

alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'

alias please='sudo'
alias kssh="kitty +kitten ssh"

command -v duf >/dev/null 2>&1 && alias df='duf'
command -v rg >/dev/null 2>&1 && alias rgi='rg -i'
command -v batcat >/dev/null 2>&1 && alias bat='batcat --paging=never'

killport() {
  if [ -z "$1" ]; then
    echo "Usage: killport <port>"
    return 1
  fi
  lsof -ti :"$1" | xargs -r kill -9
}

extract() {
  if [ -f "$1" ]; then
    case "$1" in
      # GNU tar auto-detects the compression (gz, bz2, xz, zst, ...).
      *.tar|*.tar.*|*.tgz|*.tbz2|*.txz) tar xf "$1" ;;
      *.bz2)     bunzip2 "$1" ;;
      *.rar)     unrar x "$1" ;;
      *.gz)      gunzip "$1" ;;
      *.xz)      unxz "$1" ;;
      *.zst)     unzstd "$1" ;;
      *.zip)     unzip "$1" ;;
      *.7z)      7z x "$1" ;;
      *)         echo "Unknown archive format: $1" ;;
    esac
  else
    echo "Not a file: $1"
  fi
}
