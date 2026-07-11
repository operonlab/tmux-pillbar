#!/usr/bin/env bash
# helpers.sh — shared shell helpers for tmux-pillbar.
#
# This file is meant to be SOURCED, not executed. It intentionally does NOT use
# `set -e` / `set -o pipefail`: it is pulled into scripts that tmux runs from a
# status format (`#(...)`) or from `run-shell`, where any non-zero exit is
# treated by tmux as an error. Helpers here fail soft and print a default.

# get_tmux_option <option-name> <default-value>
# Read a global tmux user option, falling back to a default when unset/empty.
get_tmux_option() {
	option_name="$1"
	default_value="$2"
	option_value="$(tmux show-option -gqv "$option_name" 2>/dev/null)"
	if [ -z "$option_value" ]; then
		printf '%s' "$default_value"
	else
		printf '%s' "$option_value"
	fi
}

# pillbar_cache_dir
# Print a safe, per-user, plugin-namespaced cache directory, creating it 0700
# if needed. Refuses a pre-planted symlink at that path (a classic /tmp attack).
# Prints nothing and returns non-zero on any failure — callers must handle that
# and fall back to printing an empty widget (never block, never crash tmux).
pillbar_cache_dir() {
	dir="${TMUX_TMPDIR:-/tmp}/pillbar-$(id -u)"
	# Reject a symlink sitting where our dir should be (do not follow it).
	[ -L "$dir" ] && return 1
	if [ ! -d "$dir" ]; then
		mkdir -m 700 "$dir" 2>/dev/null || return 1
	fi
	# Re-check after creation: must be a real directory, still not a symlink.
	[ -d "$dir" ] && [ ! -L "$dir" ] || return 1
	printf '%s' "$dir"
}
