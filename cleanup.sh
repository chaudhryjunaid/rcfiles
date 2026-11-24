#!/bin/bash

# cleanup.sh — free disk space from things that are safe to delete: they're
# re-downloaded or rebuilt when needed. For each item it shows the size and
# asks before deleting (--yes deletes without asking; --dry-run only lists):
#   - mise tool versions no config uses any more (mise prune)
#   - nvim plugins no longer in the config (lazy.nvim clean)
#   - Go build and module caches, the npm, uv and pip caches
#   - ~/.rcfiles-backup folders older than 30 days (left by link.sh)
#   - Docker's build cache and dangling (untagged) images. Volumes, and
#     tagged images, are never touched: they can hold data.
#
# Usage: ./cleanup.sh [--dry-run | --yes]

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=setup/lib.sh
. "$REPO/setup/lib.sh"

MODE=ask
for arg in "$@"; do
    case "$arg" in
        -n | --dry-run) MODE=dry ;;
        -y | --yes) MODE=yes ;;
        -h | --help)
            sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done
if [ "$MODE" = ask ] && ! [ -t 0 ]; then
    warn "not a terminal, so nothing will be deleted (use --yes to delete without asking)"
    MODE=dry
fi

export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash --shims)"
fi
has() { command -v "$1" >/dev/null 2>&1; }

# size <path...>: total disk usage, human-readable ("0" if none exist).
size() {
    local existing=() p
    for p in "$@"; do [ -e "$p" ] && existing+=("$p"); done
    [ "${#existing[@]}" -gt 0 ] || {
        echo 0
        return
    }
    du -sch "${existing[@]}" 2>/dev/null | tail -n1 | cut -f1
}

cleaned=0
# offer <description> <size> <command...>: show it, and run the command if
# the answer is yes.
offer() {
    local what=$1 amount=$2 reply
    shift 2
    case "$amount" in 0 | 0B | "") return 0 ;; esac
    printf '  %-58s %8s\n' "$what" "$amount"
    case "$MODE" in
        dry) return 0 ;;
        ask)
            read -rp "    Delete? [y/N] " reply || reply=""
            case "$reply" in [yY] | [yY][eE][sS]) ;; *) return 0 ;; esac
            ;;
    esac
    if "$@"; then
        info "deleted"
        cleaned=$((cleaned + 1))
    else
        warn "couldn't delete $what"
    fi
}

log "mise"
if has mise; then
    # "mise node@26.11.1 is prunable: ..." for each unused version.
    mapfile -t prunable < <(mise prune --dry-run 2>&1 | sed -n 's/^mise \([^ ]*@[^ ]*\) is prunable.*/\1/p')
    if [ "${#prunable[@]}" -gt 0 ]; then
        dirs=()
        for tv in "${prunable[@]}"; do
            dirs+=("$HOME/.local/share/mise/installs/${tv%%@*}/${tv#*@}" "$HOME/.cache/mise/${tv%%@*}/${tv#*@}")
        done
        offer "unused tool versions: ${prunable[*]}" "$(size "${dirs[@]}")" mise prune --yes
    fi
fi

log "nvim"
lazy_dir=${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy
lock="$REPO/home/.config/nvim/lazy-lock.json"
if [ -d "$lazy_dir" ] && [ -f "$lock" ] && has nvim; then
    stale=()
    for dir in "$lazy_dir"/*/; do
        name=$(basename "$dir")
        grep -q "\"$name\":" "$lock" || stale+=("$dir")
    done
    if [ "${#stale[@]}" -gt 0 ]; then
        offer "plugins not in the config: $(printf '%s ' "${stale[@]##*/lazy/}")" \
            "$(size "${stale[@]}")" nvim --headless "+Lazy! clean" +qa
    fi
fi

log "Caches"
if has go; then
    offer "Go build cache ($(go env GOCACHE))" "$(size "$(go env GOCACHE)")" go clean -cache
    # go clean, since the module cache's files are read-only.
    offer "Go module cache ($(go env GOMODCACHE))" "$(size "$(go env GOMODCACHE)")" go clean -modcache
fi
has npm && offer "npm cache (~/.npm/_cacache)" "$(size "$HOME/.npm/_cacache")" npm cache clean --force
has uv && offer "uv cache ($(uv cache dir 2>/dev/null))" "$(size "$(uv cache dir 2>/dev/null)")" uv cache clean
offer "pip cache (~/.cache/pip)" "$(size "$HOME/.cache/pip")" rm -rf -- "$HOME/.cache/pip"

log "Old link.sh backups"
if [ -d "$HOME/.rcfiles-backup" ]; then
    mapfile -t old < <(find "$HOME/.rcfiles-backup" -mindepth 1 -maxdepth 1 -type d -mtime +30 | sort)
    if [ "${#old[@]}" -gt 0 ]; then
        offer "${#old[@]} backup folder(s) older than 30 days in ~/.rcfiles-backup" \
            "$(size "${old[@]}")" rm -rf -- "${old[@]}"
    fi
fi

log "Docker"
if has docker && docker info >/dev/null 2>&1; then
    dangling=$(docker images --filter dangling=true --quiet | wc -l)
    if [ "$dangling" -gt 0 ]; then
        offer "$dangling dangling (untagged) image(s)" "$dangling image(s)" docker image prune --force
    fi
    build=$(docker system df --format '{{.Type}}\t{{.Reclaimable}}' | awk -F'\t' '$1 == "Build Cache" { print $2 }')
    offer "build cache (rebuilt on the next docker build)" "${build:-0}" docker builder prune --force
else
    info "docker not available"
fi

echo
case "$MODE" in
    dry) log "Dry run: nothing was deleted." ;;
    *) log "Cleaned $cleaned item(s)." ;;
esac
