# rcfiles
Set of good enough system configuration/rc files for macOS/Linux.

# setup
On a fresh Ubuntu (24.04+/26.x) system:
```
./setup-ubuntu.sh        # install dependencies (see below)
./configure.sh           # symlink the dotfiles into place
./setup-git-identity.sh  # set your git name/email
```
On macOS, install the dependencies with Homebrew, then run `./configure.sh`
and `./setup-git-identity.sh`.

# after setup
Set your git identity in `~/.gitconfig.local` (created by `configure.sh`, untracked,
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
- a **Nerd Font** — for the glyphs in the tmux status bar, vim-airline and
  kitty; `setup-ubuntu.sh` installs the JetBrains Mono, Cascadia Code and
  Meslo Nerd Fonts

## zsh prompt & integrations
- **liquidprompt** — prompt
- **zsh-syntax-highlighting**, **zsh-autosuggestions**
- **fnm** — Node version manager (macOS config)
- **bat** — used as the man pager on macOS

## tmux
- **tmux** 3.2+ (popup styling)
- a clipboard tool for copy-mode: **wl-clipboard** (Wayland) or **xclip** /
  **xsel** (X11) on Linux; macOS uses pbcopy / OSC 52 automatically

## Optional
- **kitty** — terminal emulator; config is linked to `~/.config/kitty/kitty.conf`
  and expects the **JetBrainsMono Nerd Font**
- **duf** — `df` alias (Linux)
- **tmuxinator** — `mux` alias (macOS)
- **code** / **cursor** — git difftool/mergetool aliases (`git diffc`, etc.)

# Layout
- `_common/` — config shared across platforms, symlinked into `~/`
  (except `kitty.conf`, linked to `~/.config/kitty/`)
- `linux/`, `macos/` — platform-specific files (e.g. `zshrc.local`)
- `configure.sh` — symlink the dotfiles into place (backs up existing files)
- `setup-ubuntu.sh` — install dependencies on Ubuntu
- `setup-git-identity.sh` — write your git name/email to `~/.gitconfig.local`

# Notes
- zsh customizations live in `zshrc.local` (sourced from `~/.zshrc` by
  `configure.sh`) plus a shared `zshrc.common`.
- vim plugins install automatically on first launch via vim-plug.

