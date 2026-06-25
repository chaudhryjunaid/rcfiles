# rcfiles
Set of good enough system configuration/rc files for macOS/Linux.

# after setup
Set your git identity in `~/.gitconfig.local` (created by `install.sh`, untracked,
included by the tracked `~/.gitconfig`):
```
git config -f ~/.gitconfig.local user.name "Your Name"
git config -f ~/.gitconfig.local user.email "your.email@example.com"
```

# Dependencies
Most config degrades gracefully when a tool is missing (commands are guarded
with `command -v`), but the following are assumed by the configuration as
written.

## Required
- **zsh** + **oh-my-zsh** — shell and framework
- **vim** (8.0+, built with `+clipboard`) — editor; plugins are managed by
  vim-plug, which self-installs on first launch (needs **curl** and **git**)
- **git**
- **delta** — git pager / diff filter (git is configured to use it for
  `diff`/`log`; remove the `delta` lines from `gitconfig` if you don't want it)
- **fzf** — fuzzy finder (shell key-bindings + vim `:Files`/`:Rg`)
- **ripgrep** (`rg`) — fzf's file source and vim's grep program
- a **Nerd Font** — for the glyphs in the tmux status bar and vim-airline

## zsh prompt & integrations
- **liquidprompt** — prompt
- **zsh-syntax-highlighting**, **zsh-autosuggestions**
- **fnm** — Node version manager (macOS config)
- **bat** — used as the man pager on macOS

## tmux
- **tmux** 3.2+ (popup styling)
- a clipboard tool for copy-mode: **wl-clipboard** (Wayland) or **xclip** /
  **xsel** (X11) on Linux; macOS uses pbcopy / OSC 52 automatically

## Optional (aliases that no-op if the tool is absent)
- **duf** — `df` alias (Linux)
- **tmuxinator** — `mux` alias (macOS)
- **code** / **cursor** — git difftool/mergetool aliases (`git diffc`, etc.)

# Notes
- zsh customizations live in `zshrc.local` (sourced from `~/.zshrc` by
  `install.sh`) plus a shared `zshrc.common`.
- vim plugins install automatically on first launch via vim-plug.

