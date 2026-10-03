# rcfiles
Set of good enough system configuration/rc files for Linux (Ubuntu).

# setup
On a fresh Ubuntu (24.04+/26.x) system (including Ubuntu under WSL, where
the Nerd Fonts are skipped):
```
./install.sh             # deps, then symlinks, then git identity
```
`install.sh` runs these steps, each safe to re-run and usable on its own:
```
setup/ubuntu.sh          # install dependencies (incl. mise tools)
./link.sh                # symlink the dotfiles into $HOME (--dry-run, --unlink)
setup/git-identity.sh    # write your git name/email to ~/.gitconfig.local
```
Use `./install.sh --skip-deps` to only relink and set the identity. Run
`./lint.sh` (shellcheck + `bash -n`/`zsh -n`) before committing. GUI apps
aren't installed by the scripts; `setup/ubuntu-gui-apps.txt` lists them and
how to install each by hand.

# Dependencies
Most config degrades gracefully when a tool is missing (commands are guarded
with `command -v`), but the following are assumed by the configuration as
written.

## mise
Developer CLI tools are installed and versioned by
[**mise**](https://mise.jdx.dev), from the tracked global config
`home/.config/mise/config.toml` (linked to `~/.config/mise/config.toml`):
neovim, tree-sitter, node, fzf, ripgrep, fd, bat, delta, zoxide, eza, duf,
dust, btop, procs, jq, jless, jnv, miller, hyperfine, tokei, ttyper, uv,
shellcheck and shfmt. `setup/ubuntu.sh` installs mise itself (from its apt
PPA), and rustup if cargo is missing (mise builds tokei with cargo), then
runs `mise install`;
`.shellrc.sh` runs `mise activate` for both bash and zsh. Day to day:
`mise install` (add missing tools), `mise upgrade` (bump the `latest` ones),
`mise use -g <tool>@<version>` (edits the tracked config — commit it). A
project's own `mise.toml` overrides these versions inside that directory.
Terminals use `mise activate`; login files (`~/.profile`, `~/.zprofile`)
also put mise's shims on PATH so desktop-launched apps (editors, git GUIs)
find the same tools.
Only things mise can't or shouldn't own come from apt: zsh, git, tmux, build
tools, clipboard tools, liquidprompt and tmuxinator (plus the Nerd Fonts,
downloaded directly).

## Required
- **zsh** — shell; plugins are managed by antidote (cloned to `~/sh/antidote`
  by the setup script)
- **neovim** (latest stable, via mise; pin with `mise use -g neovim@<version>`)
  — editor (`EDITOR`, git's `core.editor`, and `vim`/`vi` are aliased to
  `nvim`); plugins are managed by vim-plug, which self-installs on
  first launch (needs **curl** and **git**). LSP servers (TypeScript, Python,
  Lua, Bash, JSON, YAML; Go when `go` is present) are installed by mason on
  first launch (needs **node**/**npm**, which mise provides), with completion
  from blink.cmp. Treesitter parsers are built by nvim-treesitter's `main`
  branch, which needs **tree-sitter-cli** 0.26+ (mise) and a **C compiler** (the
  setup script installs one). A plain-vim `vimrc` is kept too.
- **git**
- **delta** — git pager / diff filter (git is configured to use it for
  `diff`/`log`; remove the `delta` lines from `.gitconfig` if you don't want it)
- **fzf** — fuzzy finder (shell key-bindings + vim `:Files`/`:Rg`)
- **ripgrep** (`rg`) — fzf's file source and vim's grep program
- **zoxide** — smarter `cd`; adds `z`/`zi` (jump by frecency / fzf-pick)
- a **Nerd Font** — for the glyphs in the tmux status bar, vim-airline and
  kitty; the setup script installs the JetBrains Mono, Cascadia Code and
  Meslo Nerd Fonts

## zsh prompt & integrations
- **liquidprompt** — feature-rich prompt (installed via apt); tuned in
  `~/.liquidpromptrc` to show git/VCS state, runtime, jobs, load, battery,
  virtualenv, return code and more
- **antidote** plugins, listed in `.zsh_plugins.txt` (order matters):
  zsh-completions, ez-compinit (runs compinit), **fzf-tab** (replaces the
  completion menu with an fzf picker), **zsh-autosuggestions** and
  **zsh-syntax-highlighting** (last)
- **node** — via mise (`node = "26"` in the mise config)
- **bat** — `cat` with syntax highlighting (aliased to `bat --paging=never`)
- **eza** — modern `ls`; aliased to `ls`/`l`/`ll`/`la`/`lt` when present (falls
  back to plain `ls` otherwise) and used for the `cd` completion preview in
  fzf-tab

## tmux
- **tmux** 3.2+ (popup styling); `Ctrl-h/j/k/l` moves between tmux panes and
  nvim splits alike (vim-tmux-navigator), `` `Ctrl-l `` clears the screen
- a clipboard tool for copy-mode: **wl-clipboard** (Wayland) or **xclip** /
  **xsel** (X11)

## Optional
- **kitty** — terminal emulator; config is linked to `~/.config/kitty/kitty.conf`
  and expects the **JetBrainsMono Nerd Font**; not installed by the setup
  script
- **duf** — `df` alias
- **tmuxinator** — tmux session manager
- **code** / **cursor** — git difftool/mergetool aliases (`git diffc`, etc.)

# Layout
- `home/` — mirrors `$HOME`: every file is symlinked to the same relative path
  (e.g. `home/.config/nvim/init.vim` → `~/.config/nvim/init.vim`). To add a
  config, drop it in at its home path and rerun `./link.sh`.
- `home/.shellrc.sh` — env, aliases and functions shared by bash and zsh
- `install.sh` — one-shot setup (deps → link → identity)
- `link.sh` — symlink the dotfiles; existing files are moved to
  `~/.rcfiles-backup/<timestamp>/`, dangling links into the repo are pruned
- `setup/ubuntu.sh` — install dependencies; `setup/lib.sh` holds its helpers
- `setup/git-identity.sh` — write your git name/email to `~/.gitconfig.local`
- `lint.sh` — shellcheck the scripts, syntax-check the rc files (shellcheck
  comes from mise)

# Notes
- `~/.zshrc` and `~/.bashrc` both source `~/.shellrc.sh`. `~/.profile`
  (Ubuntu's default) and `~/.zprofile` are tracked too, for the mise shims.
- Per-machine tweaks (PATH entries, SDK/installer snippets like gcloud) go in
  untracked `~/.zshrc.machine` / `~/.bashrc.machine`, sourced last. Because
  `~/.zshrc` is a symlink into this repo, move anything an installer appends
  there into the `.machine` file instead of committing it.
- The prompt is liquidprompt, configured by `~/.liquidpromptrc`.
- vim plugins install automatically on first launch via vim-plug.

