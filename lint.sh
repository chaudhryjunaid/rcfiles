#!/bin/bash

# lint.sh — shellcheck the scripts and syntax-check the shell rc files.

set -euo pipefail

cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"

status=0

echo "==> shellcheck"
shellcheck -x ./*.sh setup/*.sh || status=1

# rc files source things that only exist at runtime; just check syntax.
echo "==> bash -n"
for f in home/*/.bashrc home/common/.shellrc.sh; do
    bash -n "$f" || status=1
done

if command -v zsh >/dev/null 2>&1; then
    echo "==> zsh -n"
    for f in home/*/.zshrc home/*/.zprofile home/common/.zshrc.common; do
        zsh -n "$f" || status=1
    done
fi

[ "$status" -eq 0 ] && echo "All checks passed."
exit "$status"
