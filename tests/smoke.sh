#!/usr/bin/env bash
# smoke.sh — headless structural test for tmux-pillbar on an ISOLATED socket.
#
# Never touches the default tmux server: every command runs under `tmux -L`
# with a private socket that is killed on exit. What CAN be verified headlessly
# is the STRUCTURE of the assembled second row (static align tags present,
# #() content present, status switched to 2, save/restore round-trip). What
# CANNOT be verified without an attached client is the pixel rendering /
# alignment on screen — those are reported as SKIP for a human to eyeball.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENTRY="${REPO_DIR}/pillbar.tmux"
TEARDOWN="${REPO_DIR}/scripts/teardown.sh"
PILL="${REPO_DIR}/scripts/pill.sh"

SOCKETS=""
FAILS=0

cleanup() {
	for s in $SOCKETS; do
		tmux -L "$s" kill-server 2>/dev/null || true
		rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$s" 2>/dev/null || true
	done
}
trap cleanup EXIT INT TERM

# new_sock <letter> — allocate a socket name into $SOCK and register it for
# cleanup. Must be called plainly, never as `$(new_sock …)`: command
# substitution runs the body in a subshell, the SOCKETS registration dies
# there, and cleanup silently becomes a no-op that leaks every test server.
new_sock() {
	SOCK="pillbartest$$_$1"
	SOCKETS="$SOCKETS $SOCK"
}

check() {
	# check <label> <expected> <actual>
	if [ "$2" = "$3" ]; then
		echo "  PASS: $1 (= $3)"
	else
		echo "  FAIL: $1 — expected [$2] got [$3]"
		FAILS=$((FAILS + 1))
	fi
}

contains() {
	# contains <label> <haystack> <needle>
	case "$2" in
		*"$3"*) echo "  PASS: $1 (found '$3')" ;;
		*) echo "  FAIL: $1 — '$3' not in [$2]"; FAILS=$((FAILS + 1)) ;;
	esac
}

not_contains() {
	# not_contains <label> <haystack> <needle>
	case "$2" in
		*"$3"*) echo "  FAIL: $1 — '$3' unexpectedly in [$2]"; FAILS=$((FAILS + 1)) ;;
		*) echo "  PASS: $1 (no '$3')" ;;
	esac
}

echo "tmux version: $(tmux -V)"

# ── parse checks ─────────────────────────────────────────────────────────────
echo "── Parse: every script is valid shell"
for f in "$ENTRY" "$TEARDOWN" "$PILL" "${REPO_DIR}/scripts/helpers.sh" "${REPO_DIR}/examples/nowplaying-demo.sh"; do
	if bash -n "$f" 2>/dev/null; then
		echo "  PASS: bash -n $(basename "$f")"
	else
		echo "  FAIL: bash -n $(basename "$f")"; FAILS=$((FAILS + 1))
	fi
done

# ══ Scenario A: full three-slot assembly ═════════════════════════════════════
echo "── Scenario A: three configured slots → static align tags + #() content, status 2"
new_sock A; A=$SOCK
tmux -L "$A" -f /dev/null new-session -d -s main -x 200 -y 50
orig_status=$(tmux -L "$A" show-option -gqv status)
tmux -L "$A" set-option -g @pillbar-left  '#(echo L)'
tmux -L "$A" set-option -g @pillbar-center '#(echo C)'
tmux -L "$A" set-option -g @pillbar-right  '#(echo R)'
tmux -L "$A" run-shell "'${ENTRY}'"
fmt=$(tmux -L "$A" show-option -gqv 'status-format[1]')
echo "  format[1] = ${fmt}"
contains "left align tag is static" "$fmt" "#[align=left]"
contains "center align tag is static (default centre)" "$fmt" "#[align=centre]"
contains "right align tag is static" "$fmt" "#[align=right]"
contains "left content wrapped in #()" "$fmt" "#(echo L)"
contains "center content wrapped in #()" "$fmt" "#(echo C)"
contains "right content wrapped in #()" "$fmt" "#(echo R)"
check "status switched to two rows" "2" "$(tmux -L "$A" show-option -gqv status)"
check "original status recorded" "$orig_status" "$(tmux -L "$A" show-option -gqv @pillbar-saved-status)"

# ══ Scenario B: absolute-centre opt-in ═══════════════════════════════════════
echo "── Scenario B: @pillbar-center-align absolute-centre is honoured (opt-in)"
new_sock B; B=$SOCK
tmux -L "$B" -f /dev/null new-session -d -s main -x 200 -y 50
tmux -L "$B" set-option -g @pillbar-center '#(echo C)'
tmux -L "$B" set-option -g @pillbar-center-align absolute-centre
tmux -L "$B" run-shell "'${ENTRY}'"
fmtB=$(tmux -L "$B" show-option -gqv 'status-format[1]')
contains "absolute-centre passed into format" "$fmtB" "#[align=absolute-centre]"

# a garbage value must be coerced back to the safe default
echo "── Scenario B2: bogus center-align coerced to centre"
tmux -L "$B" set-option -g @pillbar-center-align wat
tmux -L "$B" run-shell "'${ENTRY}'"
fmtB2=$(tmux -L "$B" show-option -gqv 'status-format[1]')
contains "bogus align coerced to centre" "$fmtB2" "#[align=centre]"
not_contains "bogus align value not passed through" "$fmtB2" "align=wat"

# ══ Scenario C: empty slot is skipped ════════════════════════════════════════
echo "── Scenario C: empty @pillbar-center → centre slot skipped, left+right remain"
new_sock C; C=$SOCK
tmux -L "$C" -f /dev/null new-session -d -s main -x 200 -y 50
tmux -L "$C" set-option -g @pillbar-left  '#(echo L)'
tmux -L "$C" set-option -g @pillbar-right  '#(echo R)'
tmux -L "$C" run-shell "'${ENTRY}'"
fmtC=$(tmux -L "$C" show-option -gqv 'status-format[1]')
contains "left slot present" "$fmtC" "#[align=left]#(echo L)"
contains "right slot present" "$fmtC" "#[align=right]#(echo R)"
not_contains "empty center slot skipped" "$fmtC" "#[align=centre]"

# ══ Scenario D: reload does not clobber the saved original status ═════════════
echo "── Scenario D: a second run (reload) keeps the true original status"
new_sock D; D=$SOCK
tmux -L "$D" -f /dev/null new-session -d -s main -x 200 -y 50
tmux -L "$D" set-option -g status on
tmux -L "$D" set-option -g @pillbar-left '#(echo L)'
tmux -L "$D" run-shell "'${ENTRY}'"   # saves 'on', sets status 2
tmux -L "$D" run-shell "'${ENTRY}'"   # runs again with status already 2
check "saved status is still the original 'on', not 2" "on" "$(tmux -L "$D" show-option -gqv @pillbar-saved-status)"

# ══ Scenario E: teardown restores status and clears our row ══════════════════
echo "── Scenario E: teardown restores status + clears status-format[1]"
tmux -L "$D" run-shell "'${TEARDOWN}'"
check "status restored to original 'on'" "on" "$(tmux -L "$D" show-option -gqv status)"
check "status-format[1] cleared" "" "$(tmux -L "$D" show-option -gqv 'status-format[1]')"
check "saved marker cleared" "" "$(tmux -L "$D" show-option -gqv @pillbar-saved-status)"

# ══ Scenario F: pill.sh renders three styles, never emits align ══════════════
echo "── Scenario F: pill.sh style output (nerd/ascii/none) and no-align guarantee"
for style in nerd ascii none; do
	out=$(printf '%s\n' 'CPU||42%|colour15|colour24' | bash "$PILL" "$style" default)
	echo "  [$style] $out"
	not_contains "pill.sh $style emits no align tag" "$out" "align"
	contains "pill.sh $style carries the value" "$out" "42%"
	# `%` must pass through verbatim — tmux does NOT re-expand #() output, so
	# doubling it (42%%) would render a literal double percent. Guard against a
	# re-introduced escape.
	not_contains "pill.sh $style does not double the percent" "$out" "42%%"
done
# nerd caps present as real bytes
nerd_out=$(printf '%s\n' 'X||Y|1|2' | bash "$PILL" nerd default)
if printf '%s' "$nerd_out" | grep -q "$(printf '\356\202\266')" && \
   printf '%s' "$nerd_out" | grep -q "$(printf '\356\202\264')"; then
	echo "  PASS: nerd end-caps E0B6/E0B4 present"
else
	echo "  FAIL: nerd end-caps missing"; FAILS=$((FAILS + 1))
fi
# empty input → empty output (no crash)
empty_out=$(printf '' | bash "$PILL" ascii default)
check "empty stdin → empty output" "" "$empty_out"

# ── SKIP: things that genuinely need an attached client ──────────────────────
echo "── SKIP (needs an attached client; verify by eye):"
echo "  SKIP: on-screen pixel alignment of the three slots"
echo "  SKIP: nerd end-caps rendering with an actual Nerd Font"
echo "  SKIP: absolute-centre vs centre visual position"

echo ""
if [ "$FAILS" -eq 0 ]; then
	echo "ALL SMOKE CHECKS PASSED"
	exit 0
else
	echo "SMOKE FAILURES: $FAILS"
	exit 1
fi
