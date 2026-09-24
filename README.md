# rcfiles
Set of good enough system configuration/rc files for macOS/Linux.

# setup
On a fresh Ubuntu (24.04+/26.x) system (including Ubuntu under WSL, where
kitty and the Nerd Fonts are skipped) or on macOS:
```
./install.sh             # deps, then symlinks, then git identity
```
`install.sh` runs these steps, each safe to re-run and usable on its own:
```
setup/ubuntu.sh          # or setup/macos.sh: install dependencies
./link.sh                # symlink the dotfiles into $HOME (--dry-run, --unlink)
setup/git-identity.sh    # write your git name/email to ~/.gitconfig.local
```
Use `./install.sh --skip-deps` to only relink and set the identity. Run
`./lint.sh` (shellcheck + `bash -n`/`zsh -n`) before committing.

# Dependencies
Most config degrades gracefully when a tool is missing (commands are guarded
with `command -v`), but the following are assumed by the configuration as
written.

## Required
- **zsh** — shell; plugins are managed by antidote (cloned to `~/sh/antidote`
  by the setup scripts)
- **neovim** (latest stable, installed and managed by
  [**bob**](https://github.com/MordechaiHadad/bob): `bob use stable`,
  `bob ls`, `bob use <version>` to switch; its `nvim-bin` is put on PATH by
  `.shellrc.sh`, ahead of any system nvim) — editor (`EDITOR`, git's `core.editor`, and `vim`/`vi` are
  aliased to `nvim`); plugins are managed by vim-plug, which self-installs on
  first launch (needs **curl** and **git**). LSP servers (TypeScript, Python,
  Lua, Bash, JSON, YAML; Go when `go` is present) are installed by mason on
  first launch (needs **node**/**npm**, which fnm provides), with completion
  from blink.cmp. Treesitter parsers are built by nvim-treesitter's `main`
  branch, which needs **tree-sitter-cli** 0.26+ and a **C compiler** (the setup
  scripts install both). A plain-vim
  `vimrc` is kept too.
- **git**
- **delta** — git pager / diff filter (git is configured to use it for
  `diff`/`log`; remove the `delta` lines from `.gitconfig` if you don't want it)
- **fzf** — fuzzy finder (shell key-bindings + vim `:Files`/`:Rg`)
- **ripgrep** (`rg`) — fzf's file source and vim's grep program
- **zoxide** — smarter `cd`; adds `z`/`zi` (jump by frecency / fzf-pick)
- a **Nerd Font** — for the glyphs in the tmux status bar, vim-airline and
  kitty; the setup scripts install the JetBrains Mono, Cascadia Code and
  Meslo Nerd Fonts

## zsh prompt & integrations
- **liquidprompt** — feature-rich prompt (installed via apt / brew); tuned in
  `~/.liquidpromptrc` to show git/VCS state, runtime, jobs, load, battery,
  virtualenv, return code and more
- **antidote** plugins, listed in `.zsh_plugins.txt` (order matters):
  zsh-completions, ez-compinit (runs compinit), **fzf-tab** (replaces the
  completion menu with an fzf picker), **zsh-autosuggestions** and
  **zsh-syntax-highlighting** (last)
- **fnm** — Node version manager
- **bat** — used as the man pager on macOS
- **eza** — modern `ls`; aliased to `ls`/`l`/`ll`/`la`/`lt` when present (falls
  back to plain `ls` otherwise) and used for the `cd` completion preview in
  fzf-tab

## tmux
- **tmux** 3.2+ (popup styling); `Ctrl-h/j/k/l` moves between tmux panes and
  nvim splits alike (vim-tmux-navigator), `` `Ctrl-l `` clears the screen
- a clipboard tool for copy-mode: **wl-clipboard** (Wayland) or **xclip** /
  **xsel** (X11) on Linux; macOS uses pbcopy / OSC 52 automatically

## Optional
- **kitty** — terminal emulator; config is linked to `~/.config/kitty/kitty.conf`
  and expects the **JetBrainsMono Nerd Font**
- **duf** — `df` alias (Linux)
- **tmuxinator** — `mux` alias (macOS)
- **code** / **cursor** — git difftool/mergetool aliases (`git diffc`, etc.)

# Layout
- `home/common/`, `home/linux/`, `home/macos/` — mirror `$HOME`: every file is
  symlinked to the same relative path (e.g. `home/common/.config/nvim/init.vim`
  → `~/.config/nvim/init.vim`). A platform file overrides a common one with
  the same path. To add a config, drop it in at its home path and rerun
  `./link.sh`.
- `home/common/.shellrc.sh` — env, aliases and functions shared by bash and zsh
- `install.sh` — one-shot setup (deps → link → identity)
- `link.sh` — symlink the dotfiles; existing files are moved to
  `~/.rcfiles-backup/<timestamp>/`, dangling links into the repo are pruned
- `setup/ubuntu.sh`, `setup/macos.sh` — install dependencies; `setup/lib.sh`
  holds their shared helpers
- `setup/git-identity.sh` — write your git name/email to `~/.gitconfig.local`
- `lint.sh` — shellcheck the scripts, syntax-check the rc files

# Notes
- The platform `.zshrc` is the tracked entry point, symlinked to `~/.zshrc`;
  it sources `.zshrc.common`, which sources `.shellrc.sh`. `~/.bashrc` sources
  `.shellrc.sh` too.
- Per-machine tweaks (PATH entries, SDK/installer snippets like gcloud) go in
  untracked `~/.zshrc.machine` / `~/.bashrc.machine`, sourced last. Because
  `~/.zshrc` is a symlink into this repo, move anything an installer appends
  there into the `.machine` file instead of committing it.
- The prompt is liquidprompt, configured by `~/.liquidpromptrc`.
- vim plugins install automatically on first launch via vim-plug.

