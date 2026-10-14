# rcfiles
Set of good enough system configuration/rc files for Linux (Ubuntu, Fedora).

# setup
On a fresh Ubuntu (24.04+/26.x) or Fedora (44+) system, including under WSL
(where the Nerd Fonts are skipped):
```
./install.sh             # deps, then symlinks, then git identity
```
`install.sh` picks the distro script from `/etc/os-release` (derivatives such
as Linux Mint count as their base) and runs these steps, each safe to re-run
and usable on its own:
```
setup/ubuntu.sh          # system packages and mise, via apt
setup/fedora.sh          #   ...or via dnf
setup/common.sh          # antidote, liquidprompt, rustup, mise tools, fonts, zsh
./link.sh                # symlink the dotfiles into $HOME (--dry-run, --unlink)
setup/git-identity.sh    # write your git name/email to ~/.gitconfig.local
```
Use `./install.sh --skip-deps` to only relink and set the identity; that
works on any system. Run `./lint.sh` (shellcheck + `bash -n`/`zsh -n`) before
committing. GUI apps aren't installed by the scripts;
`setup/gui-apps.manifest.txt` lists the ones I use, one per line with its
homepage, to install by hand on either distro. For more fonts, the optional
`setup/install-fonts.sh [FOLDER]` asks for a name and searches the distro's
packages, Nerd Fonts, Google Fonts and the font files under FOLDER (default
`~/media/fonts`), then installs the ones you pick. `setup/ensure-fonts.sh
[--dry-run]` updates the fonts from the first three to their latest versions,
and moves loose files in `~/.local/share/fonts` whose family is on Google
Fonts over to the Google version (the loose files go to `~/.rcfiles-backup/`).

# Dependencies
Most config degrades gracefully when a tool is missing (commands are guarded
with `command -v`), but the following are assumed by the configuration as
written.

## mise
Developer CLI tools are installed and versioned by
[**mise**](https://mise.jdx.dev), from the tracked global config
`home/.config/mise/config.toml` (linked to `~/.config/mise/config.toml`):
neovim, tree-sitter, node, go, java (Temurin, current LTS), fzf, ripgrep, fd,
bat, delta, zoxide, eza, duf, dust, btop, procs, jq, jless, jnv, miller,
hyperfine, tokei, ttyper, uv, shellcheck and shfmt. `mise activate` also sets
`JAVA_HOME` and `GOROOT`; the config turns off mise's per-version `GOBIN`, so
`go install` puts binaries in `~/go/bin` (on PATH via `.shellrc.sh`) and they
survive Go upgrades. The distro script installs mise itself (from its apt
PPA or rpm repo), then `setup/common.sh` installs rustup if cargo is missing
(mise builds tokei with cargo) and runs `mise install`.
`.shellrc.sh` runs `mise activate` for both bash and zsh. Day to day:
`mise install` (add missing tools), `mise upgrade` (bump the `latest` ones),
`mise use -g <tool>@<version>` (edits the tracked config — commit it). A
project's own `mise.toml` overrides these versions inside that directory.
Terminals use `mise activate`; login files (`~/.profile`, `~/.zprofile`)
also put mise's shims on PATH so desktop-launched apps (editors, git GUIs)
find the same tools.
Only things mise can't or shouldn't own come from apt/dnf: zsh, git, tmux,
build tools and clipboard tools, plus tmuxinator on Ubuntu (Fedora doesn't
package it). antidote and liquidprompt are cloned from GitHub into `~/sh`,
and the Nerd Fonts are downloaded directly.

## Required
- **zsh** — shell; plugins are managed by antidote (cloned to `~/sh/antidote`
  by the setup script)
- **neovim** (latest stable, via mise; pin with `mise use -g neovim@<version>`)
  — editor (`EDITOR`, git's `core.editor`, and `vim`/`vi` are aliased to
  `nvim`); plugins are managed by vim-plug, which self-installs on
  first launch (needs **curl** and **git**). LSP servers (TypeScript, Python,
  Lua, Bash, JSON, YAML, Go) are installed by mason on first launch (needs
  **node**/**npm** and **go**, which mise provides), with completion
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
- **liquidprompt** — feature-rich prompt, cloned from its `stable` branch
  (the latest release) to `~/sh/liquidprompt` by the setup script; update it
  with `git -C ~/sh/liquidprompt pull`. Tuned in
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
  script (see `setup/gui-apps.manifest.txt`)
- **Sublime Text** — settings are linked to
  `~/.config/sublime-text/Packages/User/Preferences.sublime-settings` and
  expect the **CaskaydiaCove Nerd Font Mono**; not installed by the setup
  script (see `setup/gui-apps.manifest.txt`)
- **duf** — `df` alias
- **tmuxinator** — tmux session manager (apt on Ubuntu; on Fedora,
  `gem install tmuxinator`)
- **code** / **cursor** — git difftool/mergetool aliases (`git diffc`, etc.)

# Layout
- `home/` — mirrors `$HOME`: every file is symlinked to the same relative path
  (e.g. `home/.config/nvim/init.vim` → `~/.config/nvim/init.vim`). To add a
  config, drop it in at its home path and rerun `./link.sh`.
- `home/.shellrc.sh` — env, aliases and functions shared by bash and zsh
- `install.sh` — one-shot setup (deps → link → identity)
- `link.sh` — symlink the dotfiles; existing files are moved to
  `~/.rcfiles-backup/<timestamp>/`, dangling links into the repo are pruned
- `setup/ubuntu.sh`, `setup/fedora.sh` — system packages and mise for each
  distro; `setup/common.sh` — the distro-independent rest; `setup/lib.sh`
  holds their shared helpers
- `setup/git-identity.sh` — write your git name/email to `~/.gitconfig.local`
- `setup/install-fonts.sh` — optional: search for a font by name (packages,
  Nerd Fonts, Google Fonts, a local folder) and install the ones you pick into
  `~/.local/share/fonts` (packages system-wide)
- `setup/ensure-fonts.sh` — optional: update every font from packages, Nerd
  Fonts or Google Fonts to the latest version (via `install-fonts.sh`), moving
  loose Google-family files over to the Google version
- `lint.sh` — shellcheck the scripts, syntax-check the rc files (shellcheck
  comes from mise)
- `set-font.sh` — set the font family and size in the kitty, alacritty and
  Sublime Text configs, e.g. `./set-font.sh --all jetbrains 14`; the font is
  an alias (`--help` lists them), an installed family name, or words from one
  (asks which if several match); prints the diff and only writes with
  `--apply`

# Notes
- `~/.zshrc` and `~/.bashrc` both source `~/.shellrc.sh`. `~/.profile`
  (Ubuntu's default) and `~/.zprofile` are tracked too, for the mise shims.
  Fedora's stock `~/.bash_profile` shadows `~/.profile` for bash login
  shells; zsh, the login shell after setup, reads `~/.zprofile` instead.
- Per-machine tweaks (PATH entries, SDK/installer snippets like gcloud) go in
  untracked `~/.zshrc.machine` / `~/.bashrc.machine`, sourced last. Because
  `~/.zshrc` is a symlink into this repo, move anything an installer appends
  there into the `.machine` file instead of committing it.
- `~/.ssh/config` holds only generic defaults (connection sharing,
  keepalives, agent loading), since this repo is public. Real hosts go in
  untracked `~/.ssh/config.local`, which it includes first.
- The prompt is liquidprompt, configured by `~/.liquidpromptrc`.
- vim plugins install automatically on first launch via vim-plug.

