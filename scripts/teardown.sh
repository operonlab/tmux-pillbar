#!/usr/bin/env bash
# teardown.sh — undo tmux-pillbar cleanly. Clears the second status row we added
# and restores the `status` value we saved when the plugin first loaded. Your
# own @pillbar-* lines in tmux.conf are left alone (remove them by hand if you
# want the plugin to stop re-applying on the next reload).
#
# Run from an attached client: bash scripts/teardown.sh

set -u

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "${CURRENT_DIR}/helpers.sh"

# What was `status` before pillbar touched it? Fall back to tmux's default `on`
# if we somehow never recorded it.
saved="$(tmux show-option -gqv @pillbar-saved-status)"
[ -z "$saved" ] && saved="on"

# Clear OUR second-row format. NOTE: `-u` on an array index leaves the element
# EMPTY, not the tmux compiled default — tmux never restores the built-in value
# for an indexed option once it has been set. Harmless here: status drops back to
# one row so status-format[1] is no longer rendered. Caveat: we only ever saved
# the `status` height, not the original status-format[1] content, so a user who
# had hand-customised a multi-row format before installing pillbar gets an empty
# row back on teardown rather than their prior custom value.
tmux set-option -gu 'status-format[1]' 2>/dev/null

# Put the status height back the way we found it.
tmux set-option -g status "$saved"

# Forget our marker so a later `pillbar.tmux` run re-saves a fresh original.
tmux set-option -gu @pillbar-saved-status 2>/dev/null

printf '%s\n' "pillbar: second row removed, status restored to '${saved}'."
