#!/usr/bin/env bash
# pill.sh — render "capsules" for a tmux-pillbar slot.
#
# Reads pipe-delimited lines from stdin, one capsule per line:
#
#     icon|label|value|fg|bg
#
# and writes a single tmux-format string of styled capsules to stdout. Empty
# fields are dropped from the capsule text; a fully blank line is skipped. fg/bg
# default to `default` (the terminal's own colours) when omitted — this is a
# framework, it does not ship a palette, you bring your own colours.
#
# HARD RULE: pill.sh output NEVER contains an `#[align=...]` tag. Alignment is
# owned by pillbar.tmux and written statically into the format. An align tag
# escaping into a slot's dynamic output wedges tmux at 100% CPU. This helper is
# the "content" half of that contract and stays strictly on its side of it.
#
# Usage inside a slot command (see examples/family.conf):
#     printf '%s\n' 'CPU||42%|colour15|colour24' | pill.sh
#
# Optional overrides (handy for tests / when tmux is not reachable from `#()`):
#     pill.sh <style> <line-bg>
#   <style>   = nerd | ascii | none   (default: @pillbar-pill-style, else ascii)
#   <line-bg> = colour for the gaps around nerd end-caps (default: @pillbar-bg)
#
# No `set -e`: this runs inside `#(...)`; a non-zero exit is an error to tmux.
# On any trouble it prints what it has (possibly nothing) and exits 0.

set -u

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "${CURRENT_DIR}/helpers.sh" 2>/dev/null || true

# --- resolve style: arg1 override > @pillbar-pill-style option > ascii --------
style="${1:-}"
case "$style" in
	nerd|ascii|none) ;;
	*)
		if command -v get_tmux_option >/dev/null 2>&1; then
			style="$(get_tmux_option @pillbar-pill-style ascii)"
		else
			style="ascii"
		fi
		case "$style" in nerd|ascii|none) ;; *) style="ascii" ;; esac
		;;
esac

# --- resolve the line background (only used by nerd end-caps) ------------------
line_bg="${2:-}"
if [ -z "$line_bg" ]; then
	if command -v get_tmux_option >/dev/null 2>&1; then
		line_bg="$(get_tmux_option @pillbar-bg default)"
	else
		line_bg="default"
	fi
fi

# Nerd Font half-circle end-caps, written as OCTAL UTF-8 byte escapes so that no
# PUA glyphs ever live in this file (editors silently drop them) and so it works
# on bash 3.2, which does not understand the \u escape. E0B6 = left half-circle
# (bytes EE 82 B6), E0B4 = right half-circle (bytes EE 82 B4).
NERD_L=$'\356\202\266'
NERD_R=$'\356\202\264'

out=""
while IFS='|' read -r icon label value fg bg; do
	# Skip a line with no visible content at all.
	[ -z "${icon}${label}${value}" ] && continue
	fg="${fg:-default}"
	bg="${bg:-default}"

	# Join the non-empty fields with single spaces. Values are emitted verbatim:
	# tmux does NOT re-expand the OUTPUT of a `#(...)`, so a literal `%` (e.g.
	# `42%`) passes straight through and renders correctly. (Do not double it —
	# `%` is only special in the `#()` COMMAND string, never in its output.)
	inner=""
	[ -n "$icon" ]  && inner="$icon"
	[ -n "$label" ] && inner="${inner:+$inner }$label"
	[ -n "$value" ] && inner="${inner:+$inner }$value"

	case "$style" in
		nerd)
			# Cap glyph coloured as the capsule bg, sitting on the line bg, so
			# the rounded ends blend into the row. Body carries the real colours.
			out="${out}#[fg=${bg},bg=${line_bg}]${NERD_L}#[fg=${fg},bg=${bg}] ${inner} #[fg=${bg},bg=${line_bg}]${NERD_R}#[default]"
			;;
		ascii)
			out="${out}#[fg=${fg},bg=${bg}][ ${inner} ]#[default]"
			;;
		none)
			out="${out}#[fg=${fg},bg=${bg}]${inner}#[default] "
			;;
	esac
done

printf '%s' "$out"
exit 0
