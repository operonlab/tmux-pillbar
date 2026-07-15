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

# evaluate_threshold_health <value> <warn> <crit> [invert]
# Map a numeric reading to a health token so a provider expresses SEMANTICS, not
# a hardcoded colour. Echoes exactly one of: ok | warning | error.
#   default (invert unset/0): higher is worse — value>=crit → error,
#                             value>=warn → warning, else ok.
#   invert set (non-empty, not 0): lower is worse — value<=crit → error,
#                             value<=warn → warning, else ok.
# A non-numeric <value> yields `error`, never a silent `ok`: a broken provider
# must show red, not a false all-clear. Integers and decimals are accepted.
evaluate_threshold_health() {
	awk -v v="$1" -v w="$2" -v c="$3" -v inv="${4:-0}" 'BEGIN{
		if (v !~ /^-?[0-9]+(\.[0-9]+)?$/) { printf "error"; exit }
		if (inv != "" && inv != "0") {
			if (v <= c) printf "error"; else if (v <= w) printf "warning"; else printf "ok";
		} else {
			if (v >= c) printf "error"; else if (v >= w) printf "warning"; else printf "ok";
		}
	}'
}

# resolve_health_style <health-token>
# Map a health token (ok|warning|error) to a `fg bg` colour pair by reading the
# matching @pillbar-health-<token>-style option. Defaults to `default default`
# (the terminal's own colours — i.e. NO colour) so pillbar stays a palette-free
# framework: you opt INTO colour by setting these options, e.g.
#     set -g @pillbar-health-error-style 'colour231 colour160'
resolve_health_style() {
	get_tmux_option "@pillbar-health-$1-style" "default default"
}
