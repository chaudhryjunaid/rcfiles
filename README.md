# rcfiles
Set of good enough system configuration/rc files for macOS/Linux.

# setup
On a fresh Ubuntu (24.04+/26.x) system:
```
./setup-ubuntu.sh        # install dependencies (see below)
./configure.sh           # symlink the dotfiles into place
./setup-git-identity.sh  # set your git name/email
```
On macOS:
```
./setup-macos.sh         # install dependencies via Homebrew
./configure.sh           # symlink the dotfiles into place
./setup-git-identity.sh  # set your git name/email
```

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
- **zsh** — shell (no framework; the prompt is starship and the two plugins
  below are sourced directly from `~/.zsh/plugins`)
- **vim** (8.0+, built with `+clipboard`) — editor; plugins are managed by
  vim-plug, which self-installs on first launch (needs **curl** and **git**)
- **git**
- **delta** — git pager / diff filter (git is configured to use it for
  `diff`/`log`; remove the `delta` lines from `gitconfig` if you don't want it)
- **fzf** — fuzzy finder (shell key-bindings + vim `:Files`/`:Rg`)
- **ripgrep** (`rg`) — fzf's file source and vim's grep program
- **zoxide** — smarter `cd`; adds `z`/`zi` (jump by frecency / fzf-pick)
- a **Nerd Font** — for the glyphs in the tmux status bar, vim-airline and
  kitty; `setup-ubuntu.sh` installs the JetBrains Mono, Cascadia Code and
  Meslo Nerd Fonts

## zsh prompt & integrations
- **starship** — prompt (`setup-ubuntu.sh` installs it via the official script,
  since it isn't reliably packaged in apt; `setup-macos.sh` installs it via brew)
- **fzf-tab**, **zsh-syntax-highlighting**, **zsh-autosuggestions** — cloned to
  `~/.zsh/plugins` by the setup scripts and sourced directly by `~/.zshrc`
  (fzf-tab replaces the completion menu with an fzf picker)
- **fnm** — Node version manager
- **bat** — used as the man pager on macOS
- **eza** — optional; used for the `cd` completion preview in fzf-tab

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
- `linux/`, `macos/` — platform-specific files (e.g. `zshrc`, the entry point
  symlinked to `~/.zshrc`)
- `configure.sh` — symlink the dotfiles into place (backs up existing files)
- `setup-ubuntu.sh` — install dependencies on Ubuntu
- `setup-macos.sh` — install dependencies on macOS via Homebrew
- `setup-git-identity.sh` — write your git name/email to `~/.gitconfig.local`

# Notes
- The platform `zshrc` is the tracked entry point, symlinked to `~/.zshrc`; it
  sources a shared `zshrc.common`. Per-machine tweaks go in an untracked
  `~/.zshrc.machine` (sourced automatically if present).
- No shell framework: the prompt is starship and the two zsh plugins are
  sourced directly from `~/.zsh/plugins`.
- vim plugins install automatically on first launch via vim-plug.

