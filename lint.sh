#!/bin/bash

# lint.sh — check the scripts and configs in this checkout:
#   - shellcheck the scripts and rc files, bash -n / zsh -n the rc files
#   - parse the git, TOML, Sublime, tmux, Ghostty, kitty and nvim configs
#   - check the manifests' columns
#   - repo hygiene: script modes, no symlinks or per-machine files under
#     home/, no hosts in the ssh config, no keys or tokens anywhere
# hooks/pre-commit runs it on the staged files before every commit. A check
# whose tool isn't installed is skipped, except shellcheck (mise installs it).
#
# Usage: ./lint.sh

set -euo pipefail

cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"

status=0
fail() { echo "    FAIL: $*" >&2; status=1; }
skip() { echo "    skip: $*"; }
has()  { command -v "$1" >/dev/null 2>&1; }

echo "==> shellcheck"
if has shellcheck; then
    shellcheck -x ./*.sh setup/*.sh hooks/* gogh || status=1
    # The rc files source things that only exist at runtime (SC1090/1091).
    shellcheck -s bash -e SC1090,SC1091 home/.shellrc.sh home/.bashrc home/.profile || status=1
else
    fail "shellcheck not found (mise install)"
fi

echo "==> bash -n, zsh -n"
for f in home/.bashrc home/.profile home/.shellrc.sh; do
    bash -n "$f" || status=1
done
if has zsh; then
    # .shellrc.sh is sourced by zsh too.
    for f in home/.zshrc home/.zprofile home/.shellrc.sh; do
        zsh -n "$f" || status=1
    done
else
    skip "zsh not installed"
fi

echo "==> git config"
git config -f home/.config/git/config --list >/dev/null || status=1

echo "==> TOML, Sublime settings, manifests"
if has python3; then
    python3 -I - <<'EOF' || status=1
import csv, json, re, sys

ok = True
def fail(msg):
    global ok
    print(f"    FAIL: {msg}", file=sys.stderr)
    ok = False

try:
    import tomllib
except ImportError:   # Python < 3.11
    print("    skip: TOML (needs Python 3.11+)")
else:
    for path in ["home/.config/mise/config.toml",
                 "home/.config/alacritty/alacritty.toml",
                 "home/.config/alacritty/gogh.toml"]:
        try:
            with open(path, "rb") as f:
                tomllib.load(f)
        except (OSError, tomllib.TOMLDecodeError) as e:
            fail(f"{path}: {e}")

# Sublime allows // comments and trailing commas; this file uses only
# whole-line comments.
path = "home/.config/sublime-text/Packages/User/Preferences.sublime-settings"
try:
    with open(path, encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r"(?m)^\s*//.*$", "", text)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    json.loads(text)
except (OSError, ValueError) as e:
    fail(f"{path}: {e}")

# extra-install.sh reads name and the distro columns.
for path, columns in [
    ("cli-apps.manifest.csv",
     ["category", "name", "homepage", "description", "install", "ubuntu", "fedora"]),
    ("gui-apps.manifest.csv",
     ["category", "name", "homepage", "description", "ubuntu", "fedora"]),
]:
    try:
        with open(path, newline="", encoding="utf-8") as f:
            rows = list(csv.reader(f))
    except (OSError, csv.Error) as e:
        fail(f"{path}: {e}")
        continue
    if not rows or rows[0] != columns:
        fail(f"{path}: header should be {','.join(columns)}")
        continue
    names = set()
    for n, row in enumerate(rows[1:], start=2):
        if len(row) != len(columns):
            fail(f"{path}:{n}: {len(row)} fields, expected {len(columns)}")
            continue
        rec = dict(zip(columns, row))
        if not rec["name"].strip():
            fail(f"{path}:{n}: empty name")
        elif rec["name"] in names:
            fail(f"{path}:{n}: duplicate name {rec['name']!r}")
        names.add(rec["name"])
        if not rec["homepage"].startswith(("http://", "https://")):
            fail(f"{path}:{n}: homepage isn't a URL")

sys.exit(0 if ok else 1)
EOF
else
    skip "python3 not installed"
fi

echo "==> app configs"
if has tmux; then
    # Parse only (-n); a throwaway server that exits right after.
    tmux -L "lint-$$" -f /dev/null start-server \; source-file -n home/.tmux.conf </dev/null || status=1
else
    skip "tmux not installed"
fi
if has ghostty; then
    # Themes are looked up in this checkout's themes/, so one that's only
    # installed locally (and missing on a fresh machine) fails here. Output
    # goes through a pipe: the snap's ghostty truncates a file on stdout,
    # wiping what was logged before it.
    if ! out=$(XDG_CONFIG_HOME="$PWD/home/.config" \
        ghostty +validate-config --config-file="$PWD/home/.config/ghostty/config.ghostty" 2>&1 </dev/null); then
        echo "$out" >&2
        fail "home/.config/ghostty/config.ghostty"
    fi
else
    skip "ghostty not installed"
fi
if has kitty; then
    # kitty only logs bad lines (and raises on bad values), so any output fails.
    out=$(kitty +runpy 'import sys; from kitty.config import load_config; load_config(sys.argv[-1])' \
        "$PWD/home/.config/kitty/kitty.conf" </dev/null 2>&1) || true
    if [ -n "$out" ]; then
        echo "$out" >&2
        fail "home/.config/kitty/kitty.conf"
    fi
else
    skip "kitty not installed"
fi
if has nvim; then
    nvim_init=home/.config/nvim/init.lua
    # Parse init.lua and the lockfile, without running anything.
    out=$(nvim --clean --headless -i NONE -l /dev/stdin "$nvim_init" home/.config/nvim/lazy-lock.json 2>&1 <<'EOF'
local _, err = loadfile(arg[1])
if err then io.stderr:write(err, "\n") os.exit(1) end
local ok, lock = pcall(vim.json.decode, table.concat(vim.fn.readfile(arg[2]), "\n"))
if not ok then io.stderr:write(arg[2], ": ", lock, "\n") os.exit(1) end
EOF
    ) || { echo "$out" >&2; fail "nvim config doesn't parse"; }
    # Startup, only once lazy.nvim is installed: before that, loading init.lua
    # would download it and every plugin.
    if [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim" ]; then
        out=$(timeout 30 nvim --headless -i NONE -u "$PWD/$nvim_init" \
            +'lua vim.defer_fn(function() if vim.v.errmsg ~= "" then io.stdout:write(vim.v.errmsg, "\n") end vim.cmd("qa!") end, 200)' \
            </dev/null 2>&1) || true
        if [ -n "$out" ]; then
            echo "$out" >&2
            fail "$nvim_init: errors on startup"
        fi
    else
        skip "nvim startup (lazy.nvim not installed)"
    fi
else
    skip "nvim not installed"
fi

echo "==> repo hygiene"
for f in ./*.sh setup/*.sh hooks/* gogh; do
    case "$f" in setup/lib.sh) continue ;; esac   # sourced, not run
    [ -x "$f" ] || fail "$f isn't executable (chmod +x, or git update-index --chmod=+x)"
done
# link.sh only links regular files.
while IFS= read -r f; do
    fail "$f is a symlink; link.sh would skip it"
done < <(find home -type l)
# Per-machine files stay untracked (README: Notes).
while IFS= read -r f; do
    fail "$f is per-machine and shouldn't be committed"
done < <(find home \( -path home/.gitconfig -o -name .gitconfig.local -o -name '*.machine' \
    -o -path home/.ssh/config.local -o -path 'home/.ssh/id_*' \) -print)
# This repo is public: real ssh hosts go in ~/.ssh/config.local.
if grep -nE '^[[:space:]]*(HostName|User|IdentityFile|ProxyJump)[[:space:]]|^[[:space:]]*Host[[:space:]]+[^*[:space:]]' \
    home/.ssh/config >&2; then
    fail "home/.ssh/config names a host; put it in ~/.ssh/config.local"
fi
# Keys and tokens. Only file:line is printed, not the secret.
secrets=$(grep -rInoE --exclude-dir=.git \
    -e '-----BEGIN ([A-Z]+ )*PRIVATE KEY-----' \
    -e 'gh[pousr]_[A-Za-z0-9]{36}' -e 'github_pat_[A-Za-z0-9_]{40,}' \
    -e 'sk-[A-Za-z0-9_-]{32,}' \
    -e 'AKIA[0-9A-Z]{16}' -e 'AIza[0-9A-Za-z_-]{35}' \
    -e 'xox[abposr]-[A-Za-z0-9-]{10,}' \
    -e '_authToken[[:space:]]*=' \
    . | cut -d: -f1,2) || true
if [ -n "$secrets" ]; then
    echo "$secrets" >&2
    fail "what looks like a private key or token (above)"
fi

if [ "$status" -eq 0 ]; then
    echo "All checks passed."
fi
exit "$status"
