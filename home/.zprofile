# Login-shell setup for zsh on Linux. Symlinked to ~/.zprofile by link.sh.
# zsh login shells don't read ~/.profile, and GNOME on Wayland starts the
# session through the login shell, so this is what desktop apps inherit.

# The user's private bins, as ~/.profile adds them (~/.local/bin first).
# mise itself lives in ~/.local/bin on Ubuntu (its installer), so this has
# to come before the check below.
[ -d "$HOME/bin" ] && path=("$HOME/bin" $path)
[ -d "$HOME/.local/bin" ] && path=("$HOME/.local/bin" $path)

# mise shims: put the mise tools (nvim, node, delta, ...) on PATH for apps not
# started from an interactive shell. ~/.zshrc's `mise activate` takes over
# from these in terminals.
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh --shims)"
