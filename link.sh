#!/bin/bash

# link.sh — symlink the dotfiles into $HOME.
#
# home/common/ and home/<platform>/ mirror the layout of $HOME: every file in
# them is linked to the same relative path under $HOME, e.g.
#   home/common/.config/nvim/init.vim -> ~/.config/nvim/init.vim
# A platform file wins over a common file with the same path. Existing files
# are moved to ~/.rcfiles-backup/<timestamp>/ first. Safe to re-run.
#
# Usage: ./link.sh [--dry-run] [--unlink]

set -euo pipefail

REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BACKUP_DIR="$HOME/.rcfiles-backup/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
UNLINK=0
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        -u|--unlink)  UNLINK=1 ;;
        -h|--help)    sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)            echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

case "$(uname -s)" in
    Linux)  PLATFORM="linux" ;;
    Darwin) PLATFORM="macos" ;;
    *)      echo "Unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac

# run <cmd...>: execute, or just print under --dry-run.
run() {
    if [ "$DRY_RUN" -eq 1 ]; then echo "    would: $*"; else "$@"; fi
}

# List "<relative path>\t<source>" for every file to link. Platform files come
# first; a common file is skipped when the platform has the same path.
# (Plain arrays and POSIX find only: macOS ships bash 3.2 and BSD find.)
list_sources() {
    local pkg dir file rel
    for pkg in "$PLATFORM" common; do
        dir="$REPO/home/$pkg"
        [ -d "$dir" ] || continue
        while IFS= read -r -d '' file; do
            rel="${file#"$dir"/}"
            if [ "$pkg" = common ] && [ -f "$REPO/home/$PLATFORM/$rel" ]; then
                continue
            fi
            printf '%s\t%s\n' "$rel" "$file"
        done < <(find "$dir" -type f -print0)
    done | sort
}

linked=0 skipped=0 backed_up=0 removed=0
while IFS=$'\t' read -r rel src; do
    target="$HOME/$rel"

    if [ "$UNLINK" -eq 1 ]; then
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
            echo "unlink $target"
            run rm "$target"
            removed=$((removed + 1))
        fi
        continue
    fi

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    # Back up anything in the way, except stale links into this repo.
    if [ -e "$target" ] || [ -L "$target" ]; then
        case "$(readlink "$target" 2>/dev/null || true)" in
            "$REPO"/*) ;;
            *)
                echo "backup $target -> $BACKUP_DIR/$rel"
                run mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
                run mv "$target" "$BACKUP_DIR/$rel"
                backed_up=$((backed_up + 1))
                ;;
        esac
    fi

    echo "link   $target -> $src"
    run mkdir -p "$(dirname "$target")"
    run ln -sfn "$src" "$target"
    linked=$((linked + 1))
done < <(list_sources)

# Remove dangling links into this repo (files that were renamed or deleted).
while IFS= read -r -d '' link; do
    [ -e "$link" ] && continue
    case "$(readlink "$link")" in
        "$REPO"/*)
            echo "prune  $link (dangling)"
            run rm "$link"
            removed=$((removed + 1))
            ;;
    esac
done < <(find "$HOME" -maxdepth 1 -type l -print0
         if [ -d "$HOME/.config" ]; then find "$HOME/.config" -maxdepth 2 -type l -print0; fi)

if [ "$UNLINK" -eq 1 ]; then
    echo "Done: $removed removed."
    exit 0
fi

# Directories .vimrc expects.
run mkdir -p "$HOME/.vim/backups" "$HOME/.vim/swaps" "$HOME/.vim/undo"

# Untracked per-machine git identity (included by ~/.gitconfig); see
# setup/git-identity.sh.
GITLOCAL="$HOME/.gitconfig.local"
if [ ! -f "$GITLOCAL" ]; then
    echo "create $GITLOCAL (placeholder identity)"
    if [ "$DRY_RUN" -eq 0 ]; then
        cat > "$GITLOCAL" <<'EOF'
[user]
	name = Your Name
	email = your.email@example.com
EOF
    fi
fi

echo "Done ($PLATFORM): $linked linked, $skipped already linked, $backed_up backed up, $removed pruned."
[ "$DRY_RUN" -eq 1 ] && echo "(dry run: nothing was changed)"
exit 0
