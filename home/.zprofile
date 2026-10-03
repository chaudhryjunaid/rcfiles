# Login-shell setup for zsh on Linux. Symlinked to ~/.zprofile by link.sh.
# zsh login shells don't read ~/.profile, and GNOME on Wayland starts the
# session through the login shell, so this is what desktop apps inherit.

# mise shims: put the mise tools (nvim, node, delta, ...) on PATH for apps not
# started from an interactive shell. ~/.zshrc's `mise activate` takes over
# from these in terminals.
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh --shims)"
