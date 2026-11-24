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
setup/common.sh          # antidote, liquidprompt, rustup, mise tools, zsh, hidden launchers
./link.sh                # symlink the dotfiles into $HOME (--dry-run, --unlink)
setup/git-identity.sh    # write your git name/email and SSH signing key to ~/.gitconfig
```
Day to day, from the clone:
```
./update.sh              # update the checkout, mise tools, plugins, parsers, fonts, tldr
./doctor.sh              # read-only health check: ✓ / ! / ✗ per item, with the fix
./cleanup.sh             # free disk space (asks per item; --dry-run, --yes)
./manifest-diff.sh       # manifests vs what's installed, both ways
./manifest-update.sh     # add rows for what's installed here (--prune, --dry-run)
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
the ones I use on a GNOME desktop (a snapshot of my main machine, kept
current with `./manifest-update.sh`). Apps that ship with a stock GNOME
desktop (Firefox, ...) are left out. `cli-apps.manifest.csv` does the same
for command-line tools that aren't in a stock Ubuntu desktop and that the
setup scripts and mise config don't install. Both have the columns
`category,name,homepage,description,install,ubuntu,fedora`, where `install`
says how the app got onto that machine (Ubuntu 26.10): `apt: <packages>`,
`apt, from <host>'s repo: <packages>`, `.deb from the homepage: <package>`,
`snap: <name> [--classic]`, `flatpak: <app id>`, `extension: <uuid>` (a
GNOME extension from extensions.gnome.org), `Chrome: Install page as app`,
or a release binary or installer script. `./manifest-update.sh` fills it in.

The `ubuntu` and `fedora` columns name each app's packages in that distro's
own repos (Fedora's often differ, e.g. `lm_sensors`, `vim-enhanced`), and are
empty when it has none. `./extra-install.sh [--dry-run] [--cli-only]`
installs those with apt or dnf, and the `snap:` and `flatpak:` rows with
snap and Flatpak (adding Flathub if needed), skipping apps already installed
either way. It lists the rest with their `install` column, to install by
hand: a vendor's apt/rpm repo or package, a GNOME extension (Extension
Manager), an installer, or an AppImage (AppImages need FUSE 2:
`libfuse2t64` on Ubuntu, `fuse-libs` on Fedora).

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
shellcheck, shfmt, lazygit, tealdeer, gh (GitHub CLI), jless (JSON viewer)
and edit (Microsoft Edit, a simple terminal editor). `mise activate` also sets
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
git-crypt and git-lfs), tmux, build tools and clipboard tools.
`setup/common.sh` registers git-lfs's filters system-wide, in
`/etc/gitconfig`, and hides the vim, nvim, info and texdoctk launchers from
the app grid (a `NoDisplay=true` copy of each in
`~/.local/share/applications`; delete the copy to bring one back). antidote and
liquidprompt are cloned from GitHub into `~/sh`.

## Required
- **zsh** — shell; plugins are managed by antidote (cloned to `~/sh/antidote`
  by the setup script)
- **neovim** (latest stable, via mise; pin with `mise use -g neovim@<version>`)
  — the only editor configured here: `EDITOR`/`VISUAL` in shells and, through
  `~/.config/environment.d`, the desktop session; git's `core.editor`;
  `vim`/`vi` aliased to `nvim`; and system-wide (for root, `sudo -i`, ...)
  the distro's `neovim`: on Ubuntu as the `editor`/`vi`/`vim` alternative,
  on Fedora via `/etc/profile.d/zz-nvim-default-editor.sh`, which takes over
  from `nano-default-editor` (Fedora has no neovim one); plugins are managed by lazy.nvim, which self-installs on
  first launch (needs **git**) and installs the versions pinned in
  `home/.config/nvim/lazy-lock.json`. LSP servers (TypeScript, Python,
  Lua, Bash, JSON, YAML, Go) are installed by mason when the first file is
  opened (needs **node**/**npm** and **go**, which mise provides), with
  completion from blink.cmp. Treesitter parsers are built by nvim-treesitter's `main`
  branch, which needs **tree-sitter-cli** 0.26+ (mise) and a **C compiler** (the
  setup script installs one).
- **git**
- **delta** — git pager / diff filter (git is configured to use it for
  `diff`/`log`; remove the `delta` lines from `home/.config/git/config` if you don't want it)
- **fzf** — fuzzy finder (shell key-bindings + nvim `:Files`/`:Rg`)
- **ripgrep** (`rg`) — fzf's file source and nvim's `:Rg`
- **zoxide** — smarter `cd`; adds `z`/`zi` (jump by frecency / fzf-pick)
- a **Nerd Font** — for the glyphs in the tmux status bar and nvim's lualine;
  kitty, Ghostty and Sublime Text use `set-font.sh`'s font
  (change it with `./set-font.sh`). Not installed by the setup scripts
  (`setup/install-fonts.sh` finds and installs them)

## zsh prompt & integrations
- **liquidprompt** — feature-rich prompt, cloned from its `stable` branch
  (the latest release) to `~/sh/liquidprompt` by the setup script; update it
  with `git -C ~/sh/liquidprompt pull`. Tuned in
  `~/.config/liquidpromptrc` to show git/VCS state, runtime, jobs, load, battery,
  virtualenv, return code and more
- **antidote** plugins, listed in `.zsh_plugins.txt` (order matters):
  zsh-completions, ez-compinit (runs compinit), **fzf-tab** (replaces the
  completion menu with an fzf picker), **fzf-git.sh** (`Ctrl-G` then
  `Ctrl-F`/`B`/`T`/`R`/`H`/`S`/`L`/`E`/`W` picks git files, branches, tags,
  remotes, commit hashes, stashes, reflog, refs or worktrees),
  **zsh-autosuggestions** and **fast-syntax-highlighting** (last; these
  three deferred until after the first prompt)
- **lazygit** — git TUI (stage hunks, commit, browse history); diffs go
  through delta, `e` opens nvim (`~/.config/lazygit/config.yml`)
- **tldr** (tealdeer) — short command examples, `tldr tar`; pages download
  on first use and refresh monthly (`~/.config/tealdeer/config.toml`)
- **node** — via mise (`node = "26"` in the mise config)
- **bat** — `cat` with syntax highlighting; `~/.config/bat/config` sets its
  theme (TwoDark), style and no pager (`cat` itself is not aliased)
- **eza** — modern `ls`; backs the `l`/`ll`/`la`/`lt` aliases when present
  (they fall back to plain `ls` otherwise; `ls` itself stays GNU `ls`) and is
  used for the `cd` completion preview in fzf-tab

## tmux
- **tmux** 3.2+ (popup styling); the prefix is `` ` `` (backtick; press it
  twice for a literal one). `Ctrl-h/j/k/l` moves between tmux panes and nvim
  splits alike (vim-tmux-navigator), `` `Ctrl-l `` clears the screen
- **tmux-resurrect** + **tmux-continuum** (cloned to
  `~/.config/tmux/plugins` by `setup/common.sh`, loaded without a plugin
  manager): sessions are saved every 15 minutes to
  `~/.local/state/tmux/resurrect` and restored when the tmux server starts;
  `` `Ctrl-s `` saves now, `` `Ctrl-r `` restores
- a clipboard tool for copy-mode: **wl-clipboard** (Wayland) or **xclip**
  (X11)

## Optional
- **kitty** — terminal emulator; config is linked to `~/.config/kitty/kitty.conf`
  and expects the **JetBrainsMono Nerd Font**; not installed by the setup
  script (see `gui-apps.manifest.csv`)
- **Ghostty** — terminal emulator; config is linked to
  `~/.config/ghostty/config.ghostty` (Gogh's `Papercolor Dark` theme, tracked
  in `themes/`; bundles its own Nerd Font symbols, so any font works); check it with
  `ghostty +validate-config`; not installed by the setup script (see
  `gui-apps.manifest.csv`)
- **Sublime Text** — settings are linked to
  `~/.config/sublime-text/Packages/User/Preferences.sublime-settings` and
  expect the **JetBrainsMono Nerd Font**; not installed by the setup
  script (see `gui-apps.manifest.csv`)
- **duf** — friendlier `df`; run it as `duf` (`df` is not aliased)

# Layout
- `home/` — mirrors `$HOME`: every file is symlinked to the same relative path
  (e.g. `home/.config/nvim/init.lua` → `~/.config/nvim/init.lua`). To add a
  config, drop it in at its home path and rerun `./link.sh`.
- `home/.shellrc.sh` — env, aliases and functions shared by bash and zsh
- `home/.inputrc` — readline (bash): case-insensitive completion, matches
  listed on the first Tab, Up/Down search history by the typed prefix
- `home/.config/ripgrep/config` — smart case and hidden files for `rg`
  typed at the prompt (via an alias; scripts and tools keep rg's defaults)
- `home/.config/bat/config` — bat's theme, style and no pager
- `home/.config/fontconfig/conf.d/60-hide-noto-scripts.conf` — hides
  Ubuntu's ~200 per-script Noto fonts from every font list (and from
  fallback: only US English is needed), keeping Noto Sans/Serif, the mono,
  math and symbol fonts, and emoji
- `run.sh` — bootstrap from GitHub: clone/update the repo, `install.sh`,
  fonts, `set-font.sh` (see setup above)
- `install.sh` — one-shot setup (deps → link → identity)
- `update.sh` — update everything: `git pull` + `link.sh`, mise and its
  `latest` tools, antidote, liquidprompt, the tmux plugins, nvim plugins
  (rewriting `lazy-lock.json`; it lists what changed, to commit) and
  treesitter parsers, fonts, tldr pages. `--no-pull`, `--no-fonts`
- `doctor.sh` — read-only health check: links, login shell and plugins,
  git identity and hook, tools (and `mise ls --missing`), default editor,
  nvim (startup errors, plugins, treesitter highlight queries), fonts (the
  ensure-fonts set and each app's font). Exits 1 if anything is broken
- `cleanup.sh` — free space from what's re-downloadable: unused mise
  versions, removed nvim plugins, Go/npm/uv/pip caches, `~/.rcfiles-backup`
  folders over 30 days old, Docker build cache and dangling images (never
  volumes or tagged images), old (disabled) snap revisions. Shows sizes and
  asks per item
- `manifest-diff.sh` — the manifests vs this machine: rows not installed
  here, and apps installed here that no row covers: GUI (Flatpak, snap,
  AppImage, GNOME extension, `~/.local/share/applications`, packages with a
  launcher added after the OS install) and CLI (packages added by hand after
  the OS install, snaps, cargo/go/npm/uv/pip --user tools, `/usr/local/bin`,
  `~/.local/bin`). Matches by package, then name, so check odd ones by hand
- `manifest-update.sh` — write the manifests from this machine: existing
  rows stay as they are, uncovered apps get a row filled in from their
  package/snap/Flatpak/extension metadata (it lists the ones that still need
  a homepage, description or category by hand). `--prune` also drops rows
  not found here; `--dry-run` writes nothing. Review with `git diff`
- `setup/manifests.py` — the detection and matching behind both
- `link.sh` — symlink the dotfiles; existing files are moved to
  `~/.rcfiles-backup/<timestamp>/`, dangling links into the repo are pruned
- `setup/ubuntu.sh`, `setup/fedora.sh` — system packages and mise for each
  distro; `setup/common.sh` — the distro-independent rest; `setup/lib.sh`
  holds their shared helpers
- `setup/git-identity.sh` — write your git name/email to `~/.gitconfig`,
  and sign commits and tags with your SSH key (`~/.ssh/id_ed25519.pub`, or
  `SIGNING_KEY`)
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
  the distro's own repos have (their `ubuntu`/`fedora` column), and the
  snaps and Flatpaks (their `install` column); list the rest
- `lint.sh` — shellcheck and shfmt the scripts and rc files (formatting:
  `shfmt -w` with the flags in `lint.sh`; `.editorconfig` matches), parse
  the app configs, check the manifests and repo hygiene (both tools come
  from mise)
- `hooks/pre-commit` — runs `lint.sh` on the staged files before each commit
- `set-font.sh` — set the font family and size in the kitty, Ghostty and
  Sublime Text configs. Run with no arguments: pick the app from
  a numbered menu, the font in fzf (every installed family; Enter or Tab to
  choose), then type the size. Scripted form: `./set-font.sh APP|all FONT
  SIZE`, with the exact family name; `--show` prints each app's current
  font

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
- Commits and tags are signed with an SSH key: the tracked git config sets
  `gpg.format = ssh`, and `setup/git-identity.sh` sets `user.signingKey`,
  turns on `commit.gpgSign`/`tag.gpgSign` in `~/.gitconfig` and adds the key
  to the untracked `~/.config/git/allowed_signers` (so `git log
  --show-signature` verifies your commits). GitHub shows them as Verified
  once the key is added there as a signing key: `gh ssh-key add
  ~/.ssh/id_ed25519.pub --type signing` (the gh token needs
  `gh auth refresh -s admin:ssh_signing_key`). `./doctor.sh` warns while
  commits aren't signed.
- The prompt is liquidprompt, configured by `~/.config/liquidpromptrc`.
- nvim plugins install automatically on first launch via lazy.nvim, at the
  commits in `lazy-lock.json`. `:Lazy update` upgrades them and rewrites the
  lockfile in this checkout (commit it); `:Lazy restore` goes back to the
  pinned versions. Coming from the old vim-plug `init.vim`, rerun
  `./link.sh` (it prunes the dangling `init.vim` link, which Neovim would
  otherwise report as a conflicting config) and delete
  `~/.local/share/nvim/plugged`, then run `:TSInstall! <lang>...` for the
  parsers it had installed: their highlight queries are symlinks into
  `plugged/` and break with it.
