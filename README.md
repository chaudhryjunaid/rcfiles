# rcfiles
Set of good enough system configuration/rc files for macOS/Linux.

# setup
On a fresh Ubuntu (24.04+/26.x) system, including Ubuntu under WSL
(WSL is detected; kitty and the Nerd Fonts are skipped):
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

# Dependencies
Most config degrades gracefully when a tool is missing (commands are guarded
with `command -v`), but the following are assumed by the configuration as
written.

## Required
- **zsh** — shell; plugins are managed by antidote (cloned to `~/sh/antidote`
  by the setup scripts)
- **neovim** — editor (`EDITOR`, git's `core.editor`, and `vim`/`vi` are
  aliased to `nvim`); plugins are managed by vim-plug, which self-installs on
  first launch (needs **curl** and **git**). A plain-vim `vimrc` is kept too.
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
- **liquidprompt** — feature-rich prompt (installed via apt / brew); tuned in
  `~/.liquidpromptrc` to show git/VCS state, runtime, jobs, load, battery,
  virtualenv, return code and more
- **antidote** plugins, listed in `zsh_plugins.txt` (order matters):
  zsh-completions, ez-compinit (runs compinit), **fzf-tab** (replaces the
  completion menu with an fzf picker), **zsh-autosuggestions** and
  **zsh-syntax-highlighting** (last)
- **fnm** — Node version manager
- **bat** — used as the man pager on macOS
- **eza** — modern `ls`; aliased to `ls`/`l`/`ll`/`la`/`lt` when present (falls
  back to plain `ls` otherwise) and used for the `cd` completion preview in
  fzf-tab

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
  (except `kitty.conf` and `init.vim`, linked into `~/.config/`)
- `_common/shellrc.sh` — env, aliases and functions shared by bash and zsh
- `linux/`, `macos/` — platform-specific files (e.g. `zshrc`, the entry point
  symlinked to `~/.zshrc`)
- `configure.sh` — symlink the dotfiles into place (backs up existing files)
- `setup-ubuntu.sh` — install dependencies on Ubuntu (and Ubuntu on WSL)
- `setup-macos.sh` — install dependencies on macOS via Homebrew
- `setup-git-identity.sh` — write your git name/email to `~/.gitconfig.local`

# Notes
- The platform `zshrc` is the tracked entry point, symlinked to `~/.zshrc`; it
  sources `zshrc.common`, which sources `shellrc.sh`. `~/.bashrc` sources
  `shellrc.sh` too.
- Per-machine tweaks (PATH entries, SDK/installer snippets like gcloud) go in
  untracked `~/.zshrc.machine` / `~/.bashrc.machine`, sourced last. Because
  `~/.zshrc` is a symlink into this repo, move anything an installer appends
  there into the `.machine` file instead of committing it.
- The prompt is liquidprompt, configured by `~/.liquidpromptrc`.
- vim plugins install automatically on first launch via vim-plug.

