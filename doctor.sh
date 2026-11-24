#!/bin/bash

# doctor.sh — check that this machine is set up the way this repo expects.
# Read-only: it changes nothing, and prints ✓ (fine), ! (worth a look) or
# ✗ (broken, with the fix) for each check:
#   links, shell and plugins, git, tools (mise), default editor, Neovim
#   (startup, plugins, treesitter highlighting), fonts.
# Exits 1 if anything is broken. Run it after run.sh/install.sh on a new
# machine, after ./update.sh, or when something looks off.
#
# Usage: ./doctor.sh

set -uo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$REPO" || exit 1

case "${1:-}" in
    "") ;;
    -h | --help)
        sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 2
        ;;
esac

# mise's tools for this non-interactive shell, as in a terminal.
export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash --shims)"
fi

fails=0 warns=0
# Colors only on a terminal.
if [ -t 1 ]; then
    green=$'\033[32m' yellow=$'\033[33m' red=$'\033[31m' reset=$'\033[0m'
else
    green="" yellow="" red="" reset=""
fi
section() { printf '\n%s\n' "$*"; }
ok() { printf '  %s✓%s %s\n' "$green" "$reset" "$*"; }
warn() {
    printf '  %s!%s %s\n' "$yellow" "$reset" "$*"
    warns=$((warns + 1))
}
bad() {
    printf '  %s✗%s %s\n' "$red" "$reset" "$*"
    fails=$((fails + 1))
}
has() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
section "Links"
out=$("$REPO/link.sh" --dry-run 2>&1)
done_line=$(grep '^Done:' <<<"$out")
# "Done: 0 linked, 31 already linked, 0 backed up, 0 pruned."
linked=1 backed=1 pruned=1
if [[ "$done_line" =~ ([0-9]+)\ linked,\ [0-9]+\ already\ linked,\ ([0-9]+)\ backed\ up,\ ([0-9]+)\ pruned ]]; then
    linked=${BASH_REMATCH[1]} backed=${BASH_REMATCH[2]} pruned=${BASH_REMATCH[3]}
fi
if [ "$linked" -eq 0 ] && [ "$backed" -eq 0 ] && [ "$pruned" -eq 0 ]; then
    ok "every dotfile is linked ($done_line)"
else
    bad "links out of date; run ./link.sh"
    grep -E '^(link|backup|prune) ' <<<"$out" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
section "Shell"
login_shell=$(getent passwd "$(id -un)" | cut -d: -f7)
case "$login_shell" in
    */zsh) ok "login shell is zsh" ;;
    *) bad "login shell is $login_shell; run: chsh -s \"\$(command -v zsh)\"" ;;
esac
for dir in "$HOME/sh/antidote" "$HOME/sh/liquidprompt" \
    "$HOME/.config/tmux/plugins/tmux-resurrect" "$HOME/.config/tmux/plugins/tmux-continuum"; do
    if [ -d "$dir" ]; then
        ok "${dir/#$HOME/\~} installed"
    else
        bad "${dir/#$HOME/\~} missing; run setup/common.sh"
    fi
done

# ---------------------------------------------------------------------------
section "Git"
if [ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ]; then
    ok "identity: $(git config --global user.name) <$(git config --global user.email)>"
else
    bad "no git identity; run setup/git-identity.sh"
fi
if [ "$(git -C "$REPO" config core.hooksPath)" = hooks ]; then
    ok "this checkout's pre-commit hook is on"
else
    bad "pre-commit hook off; run: git -C $REPO config core.hooksPath hooks"
fi

# ---------------------------------------------------------------------------
section "Tools"
missing=()
for cmd in zsh git curl unzip tmux cc mise nvim tree-sitter fzf rg fd bat delta eza \
    zoxide jq lazygit tldr shellcheck shfmt; do
    has "$cmd" || missing+=("$cmd")
done
if [ "${#missing[@]}" -eq 0 ]; then
    ok "all expected commands are on PATH"
else
    bad "not found: ${missing[*]} (install.sh installs them; mise ones: mise install)"
fi
if has mise; then
    mise_missing=$(mise ls --missing 2>/dev/null)
    if [ -z "$mise_missing" ]; then
        ok "every tool in the mise config is installed"
    else
        bad "mise tools not installed (run: mise install):"
        while IFS= read -r line; do printf '      %s\n' "$line"; done <<<"$mise_missing"
    fi
fi

# ---------------------------------------------------------------------------
section "Default editor"
if [ "${EDITOR:-}" = nvim ] || [ "${EDITOR:-}" = /usr/bin/nvim ]; then
    ok "EDITOR=$EDITOR"
else
    warn "EDITOR is '${EDITOR:-}', not nvim (open a new shell, or log in again for the desktop session)"
fi
if has update-alternatives && update-alternatives --query editor >/dev/null 2>&1; then
    system_editor=$(update-alternatives --query editor | sed -n 's/^Value: //p')
    case "$system_editor" in
        */nvim) ok "system editor: $system_editor" ;;
        *) bad "system editor is $system_editor; run: sudo update-alternatives --set editor /usr/bin/nvim" ;;
    esac
elif [ -f /etc/profile.d/zz-nvim-default-editor.sh ]; then
    ok "system editor: nvim (/etc/profile.d/zz-nvim-default-editor.sh)"
else
    warn "system default editor isn't nvim (setup/<distro>.sh sets it)"
fi

# ---------------------------------------------------------------------------
section "Neovim"
data=${XDG_DATA_HOME:-$HOME/.local/share}/nvim
if ! has nvim; then
    bad "nvim not found"
elif [ ! -d "$data/lazy/lazy.nvim" ]; then
    bad "plugins not installed yet; start nvim once (lazy.nvim installs them)"
else
    # Startup errors, plugins missing from the lockfile's list, and parsers
    # whose highlight queries don't load (e.g. links into a deleted plugin
    # directory). Each result is one line: "<key>\t<value>".
    report=$(timeout 60 nvim --headless -i NONE +'lua vim.defer_fn(function()
        local out = {}
        table.insert(out, "errmsg\t" .. vim.v.errmsg)
        local lock = vim.fn.stdpath("config") .. "/lazy-lock.json"
        local ok, plugins = pcall(vim.json.decode, table.concat(vim.fn.readfile(lock), "\n"))
        local missing = {}
        if ok then
            for name in pairs(plugins) do
                if vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/" .. name) == 0 then
                    table.insert(missing, name)
                end
            end
        end
        table.insert(out, "missing\t" .. table.concat(missing, " "))
        local langs, bad = {}, {}
        for _, f in ipairs(vim.api.nvim_get_runtime_file("parser/*.so", true)) do
            local lang = vim.fn.fnamemodify(f, ":t:r")
            if not langs[lang] then
                langs[lang] = true
                local qok, q = pcall(vim.treesitter.query.get, lang, "highlights")
                if not (qok and q) then table.insert(bad, lang) end
            end
        end
        table.insert(out, "parsers\t" .. vim.tbl_count(langs))
        table.insert(out, "nohighlight\t" .. table.concat(bad, " "))
        io.stdout:write(table.concat(out, "\n"), "\n")
        vim.cmd("qa!")
    end, 1500)' </dev/null 2>/dev/null)
    field() { awk -F'\t' -v k="$1" '$1 == k { print $2 }' <<<"$report"; }
    if [ -z "$report" ]; then
        bad "nvim didn't start (try: nvim --headless +qa)"
    else
        errmsg=$(field errmsg)
        if [ -z "$errmsg" ]; then ok "starts without errors"; else bad "startup error: $errmsg"; fi
        plugin_missing=$(field missing)
        if [ -z "$plugin_missing" ]; then
            ok "every plugin in lazy-lock.json is installed"
        else
            bad "plugins not installed: $plugin_missing (run nvim, then :Lazy restore)"
        fi
        nohl=$(field nohighlight)
        if [ -z "$nohl" ]; then
            ok "all $(field parsers) treesitter parsers have highlight queries"
        else
            bad "no highlighting for: $nohl (in nvim: :TSInstall! $nohl)"
        fi
    fi
    broken=$(find "$data/site/queries" -maxdepth 1 -xtype l -printf '%f ' 2>/dev/null)
    broken=${broken% }
    if [ -z "$broken" ]; then
        ok "no broken treesitter query links"
    else
        bad "broken query links: $broken (in nvim: :TSInstall! $broken)"
    fi
fi

# ---------------------------------------------------------------------------
section "Fonts"
if ! has fc-list; then
    bad "fc-list not found (install fontconfig)"
else
    families=$(fc-list --format '%{family[0]}\n' | sort -u)
    installed() { grep -Fx -- "$1" >/dev/null <<<"$families"; }
    # The families setup/ensure-fonts.sh installs ("Name=Family" lines).
    missing=()
    count=0
    while IFS= read -r family; do
        count=$((count + 1))
        installed "$family" || missing+=("$family")
    done < <(sed -n 's/^ *"[A-Za-z]*=\(.*\)"$/\1/p' "$REPO/setup/ensure-fonts.sh")
    if [ "${#missing[@]}" -eq 0 ]; then
        ok "all $count fonts from setup/ensure-fonts.sh are installed"
    else
        bad "not installed: ${missing[*]}; run setup/ensure-fonts.sh"
    fi
    # The font each app is set to (a missing one falls back silently).
    while IFS=$'\t' read -r app family size; do
        if installed "$family"; then
            ok "$app: $family $size"
        elif [ "$app" = ghostty ] && [ "$family" = "JetBrains Mono" ]; then
            ok "$app: $family $size (bundled with Ghostty)"
        else
            warn "$app is set to '$family', which isn't installed (it falls back to a default); fix with ./set-font.sh"
        fi
    done < <("$REPO/set-font.sh" --show)
fi

# ---------------------------------------------------------------------------
echo
if [ "$fails" -gt 0 ]; then
    printf '%s%d broken%s, %d to look at.\n' "$red" "$fails" "$reset" "$warns"
    exit 1
fi
if [ "$warns" -gt 0 ]; then
    printf 'Nothing broken; %d to look at.\n' "$warns"
else
    echo "All good."
fi
