#!/usr/bin/env bash
# nowplaying-demo.sh — EXAMPLE center-slot provider for tmux-pillbar.
#
# Shows the "now playing" track from Apple Music or Spotify as a capsule. Its
# real job here is to demonstrate the ONE pattern every status-line provider
# must follow: NEVER block tmux. The foreground path only ever reads a cache
# file; when that cache is stale it kicks off a fully-detached background
# refresh and returns immediately with whatever it already had.
#
# macOS only: it asks Music/Spotify over AppleScript. On Linux (or with neither
# app running) it simply prints nothing — the slot disappears, which is the
# correct "no data" behaviour for a status widget.
#
# No `set -e` / no `pipefail`: this runs inside tmux `#(...)`, where a non-zero
# exit is an error. On any trouble it prints an empty string and exits 0.

set -u

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PILL="${CURRENT_DIR}/../scripts/pill.sh"
# shellcheck source=../scripts/helpers.sh
. "${CURRENT_DIR}/../scripts/helpers.sh" 2>/dev/null || true

MAX_AGE=5   # seconds before the cache is considered stale

# Resolve a safe cache dir; if we cannot, degrade to printing nothing.
CACHE_DIR="$(pillbar_cache_dir 2>/dev/null)"
if [ -z "$CACHE_DIR" ]; then
	exit 0
fi
CACHE="${CACHE_DIR}/nowplaying.cache"

# ── the actual (slow, may-block) data collection ─────────────────────────────
# Kept in a function so the background refresher can call it in isolation.
collect() {
	command -v osascript >/dev/null 2>&1 || return 0
	track=""
	# Apple Music first, then Spotify. Each guarded so a not-running app is a
	# silent no-op rather than an error dialog.
	track="$(osascript -e 'tell application "System Events" to (name of processes) contains "Music"' 2>/dev/null | grep -q true && \
		osascript -e 'tell application "Music" to if player state is playing then (get name of current track) & " — " & (get artist of current track)' 2>/dev/null)"
	if [ -z "$track" ]; then
		track="$(osascript -e 'tell application "System Events" to (name of processes) contains "Spotify"' 2>/dev/null | grep -q true && \
			osascript -e 'tell application "Spotify" to if player state is playing then (get name of current track) & " — " & (get artist of current track)' 2>/dev/null)"
	fi
	[ -z "$track" ] && { printf '' ; return 0 ; }
	# Trim to keep the capsule sane, then render through pill.sh. Colours are
	# yours to change — this framework ships no palette.
	track="$(printf '%s' "$track" | cut -c1-40)"
	printf '%s\n' "|${track}||colour15|colour53" | "$PILL"
}

# ── foreground: read cache, refresh in the background only if stale ───────────
now="$(date +%s 2>/dev/null || echo 0)"
mtime=0
if [ -f "$CACHE" ]; then
	# BSD stat (macOS) form; GNU stat falls through the || to 0.
	mtime="$(stat -f %m "$CACHE" 2>/dev/null || stat -c %Y "$CACHE" 2>/dev/null || echo 0)"
fi

if [ "$((now - mtime))" -gt "$MAX_AGE" ]; then
	# Fully-detached background refresh: all three std fds redirected so the
	# `&` subshell cannot hold the parent's stdout open (see the note in
	# ~/dotfiles/shell/tmux/ai-status.sh — a $()-captured bg job silently
	# blocks). Write to a temp file then atomically rename into place.
	(
		val="$(collect)"
		printf '%s' "$val" > "${CACHE}.new" && mv "${CACHE}.new" "$CACHE"
	) </dev/null >/dev/null 2>&1 &
fi

# Always return instantly with whatever we have (possibly empty on first run).
cat "$CACHE" 2>/dev/null
exit 0
