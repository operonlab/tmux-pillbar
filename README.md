# tmux-pillbar

> 中文說明請見 [docs/zh.md](docs/zh.md)

**A framework for a second tmux status row — left / centre / right slots, in a
"capsule" style.** It opens a second line under your normal status bar and lets
you drop any command or tmux variable into three slots. That's it.

`tmux-pillbar` is a **framework, not a theme.** It ships **no colour palette**
and **no content** — you bring the colours and the commands. It pairs naturally
with content providers like `tmux-sysmon`, `tmux-agent-status` and
`tmux-llm-usage` (there's a three-piece example below).

> **Scope, on purpose (v0.1):** pillbar only ever touches the **second row**
> (`status-format[1]`). It does **not** modify row 0, `status-left`, or
> `status-right` — so it can't fight your existing status bar or theme, and it
> can't rot against tmux changing its default format strings. Your first row is
> exactly as you left it.

> **Platform:** the framework itself is pure tmux and works on **Linux and
> macOS**. The one bundled *example* provider (`nowplaying-demo.sh`) is
> **macOS-only** and prints nothing elsewhere — see the note where it appears.

---

## 1. What is this?

Your tmux status bar is a single line. Sometimes you want a second line for
"ambient" info — system stats, what's playing, how much LLM quota you've burned —
without cramming it all into the first line.

`tmux-pillbar` gives you that second line, split into **three slots**:

```
┌───────────────────────────── your normal status bar ─────────────────────────┐
│ 0:zsh  1:vim                                            14:32  11-Jul-26       │
├──────────────────────────── the pillbar second row ──────────────────────────┤
│ [ LLM 42% ]                 [ ♪ Miles Davis ]              [ CPU 12% ][ 64% ] │
│  └ left slot                    └ centre slot                    └ right slot  │
└──────────────────────────────────────────────────────────────────────────────┘
```

You decide what goes in each slot. pillbar handles the layout (keeping each slot
pinned left / centred / right) and an optional "capsule" wrapper around your
text. It does **not** decide your colours — a framework shouldn't.

---

## 2. Quickstart

You need **tmux 2.9 or newer** (run `tmux -V` to check). Pick one of the two
paths below. Throughout, **`prefix`** means your tmux prefix key — **`Ctrl-b`**
unless you've changed it.

By default nothing shows up until you fill at least one slot, so the examples
below set a simple clock in the centre so you can *see* it working.

### Path A — I don't use a plugin manager (works right now)

Copy-paste these three steps:

```sh
# 1. Download the plugin somewhere permanent
git clone https://github.com/joneshong/tmux-pillbar ~/.tmux/plugins/tmux-pillbar

# 2. Tell tmux to load it, and give the centre slot something to show
cat >> ~/.tmux.conf <<'CONF'
set -g @pillbar-center '#(date +%H:%M)'
run-shell ~/.tmux/plugins/tmux-pillbar/pillbar.tmux
CONF

# 3. Reload tmux config (inside tmux: press prefix then r, or run this)
tmux source-file ~/.tmux.conf
```

A second row appears with a centred clock. Done.

### Path B — I use TPM (the tmux plugin manager)

**If you don't have TPM yet**, install it first:

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

...and make sure the very last line of your `~/.tmux.conf` is:

```tmux
run '~/.tmux/plugins/tpm/tpm'
```

**Then add this plugin.** Put these lines in `~/.tmux.conf` *above* the `run`
line:

```tmux
set -g @plugin 'joneshong/tmux-pillbar'
set -g @pillbar-center '#(date +%H:%M)'
```

Reload your config (`prefix` `r`), then press `prefix` `I` (capital i) to have
TPM download it. The second row appears.

---

## 3. Demo

*Demo GIF coming soon.*

---

## 4. Filling the slots

This is the whole idea, so it gets its own section.

> ⚠️ **`@pillbar-left`, `@pillbar-center` and `@pillbar-right` can run programs.**
> Whatever you put in a `#(...)` is executed by your shell every time the status
> line refreshes. Only ever set these in a **tmux.conf you trust** — treat them
> exactly like you'd treat `status-left` or any other `#(...)` in your config.

A slot value is inserted **verbatim** into the tmux status format. That means
you use ordinary tmux syntax:

| You want... | Put this in the slot |
|---|---|
| the output of a command | `#(some-command --flag)` |
| a tmux variable | `#{pane_current_path}` or `#S` |
| plain text | `on air` |
| nothing (slot disappears) | leave the option empty |

Examples:

```tmux
set -g @pillbar-left   '#(~/.tmux/plugins/tmux-llm-usage/scripts/usage.sh)'
set -g @pillbar-center '#{pane_current_path}'
set -g @pillbar-right  '#(uptime | sed "s/.*load/load/")'
```

### ⚠️ The one landmine: never put `#[align=...]` in a slot

pillbar writes the three `#[align=left]` / `#[align=centre]` / `#[align=right]`
tags **statically** into the format. **A slot's dynamic `#(...)` output must
never contain an `#[align=...]` tag.** If an align tag comes back from a `#()`
call, tmux's layout engine spins at **100% CPU** trying to re-solve the layout
forever. Colours (`#[fg=...]`, `#[bg=...]`) in slot output are completely fine —
only alignment is off-limits. The bundled `pill.sh` obeys this; if you write your
own provider, keep `align` out of its output.

### Capsules with `pill.sh`

`scripts/pill.sh` turns simple lines into styled "capsules". Feed it
`icon|label|value|fg|bg` lines on stdin; it prints the styled capsule string.
The cleanest way to use it is from a small **provider script** (percentages and
`printf` behave normally inside a script file — see the `%` note below):

```sh
# ~/.tmux/plugins/tmux-pillbar/examples/mystats.sh  (chmod +x it)
#!/bin/sh
printf '%s\n' \
  '|CPU|12%|colour15|colour24' \
  '|MEM|64%|colour15|colour53' \
  | "$(dirname "$0")/../scripts/pill.sh"
```

```tmux
set -g @pillbar-right '#(~/.tmux/plugins/tmux-pillbar/examples/mystats.sh)'
```

Empty fields are dropped; `fg`/`bg` default to your terminal's own colours when
omitted. The look is controlled by `@pillbar-pill-style` (see Options).
`examples/nowplaying-demo.sh` is a complete provider that uses `pill.sh`.

### A note on `%` (percent signs)

tmux reads the text **inside** a `#( ... )` as a format string *before* running
it, and `%` is special there (`%s` becomes a timestamp, a lone `%` vanishes). Two
consequences:

- **In a `#()` command written directly in tmux.conf**, double any literal
  percent: `#(echo "42%%")` shows `42%`. This is why the example above lives in a
  script file — inside a script, `%` is ordinary.
- **In your provider's OUTPUT**, `%` is *not* special — tmux does not re-expand
  what a command prints. So a provider (or `pill.sh`) that prints `42%` shows
  `42%`. You never double percent signs in output.

### The non-blocking rule (important for anything slow)

Everything in a `#(...)` runs on tmux's status refresh, on the main loop. **A
slot that shells out to the network (or anything slow) on every refresh will
make tmux stutter.** The correct pattern is: read a cache file and return
instantly; when the cache is stale, refresh it in a **fully detached background
job**. `examples/nowplaying-demo.sh` is a complete, copyable example of exactly
this pattern (and a good template for your own providers).

---

## 5. A three-piece combo (the "family")

`examples/family.conf` wires three complementary providers into the three slots:

```tmux
set -g @pillbar-left   '#(~/.tmux/plugins/tmux-llm-usage/scripts/usage.sh)'    # left  (llm-usage reader)
set -g @pillbar-center '#(~/.tmux/plugins/tmux-pillbar/examples/nowplaying-demo.sh)'  # centre (macOS-only demo)
# right — sysmon has no single "row" script; each field is its own reader call:
set -g @pillbar-right  '#(~/.tmux/plugins/tmux-sysmon/scripts/sysmon.sh net)#(~/.tmux/plugins/tmux-sysmon/scripts/sysmon.sh cpu)#(~/.tmux/plugins/tmux-sysmon/scripts/sysmon.sh mem)#(~/.tmux/plugins/tmux-sysmon/scripts/sysmon.sh disk)'
set -g @pillbar-pill-style ascii
```

Copy the file, point the paths at whatever providers you actually have, and
reload. Each provider reads its own cache and never blocks — see the file's
comments. Two things to know about wiring these particular siblings in:

- **Call the reader scripts directly, not the `#{...}` tokens.** `tmux-sysmon`
  and `tmux-llm-usage` advertise `#{sysmon_cpu}` / `#{llm_usage}`-style tokens,
  but each plugin only rewrites those inside `status-left` / `status-right` —
  pillbar's second row (`status-format[1]`) is never touched, so a token dropped
  into a slot stays a literal and shows nothing. Point the slot at the underlying
  reader instead: `usage.sh`, and `sysmon.sh <field>`.
- **sysmon prints one field per call, and its cache must be warm.** There is no
  single "row" script; `sysmon.sh` takes `net` / `cpu` / `mem` / `disk` and emits
  just that field, so the right slot chains four calls. It returns the cached
  value — which is empty until the `tmux-sysmon` plugin has loaded and run one
  background refresh, so load that plugin too. The right slot is blank on the
  very first render and fills in a moment later.

---

## 6. Options

Set these in `~/.tmux.conf` **before** the line that loads the plugin. Every
option has a sensible default; you can ignore the whole table until you want to
change something.

| Option | Default | What it does (plain words) |
|---|---|---|
| `@pillbar-left` | _(empty)_ | Left slot content. A `#(command)`, a `#{variable}`, or plain text. Empty = no left slot. **Runs code — see the warning above.** |
| `@pillbar-center` | _(empty)_ | Centre slot content. Same rules. **Runs code.** |
| `@pillbar-right` | _(empty)_ | Right slot content. Same rules. **Runs code.** |
| `@pillbar-center-align` | `centre` | How the centre slot is centred. `centre` centres it in the space *left over* between the side slots (works everywhere). `absolute-centre` centres it against the *full* width — see the note below. |
| `@pillbar-bg` | `default` | Background colour of the whole second row (the gaps between capsules). `default` = your terminal's own background. |
| `@pillbar-pill-style` | `ascii` | Capsule look used by `pill.sh`: `ascii` = `[ ... ]` brackets (any font); `nerd` = rounded half-circle end-caps (needs a Nerd Font); `none` = bare coloured text, no delimiters. |

### A note on `absolute-centre`

`centre` (the default) is the safe choice and works on every tmux that has a
second status row. `absolute-centre` is a **newer** tmux value: it centres the
middle slot against the entire width, ignoring how wide the side slots are — so
the centre text stays put even as the sides grow. It's **opt-in**:

```tmux
set -g @pillbar-center-align absolute-centre
```

On a tmux too old to recognise it, the centre slot **collapses to the left**. If
you set `absolute-centre` and your centre content jumps to the left edge, your
tmux is too old — switch back to `centre` (or upgrade tmux). Verified behaviour
on `tmux next-3.8`: `absolute-centre` centres against the full width; `centre`
centres in the free space; an unknown value falls back to the left.

---

## 7. Uninstall

To remove the second row and restore your status line, run this from an attached
tmux client:

```sh
bash ~/.tmux/plugins/tmux-pillbar/scripts/teardown.sh
```

Then delete the plugin line from `~/.tmux.conf` (the
`run-shell ...pillbar.tmux` line, or the `set -g @plugin 'joneshong/tmux-pillbar'`
line) and reload with `prefix` `r`. Teardown restores the exact `status` value
pillbar saved when it first loaded, and leaves your own `@pillbar-*` lines alone
(remove them by hand if you added any).

---

## 8. Troubleshooting / FAQ

**Q: I loaded the plugin but no second row appears.**
The row only shows up once at least one slot has content. Set one, e.g.
`set -g @pillbar-center '#(date +%H:%M)'`, and reload (`prefix` `r`). Then check
tmux actually switched to two rows: `tmux show-option -gv status` should print
`2`.

**Q: My tmux is pinned at 100% CPU after I added a slot.**
Almost certainly your slot's `#(...)` output contains an `#[align=...]` tag —
this is the one thing a slot must never emit (see "The one landmine" above).
Remove any `align` from that command's output. Colours are fine; alignment is
not.

**Q: The bar stutters / feels laggy when a slot updates.**
That slot is doing slow work (network, spawning heavy processes) directly inside
`#(...)`, which blocks tmux's refresh. Switch it to the cache + detached-refresh
pattern in `examples/nowplaying-demo.sh` — read a cache instantly, refresh in the
background.

**Q: I set `absolute-centre` and the middle slot jumped to the left.**
Your tmux doesn't recognise `absolute-centre` as an alignment value. Use
`@pillbar-center-align centre` (the default), or upgrade tmux.

**Q: The `nerd` style shows tofu boxes / question marks instead of rounded ends.**
The rounded end-caps are Nerd Font glyphs (`E0B6` / `E0B4`). Your terminal font
isn't a Nerd Font. Use `@pillbar-pill-style ascii` (or `none`), or install a
Nerd Font.

**Q: Did this change my first status line?**
No. pillbar only ever writes `status-format[1]` (the second row) and the `status`
height. Your row 0, `status-left`, and `status-right` are untouched by design.

---

## 9. Testing / CI

Not everything can be tested without a human watching a screen. This repo is
honest about the split:

**Verified automatically** (`bash tests/smoke.sh`, plus `shellcheck` in CI):

- every script parses (`bash -n`)
- the assembled `status-format[1]` has the three **static** align tags and the
  `#()` content in the right places, and `status` becomes `2`
- `absolute-centre` is passed through when opted in; a bogus value is coerced to
  `centre`
- an empty slot is skipped
- a config reload does not clobber the saved original `status`
- teardown restores the original `status` and clears the second row
- `pill.sh` renders all three styles and **never** emits an `align` tag

All of the above run against a throwaway, isolated `-L` tmux socket — your real
tmux server is never touched.

**Must be checked by a human** (needs an attached client): the actual on-screen
**alignment** of the three slots, and Nerd Font end-cap **rendering**. The smoke
script prints these as `SKIP`.

---

## 10. Credits / License

Built by [joneshong](https://github.com/joneshong). Released under the
**MIT License** — see [LICENSE](LICENSE).

Complementary content providers (bring your own colours):
`tmux-sysmon`, `tmux-agent-status`, `tmux-llm-usage`.

繁體中文快速上手與 FAQ 見 [docs/zh.md](docs/zh.md)。
