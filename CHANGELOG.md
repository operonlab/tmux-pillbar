# Changelog

All notable changes to tmux-pillbar are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project aims to follow
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-07-11

Initial release.

### Added
- `pillbar.tmux` entry point: reads `@pillbar-*` options, assembles the second
  status row (`status-format[1]`) with **static** `#[align=...]` tags, and
  switches the status line to two rows (`status 2`).
- Three-slot model — left / centre / right — each fed a verbatim tmux format
  fragment (`#(command)` or an interpolation variable). An empty slot is skipped.
- Options: `@pillbar-left`, `@pillbar-center`, `@pillbar-right`,
  `@pillbar-center-align` (`centre` default, `absolute-centre` opt-in),
  `@pillbar-bg`, `@pillbar-pill-style` (`ascii` default, `nerd`, `none`).
- `scripts/pill.sh`: capsule renderer. Reads `icon|label|value|fg|bg` lines from
  stdin and emits styled capsules. Never emits an `#[align=...]` tag.
- `scripts/teardown.sh`: clears the second row and restores the original
  `status` value (saved in `@pillbar-saved-status` on first load).
- `examples/family.conf` and `examples/nowplaying-demo.sh`: a three-provider
  combination plus a worked example of the non-blocking cache + detached-refresh
  discipline every provider must follow.
- Headless structural smoke tests (`tests/smoke.sh`) on an isolated `-L` socket,
  and CI (`shellcheck -S warning` + smoke on Ubuntu and macOS).

### Notes
- Requires tmux **2.9+** (when `status-format[]` and `status 2` were introduced).
  Tested on `tmux next-3.8`.
- This is a **framework, not a theme** — it ships no colour palette. Bring your
  own colours.
