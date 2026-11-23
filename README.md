# rcfiles
Set of good enough system configuration/rc files for Linux (Ubuntu, Fedora).

# setup
On a fresh Ubuntu (24.04+/26.x) or Fedora (44+) system, including under WSL,
one command does everything, without cloning first:
```
curl -fsSL https://raw.githubusercontent.com/chaudhryjunaid/rcfiles/master/run.sh | bash
```
(or `wget -qO- … | bash` where curl isn't installed). `run.sh` installs git
if it's missing, clones the repo to `~/setup/rcfiles` (set `RCFILES_DIR` to
put it elsewhere; it has to stay there, since the dotfiles are linked into it)
or pulls an existing clone, then runs `install.sh` and
`setup/ensure-fonts.sh` (the programming fonts, JetBrainsMono Nerd Font
among them), and, on the first run (a fresh clone) only, sets every app to
JetBrainsMono Nerd Font with `set-font.sh`. It's safe to
re-run; later runs leave each machine's font settings alone.

From a clone, run the steps yourself:
```
./install.sh             # deps, then symlinks, then git identity
```
`install.sh` picks the distro script from `/etc/os-release` (derivatives such
as Linux Mint count as their base) and runs these steps, each safe to re-run
and usable on its own:
```
setup/ubuntu.sh          # system packages and mise, via apt
setup/fedora.sh          #   ...or via dnf
setup/common.sh          # antidote, liquidprompt, rustup, mise tools, zsh
./link.sh                # symlink the dotfiles into $HOME (--dry-run, --unlink)
setup/git-identity.sh    # write your git name/email to ~/.gitconfig
```
Use `./install.sh --skip-deps` to only relink and set the identity; that
works on any system. `--skip-identity` skips the identity prompt (it's only
asked while `~/.gitconfig` has no identity). The tracked git config sets
`user.useConfigOnly`, so git refuses to commit until one is set.

Commits to this repo run `hooks/pre-commit` (`install.sh` sets
`core.hooksPath`; on an older clone run `git config core.hooksPath hooks`).
It checks the staged files, not the working tree: whitespace errors and
conflict markers in the staged changes, no file over 512 KB, then
`./lint.sh` on a copy of the staged tree. `lint.sh` shellchecks the scripts
and rc files, parses the git, TOML, Sublime, tmux, Ghostty, kitty and nvim
configs (each one only if that app is installed), checks the manifests'
columns, and checks hygiene for a public repo: script modes, no symlinks or
per-machine files under `home/`, no real hosts in the ssh config, no private
keys or tokens. Run `./lint.sh` by hand any time; skip the hook once with
`git commit --no-verify`.

GUI apps aren't installed by the setup scripts. `gui-apps.manifest.csv` lists
the ones I use on a GNOME desktop (a snapshot of my main machine taken
2026-10-16), with columns `category,name,homepage,description,ubuntu,fedora`.
Apps that ship with a stock GNOME desktop (Firefox, ...) are left out.
`cli-apps.manifest.csv` does the same for command-line tools that aren't in a
stock Ubuntu desktop and that the setup scripts and mise config don't
install, with an extra `install` column for how each one got onto that
machine (Ubuntu 26.10): `apt: <packages>`, a vendor repo, `.deb`, snap,
release binary or installer script.

The `ubuntu` and `fedora` columns name each app's packages in that distro's
own repos (Fedora's often differ, e.g. `lm_sensors`, `vim-enhanced`), and are
empty when it has none. `./extra-install.sh [--dry-run] [--cli-only]`
installs those with apt or dnf (skipping apps already installed as a snap or
Flatpak), then lists the rest, to install the way each homepage recommends:
Flathub, Snap, the vendor's apt/rpm repo or package, or an AppImage (AppImages
need FUSE 2: `libfuse2t64` on Ubuntu, `fuse-libs` on Fedora).

Fonts aren't installed by `install.sh` either. The optional
`setup/install-fonts.sh [FOLDER]` asks for a name and searches the distro's
packages, Nerd Fonts, Google Fonts and the font files under FOLDER (default
`~/media/fonts`), then installs the ones you pick.
`setup/ensure-fonts.sh [--dry-run] [--update]` (which `run.sh` runs)
downloads ten programming fonts, the Nerd Fonts builds, from the latest Nerd
Fonts release into `~/.local/share/fonts/<Name>/`: JetBrains Mono, Cascadia
Code, Fira Code, Hack, Source Code Pro, Meslo LG, Ubuntu Mono, IBM Plex Mono,
Victor Mono and Commit Mono (about 570 MB). Re-runs only download what's
missing, or everything again once a newer release is out.

# Dependencies
Most config degrades gracefully when a tool is missing (commands are guarded
with `command -v`), but the following are assumed by the configuration as
written.

## mise
Developer CLI tools are installed and versioned by
[**mise**](https://mise.jdx.dev), from the tracked global config
`home/.config/mise/config.toml` (linked to `~/.config/mise/config.toml`):
neovim, tree-sitter, node, go, java (Temurin, current LTS), fzf, ripgrep, fd,
bat, delta, zoxide, eza, duf, dust, btop, procs, jq, hyperfine, tokei, uv,
shellcheck and shfmt. `mise activate` also sets
`JAVA_HOME` and `GOROOT`; the config turns off mise's per-version `GOBIN`, so
`go install` puts binaries in `$GOPATH/bin` (`~/.local/share/go/bin`, set and
put on PATH by `.shellrc.sh`) and they
survive Go upgrades. The distro script installs mise itself (Ubuntu: its
installer, into `~/.local/bin`; Fedora: its rpm repo), then `setup/common.sh` installs rustup if cargo is missing
(mise builds tokei with cargo) and runs `mise install`.
`.shellrc.sh` runs `mise activate` for both bash and zsh. Day to day:
`mise install` (add missing tools), `mise upgrade` (bump the `latest` ones),
`mise use -g <tool>@<version>` (edits the tracked config — commit it). A
project's own `mise.toml` overrides these versions inside that directory.
Terminals use `mise activate`; login files (`~/.profile`, `~/.zprofile`)
also put mise's shims on PATH so desktop-launched apps (editors, git GUIs)
find the same tools.
Only things mise can't or shouldn't own come from apt/dnf: zsh, git (with
git-crypt and git-lfs), tmux, build tools and clipboard tools,
plus tmuxinator on Ubuntu (Fedora doesn't package it). `setup/common.sh`
registers git-lfs's filters system-wide, in `/etc/gitconfig`. antidote and
liquidprompt are cloned from GitHub into `~/sh`.

## Required
- **zsh** — shell; plugins are managed by antidote (cloned to `~/sh/antidote`
  by the setup script)
- **neovim** (latest stable, via mise; pin with `mise use -g neovim@<version>`)
  — editor (`EDITOR`, git's `core.editor`, and `vim`/`vi` are aliased to
  `nvim`); plugins are managed by lazy.nvim, which self-installs on
  first launch (needs **git**) and installs the versions pinned in
  `home/.config/nvim/lazy-lock.json`. LSP servers (TypeScript, Python,
  Lua, Bash, JSON, YAML, Go) are installed by mason when the first file is
  opened (needs **node**/**npm** and **go**, which mise provides), with
  completion from blink.cmp. Treesitter parsers are built by nvim-treesitter's `main`
  branch, which needs **tree-sitter-cli** 0.26+ (mise) and a **C compiler** (the
  setup script installs one). A plain-vim `vimrc` is kept too.
- **git**
- **delta** — git pager / diff filter (git is configured to use it for
  `diff`/`log`; remove the `delta` lines from `home/.config/git/config` if you don't want it)
- **fzf** — fuzzy finder (shell key-bindings + vim `:Files`/`:Rg`)
- **ripgrep** (`rg`) — fzf's file source and vim's grep program
- **zoxide** — smarter `cd`; adds `z`/`zi` (jump by frecency / fzf-pick)
- a **Nerd Font** — for the glyphs in the tmux status bar and nvim's lualine;
  kitty, Alacritty, Ghostty and Sublime Text use `set-font.sh`'s font
  (change it with `./set-font.sh`). Not installed by the setup scripts
  (`setup/install-fonts.sh` finds and installs them)

## zsh prompt & integrations
- **liquidprompt** — feature-rich prompt, cloned from its `stable` branch
  (the latest release) to `~/sh/liquidprompt` by the setup script; update it
  with `git -C ~/sh/liquidprompt pull`. Tuned in
  `~/.liquidpromptrc` to show git/VCS state, runtime, jobs, load, battery,
  virtualenv, return code and more
- **antidote** plugins, listed in `.zsh_plugins.txt` (order matters):
  zsh-completions, ez-compinit (runs compinit), **fzf-tab** (replaces the
  completion menu with an fzf picker), **zsh-autosuggestions** and
  **fast-syntax-highlighting** (last; both deferred until after the first
  prompt)
- **node** — via mise (`node = "26"` in the mise config)
- **bat** — `cat` with syntax highlighting; `bat` is aliased to
  `bat --paging=never` (`cat` itself is not aliased)
- **eza** — modern `ls`; backs the `l`/`ll`/`la`/`lt` aliases when present
  (they fall back to plain `ls` otherwise; `ls` itself stays GNU `ls`) and is
  used for the `cd` completion preview in fzf-tab

## tmux
- **tmux** 3.2+ (popup styling); the prefix is `` ` `` (backtick; press it
  twice for a literal one). `Ctrl-h/j/k/l` moves between tmux panes and nvim
  splits alike (vim-tmux-navigator), `` `Ctrl-l `` clears the screen
- a clipboard tool for copy-mode: **wl-clipboard** (Wayland) or **xclip** /
  **xsel** (X11)

## Optional
- **kitty** — terminal emulator; config is linked to `~/.config/kitty/kitty.conf`
  and expects the **JetBrainsMono Nerd Font**; not installed by the setup
  script (see `gui-apps.manifest.csv`)
- **Ghostty** — terminal emulator; config is linked to
  `~/.config/ghostty/config.ghostty` (Gogh's `Papercolor Dark` theme, tracked
  in `themes/`; bundles its own Nerd Font symbols, so any font works); check it with
  `ghostty +validate-config`; not installed by the setup script (see
  `gui-apps.manifest.csv`)
- **Alacritty** — terminal emulator; config is linked to
  `~/.config/alacritty/alacritty.toml` (colors imported from `gogh.toml`
  next to it) and expects the **JetBrainsMono Nerd Font**; not installed by
  the setup script (see `gui-apps.manifest.csv`)
- **Sublime Text** — settings are linked to
  `~/.config/sublime-text/Packages/User/Preferences.sublime-settings` and
  expect the **JetBrainsMono Nerd Font**; not installed by the setup
  script (see `gui-apps.manifest.csv`)
- **duf** — friendlier `df`; run it as `duf` (`df` is not aliased)
- **tmuxinator** — tmux session manager (apt on Ubuntu; on Fedora,
  `gem install tmuxinator`)
- **code** / **cursor** — git difftool/mergetool aliases (`git diffc`, etc.)

# Layout
- `home/` — mirrors `$HOME`: every file is symlinked to the same relative path
  (e.g. `home/.config/nvim/init.lua` → `~/.config/nvim/init.lua`). To add a
  config, drop it in at its home path and rerun `./link.sh`.
- `home/.shellrc.sh` — env, aliases and functions shared by bash and zsh
- `run.sh` — bootstrap from GitHub: clone/update the repo, `install.sh`,
  fonts, `set-font.sh` (see setup above)
- `install.sh` — one-shot setup (deps → link → identity)
- `link.sh` — symlink the dotfiles; existing files are moved to
  `~/.rcfiles-backup/<timestamp>/`, dangling links into the repo are pruned
- `setup/ubuntu.sh`, `setup/fedora.sh` — system packages and mise for each
  distro; `setup/common.sh` — the distro-independent rest; `setup/lib.sh`
  holds their shared helpers
- `setup/git-identity.sh` — write your git name/email to `~/.gitconfig`
- `setup/install-fonts.sh` — optional: search for a font by name (packages,
  Nerd Fonts, Google Fonts, a local folder) and install the ones you pick into
  `~/.local/share/fonts` (packages system-wide)
- `setup/ensure-fonts.sh` — install the ten programming fonts (Nerd Fonts
  builds) and keep them on the latest Nerd Fonts release
- `gui-apps.manifest.csv` — GUI apps and GNOME extensions to install by
  hand
- `cli-apps.manifest.csv` — CLI tools the setup scripts don't install, to
  install by hand
- `extra-install.sh` — optional: install the apps from both manifests that
  the distro's own repos have (their `ubuntu`/`fedora` column)
- `lint.sh` — shellcheck the scripts and rc files, parse the app configs,
  check the manifests and repo hygiene (shellcheck comes from mise)
- `hooks/pre-commit` — runs `lint.sh` on the staged files before each commit
- `set-font.sh` — set the font family and size in the kitty, Alacritty,
  Ghostty and Sublime Text configs. Run with no arguments: pick the app from
  a numbered menu, the font in fzf (every installed family; Enter or Tab to
  choose), then type the size. Scripted form: `./set-font.sh APP|all FONT
  SIZE`, with the exact family name

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
- git's shared settings are tracked as `~/.config/git/config`. `~/.gitconfig`
  is untracked and per machine (`link.sh` creates it): git reads it last, so
  it wins, and it holds the identity plus anything `git config --global`,
  `git lfs install` or git GUIs write, which keeps those out of the repo.
  (Older setups linked `~/.gitconfig` into the repo and kept the identity in
  `~/.gitconfig.local`; `link.sh` moves that file to `~/.gitconfig`.)
- The prompt is liquidprompt, configured by `~/.liquidpromptrc`.
- nvim plugins install automatically on first launch via lazy.nvim, at the
  commits in `lazy-lock.json`. `:Lazy update` upgrades them and rewrites the
  lockfile in this checkout (commit it); `:Lazy restore` goes back to the
  pinned versions. Coming from the old vim-plug `init.vim`, rerun
  `./link.sh` (it prunes the dangling `init.vim` link, which Neovim would
  otherwise report as a conflicting config) and delete
  `~/.local/share/nvim/plugged`.
