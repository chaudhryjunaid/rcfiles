# Settings shared by bash and zsh: env, aliases and helper functions.
# Symlinked to ~/.shellrc.sh by link.sh and sourced by ~/.zshrc and
# ~/.bashrc. Keep it to syntax both shells understand.

# Default editor.
export EDITOR=nvim
export VISUAL=nvim

alias vim='nvim'
alias vi='nvim'

# -F quits if the text fits one screen (less >= 530 needs no -X for that),
# -R passes colors through, -i makes search smart-case, --mouse scrolls with
# the wheel (shift+drag to select text while less is open), --incsearch
# highlights matches as you type, -j.3 puts a match a third of the way down
# rather than on the top line. Also applies to man (MANPAGER) and delta.
export LESS="-FRi --mouse --incsearch -j.3"
export PAGER='less'
export MANPAGER="less -R --use-color -Dd+r -Du+b"
# disable annoying docker menu at the bottom
export COMPOSE_MENU=false

export NODE_REPL_HISTORY=~/.node_history
export NODE_REPL_HISTORY_SIZE='32768'

# Go: keep GOPATH out of ~ (XDG layout). `go install` puts binaries in
# $GOPATH/bin; the module cache is re-downloadable, so it lives under ~/.cache
# next to Go's own build cache (~/.cache/go-build). Both are read by the
# `go` command directly, so gopls and friends pick them up via `go env`.
export GOPATH="$HOME/.local/share/go"
export GOMODCACHE="$HOME/.cache/go/mod"
export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$GOPATH/bin:$PATH"
# mise puts the tools from ~/.config/mise/config.toml (neovim, node, go, ...)
# on PATH, ahead of system ones, and switches versions per project on cd.
# The full hook (not --shims) because it also sets JAVA_HOME and GOROOT and
# loads mise.toml [env]; it costs ~18ms at startup.
# Activated before anything below that checks `command -v`.
if command -v mise >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    eval "$(mise activate zsh)"
  elif [ -n "${BASH_VERSION:-}" ]; then
    eval "$(mise activate bash)"
  fi
fi

# fzf defaults (key-bindings are loaded per shell).
command -v rg >/dev/null 2>&1 && export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
[ -n "${FZF_DEFAULT_COMMAND:-}" ] && export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# Alt-C: fd skips what .gitignore lists (venvs, build output), unlike fzf's walker.
command -v fd >/dev/null 2>&1 && export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
# --cycle wraps from the last match to the first, --info=inline-right puts
# the match count on the prompt line, Ctrl-/ shows or hides the preview.
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --cycle --info=inline-right --bind=ctrl-/:toggle-preview'
# Previews: file contents for Ctrl-T, a directory tree for Alt-C, and for
# Ctrl-R the whole command, wrapped (hidden until Ctrl-/; for long commands).
command -v bat >/dev/null 2>&1 && export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range=:300 {}'"
command -v eza >/dev/null 2>&1 && export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
export FZF_CTRL_R_OPTS="--preview 'echo {2..}' --preview-window=up:3:hidden:wrap"

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'
# -I asks once, and only for more than 3 files or a recursive delete.
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias c='clear'
alias r='reset'
alias ports='ss -tulpn'
alias myip='curl ifconfig.me'

alias please='sudo'
alias kssh="kitten ssh"

# rg typed at the prompt uses ~/.config/ripgrep/config (smart case, hidden
# files). Set per command, not exported, so tools that run rg keep its defaults.
if command -v rg >/dev/null 2>&1; then
  alias rg='RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/config rg'
  alias rgi='rg -i'
fi
# fd typed at the prompt includes dotfiles (.env, .github/), like rg above;
# fzf's Alt-C and scripts run fd unaliased.
command -v fd >/dev/null 2>&1 && alias fd='fd --hidden --exclude .git'
# bat's defaults (theme, style, no pager) are in ~/.config/bat/config.

# killport <port>: stop whatever is listening on the TCP port. Only the
# listener: a plain `lsof -i :<port>` also matches clients connected to that
# port (a browser tab on localhost:3000, anything talking to a remote :443).
killport() {
  if [ -z "$1" ]; then
    echo "Usage: killport <port>"
    return 1
  fi
  local pids
  pids=$(lsof -ti tcp:"$1" -sTCP:LISTEN)
  if [ -z "$pids" ]; then
    echo "Nothing is listening on port $1"
    return 1
  fi
  # SIGTERM first so servers can shut down cleanly; SIGKILL what's left.
  echo "$pids" | xargs kill
  sleep 1
  pids=$(lsof -ti tcp:"$1" -sTCP:LISTEN)
  [ -n "$pids" ] && echo "$pids" | xargs kill -9
  return 0
}

extract() {
  if [ -f "$1" ]; then
    case "$1" in
      # GNU tar auto-detects the compression (gz, bz2, xz, zst, ...).
      *.tar | *.tar.* | *.tgz | *.tbz2 | *.txz) tar xf "$1" ;;
      *.bz2) bunzip2 "$1" ;;
      *.rar) unrar x "$1" ;;
      *.gz) gunzip "$1" ;;
      *.xz) unxz "$1" ;;
      *.zst) unzstd "$1" ;;
      *.zip) unzip "$1" ;;
      *.7z) 7z x "$1" ;;
      *) echo "Unknown archive format: $1" ;;
    esac
  else
    echo "Not a file: $1"
  fi
}
