#!/usr/bin/env bash
# pillbar.tmux — TPM entry point for tmux-pillbar.
#
# Loaded once by TPM (or by a manual `run-shell` on this path). It reads the
# user's @pillbar-* options, assembles the SECOND status row (status-format[1])
# and switches the status line to two rows (status 2). It deliberately touches
# NOTHING on row 0 / status-left / status-right — see README for why.
#
# THE ONE LANDMINE THIS FILE EXISTS TO AVOID:
#   The `#[align=...]` tags are written STATICALLY into the format string here.
#   They are NEVER produced by a slot's dynamic `#(...)` output. Emitting an
#   align tag from inside a `#()` return wedges tmux's layout engine at 100% CPU.
#   Slot CONTENT is dynamic; slot ALIGNMENT is static. Keep it that way.

set -u

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "${CURRENT_DIR}/scripts/helpers.sh"

left="$(get_tmux_option @pillbar-left '')"
center="$(get_tmux_option @pillbar-center '')"
right="$(get_tmux_option @pillbar-right '')"
center_align="$(get_tmux_option @pillbar-center-align centre)"
bg="$(get_tmux_option @pillbar-bg default)"

# center alignment is a closed set. Default (and the value everyone gets unless
# they opt in) is `centre`, which works on every tmux that has a second status
# row. `absolute-centre` is an opt-in for newer tmux — see README. Anything else
# is coerced back to the safe default rather than passed through to the format.
case "$center_align" in
	centre|absolute-centre) ;;
	*) center_align="centre" ;;
esac

# Remember the user's ORIGINAL `status` value exactly once, so teardown can put
# it back. The guard is on our own marker option (not on `status` itself): on a
# config reload pillbar.tmux runs again with status already at 2, and we must
# NOT record that 2 as if it were the user's original.
saved="$(tmux show-option -gqv @pillbar-saved-status)"
if [ -z "$saved" ]; then
	orig_status="$(tmux show-option -gqv status)"
	# A fresh server reports `on`; guard against an empty read just in case.
	[ -z "$orig_status" ] && orig_status="on"
	tmux set-option -g @pillbar-saved-status "$orig_status"
fi

# Assemble status-format[1]. Line background first, then each configured slot
# introduced by its STATIC align tag. An empty option means "skip this slot".
fmt="#[bg=${bg}]"
[ -n "$left" ]   && fmt="${fmt}#[align=left]${left}"
[ -n "$center" ] && fmt="${fmt}#[align=${center_align}]${center}"
[ -n "$right" ]  && fmt="${fmt}#[align=right]${right}"

tmux set-option -g 'status-format[1]' "$fmt"
tmux set-option -g status 2

# The `[ -n ... ] &&` guards above can leave $? at 1 when a slot is empty. Don't
# let that leak out as a failure — every conf reload would print a scary
# "returned 1". We did our job; exit clean.
exit 0
