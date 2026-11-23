# ~/.profile: executed by the command interpreter for login shells.
# Symlinked to ~/.profile by link.sh (Ubuntu's default plus mise shims).
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# mise shims: put the mise tools (nvim, node, delta, ...) on PATH for the
# desktop session and other non-interactive logins. `mise activate` in the
# rc files takes over from these in terminals. The bash flavour prints a
# plain POSIX export, safe for sh/dash, which may source this file.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash --shims)"
fi

# if running bash, include .bashrc last, so the PATH above is already in
# place for its `command -v` checks and its `mise activate` runs after the
# shims (activate must come after them to take precedence).
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi
