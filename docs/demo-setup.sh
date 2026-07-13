#!/bin/bash
# demo-setup.sh — self-contained stage for docs/demo.tape. Starts an ISOLATED
# tmux server (socket: pb-demo, own config) — your real tmux server and config
# are never touched.
#
# Anonymous by construction: an identity-free shell prompt and a cockpit theme
# that OWNS status-left AND status-right (the default status-right prints the
# machine's hostname — the theme replaces it so nothing leaks).
#
# HONEST BY DESIGN: pillbar owns the SECOND status row (status-format[1]). The
# theme deliberately leaves format[1] UNSET and starts at a single row, so the
# capsule row you see slide in on camera is assembled entirely by pillbar from
# the three @pillbar-* slots below — each a demo provider that pipes fixed lines
# through the repo's own scripts/pill.sh. Nothing but pillbar draws row 2.
set -u
unset TMUX TMUX_PANE
SOCK=pb-demo
WORK=/tmp/vhs-pillbar-demo
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_BIN="${TMUX_BIN:-tmux}"
PILL="$PLUGIN/scripts/pill.sh"

mkdir -p "$WORK"

# ── clean, anonymous shell for the pane. `pb` points at the plugin entry so the
#    tape can load it on camera without typing an identity-bearing absolute path. ──
cat > "$WORK/rc.sh" <<'RC'
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG=en_US.UTF-8
PS1='\[\e[38;2;166;227;161m\] dev \[\e[38;2;137;180;250m\]\W\[\e[0m\] ❯ '
PROMPT_COMMAND=
RC
printf "pb='%s/pillbar.tmux'\n" "$PLUGIN" >> "$WORK/rc.sh"

# ── three demo slot providers. Each pipes fixed `icon|label|value|fg|bg` lines
#    through the repo's own pill.sh (nerd style, row-bg #1E1E1E). This is the
#    "content" half of pillbar's contract — pillbar assembles, pill.sh renders,
#    no #[align=...] ever escapes a slot (that would wedge tmux at 100% CPU). ──
cat > "$WORK/prov-left.sh" <<PROV
#!/bin/bash
printf '%s\n' '|CC 5H|40%|#11111b|#cba6f7' '|CX 5H|65%|#11111b|#89b4fa' | "$PILL" nerd '#1E1E1E'
PROV
cat > "$WORK/prov-center.sh" <<PROV
#!/bin/bash
printf '%s\n' '|now playing|Clair de Lune|#11111b|#f5c2e7' | "$PILL" nerd '#1E1E1E'
PROV
cat > "$WORK/prov-right.sh" <<PROV
#!/bin/bash
printf '%s\n' '|CPU|34%|#11111b|#a6e3a1' '|MEM|16.7/24G|#11111b|#f9e2af' '|DISK|41%|#11111b|#94e2d5' | "$PILL" nerd '#1E1E1E'
PROV
chmod +x "$WORK/prov-left.sh" "$WORK/prov-center.sh" "$WORK/prov-right.sh"

# ── cockpit theme (catppuccin mocha). SINGLE row to start: session capsule on
#    the left, clock capsule on the right. It does NOT set status-format[1] — that
#    row belongs to pillbar and appears only once the plugin is loaded on camera. ──
cat > "$WORK/theme.conf" <<'CONF'
set -g default-terminal "tmux-256color"
set -as terminal-overrides ",xterm-256color:Tc"
set -g mouse on
setw -g automatic-rename off
set -g escape-time 0
set -g status on
set -g status-interval 2
set -g status-style "bg=#1E1E1E,fg=#cdd6f4"
set -g status-left '#[fg=#a6e3a1,bg=#1E1E1E]#[fg=#11111b,bg=#a6e3a1]  #[fg=#cdd6f4,bg=#313244] #S #[fg=#313244,bg=#1E1E1E] '
set -g status-left-length 40
set -g status-right '#[fg=#89dceb,bg=#1E1E1E]#[fg=#11111b,bg=#89dceb]  #[fg=#cdd6f4,bg=#313244] %H:%M #[fg=#313244,bg=#1E1E1E]'
set -g status-right-length 60
set -g window-status-format '#[fg=#6c7086] #I:#W '
set -g window-status-current-format '#[fg=#89b4fa,bold] #I:#W '
set -g window-status-separator ''
set -g pane-border-status top
set -g pane-border-format '#[align=centre]#{?pane_active,#[reverse],}#{pane_index}#[default] #{pane_current_command}'
set -g pane-border-style 'fg=#45475a'
set -g pane-active-border-style 'fg=#fab387,bold'
set -g message-style 'bg=#f9e2af,fg=#11111b,bold'
CONF

# ── isolated server: window 0 runs the clean shell EXPLICITLY (a session's first
#    window is created before default-command applies — classic prompt leak) ──
"$TMUX_BIN" -L "$SOCK" kill-server 2>/dev/null
sleep 0.3
"$TMUX_BIN" -L "$SOCK" -f "$WORK/theme.conf" new-session -d -s demo -x 118 -y 16 -n workspace -c "$WORK" "bash --rcfile $WORK/rc.sh -i"
"$TMUX_BIN" -L "$SOCK" set -g default-command "bash --rcfile $WORK/rc.sh -i"

# ── stage the three pillbar slots (plugin is loaded ON CAMERA by the tape, so the
#    second row appears live). Alignment is pillbar's static job; slots only carry
#    content. @pillbar-bg matches the status bar so the nerd caps blend into row 2. ──
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-bg '#1E1E1E'
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-pill-style nerd
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-left "#($WORK/prov-left.sh)"
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-center "#($WORK/prov-center.sh)"
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-right "#($WORK/prov-right.sh)"
