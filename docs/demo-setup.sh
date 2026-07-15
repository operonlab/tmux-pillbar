#!/bin/bash
# demo-setup.sh — self-contained stage for docs/demo.tape. Builds everything the
# recording needs and starts an ISOLATED tmux server (socket: pb-demo, own
# config) — your real tmux server and config are never touched.
#
# Anonymous by construction: an identity-free Starship-style shell prompt and a
# cockpit that OWNS both status rows visible on camera (the default tmux
# status-right prints the machine's hostname — the cockpit format replaces it so
# nothing leaks).
#
# FAMILY-CONSISTENT: the same two-row pill cockpit as the rest of the plugin
# family (catppuccin mocha, half-circle end-caps). Row 1 = session / window /
# cluster / weather-clock chrome — this is STAGED chrome set into status-format[0]
# by this script; pillbar deliberately never touches row 1.
#
# HONEST BY DESIGN: pillbar draws the SECOND status row and NOTHING ELSE. The
# theme starts at a SINGLE row (status on) and leaves status-format[1] UNSET; the
# capsule row you see slide in on camera is assembled entirely by pillbar.tmux
# from the three @pillbar-* slots below — each piped through the repo's own
# scripts/pill.sh. Of those three, LEFT (quota) and CENTER (now playing) carry
# fixed demo lines, while RIGHT reads this machine's REAL live load / memory /
# disk on every refresh. So row 2 is genuinely pillbar's assembly of real+staged
# providers, not a hand-written format string.
set -u
unset TMUX TMUX_PANE
SOCK=pb-demo
WORK=/tmp/vhs-pillbar-demo
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_BIN="${TMUX_BIN:-tmux}"
PILL="$PLUGIN/scripts/pill.sh"

mkdir -p "$WORK"

# ── glyphs (byte escapes) + mocha palette — for the STAGED row-1 cockpit ──
CAPL=$(printf '\xee\x82\xb6'); CAPR=$(printf '\xee\x82\xb4'); SEP=$(printf '\xee\x82\xb0')
I_TERM=$(printf '\xee\x9e\x95');   I_ROBOT=$(printf '\xf3\xb0\x9a\xa9')
I_PLAY=$(printf '\xef\x81\x8b');   I_PAUSE=$(printf '\xef\x81\x8c')
I_FLEET=$(printf '\xef\x84\x88');  I_CAL=$(printf '\xef\x86\xae')
I_THERMO=$(printf '\xef\x8b\x89'); I_CLOCK=$(printf '\xef\x80\x97')
BG='#1E1E1E'; CRUST='#11111b'; FG='#cdd6f4'; SURF='#313244'
PEACH='#fab387'; YELLOW='#f9e2af'; MAROON='#eba0ac'; LAVENDER='#b4befe'
MAUVE='#cba6f7'; PINK='#f5c2e7'; BLUE='#89b4fa'; SKY='#89dceb'
SAPPHIRE='#74c7ec'; TEAL='#94e2d5'; GREEN='#a6e3a1'; RED='#f38ba8'

# ── Row 1 pieces: session pill · window chips · cluster capsule · right pill ──
LEFT_R1="#[fg=$GREEN,bg=$BG]${CAPL}#[fg=$CRUST,bg=$GREEN]${I_TERM}  #[fg=$FG,bg=$SURF] #S #[fg=$SURF,bg=$BG]${CAPR} "
WINF="#[fg=$CRUST,bg=#9399b2]#[fg=$BG,reverse]${CAPL}#[none]#I #[fg=$FG,bg=$SURF] #W "
WINCUR="#[fg=$CRUST,bg=$PEACH]#[fg=$BG,reverse]${CAPL}#[none]#I #[fg=$FG,bg=#45475a] #W "
CLUSTER="#[fg=$MAUVE,bg=$BG]${CAPL}#[fg=$CRUST,bg=$MAUVE]${I_ROBOT}  #[fg=$FG,bg=$SURF] ${I_PLAY} 1  ${I_PAUSE} 8 #[fg=$SAPPHIRE,bg=$SURF]${CAPL}#[fg=$CRUST,bg=$SAPPHIRE]${I_FLEET}  #[fg=$FG,bg=$SURF] #[fg=$GREEN,bg=$SURF]M #[fg=$GREEN,bg=$SURF]W #[fg=$RED,bg=$SURF]A #[fg=$SURF,bg=$BG]${CAPR}"
RIGHT_R1="#[fg=$PINK,bg=$BG]${CAPL}#[fg=$CRUST,bg=$PINK]${I_CAL}  #[fg=$FG,bg=$SURF] #W #[fg=$SKY,bg=$SURF]${CAPL}#[fg=$CRUST,bg=$SKY]${I_THERMO}  #[fg=$FG,bg=$SURF] 🌤️ 29°C #[fg=$SAPPHIRE,bg=$SURF]${CAPL}#[fg=$CRUST,bg=$SAPPHIRE]${I_CLOCK}  #[fg=$FG,bg=$SURF] %Y/%m/%d %H:%M #[fg=$SURF,bg=$BG]${CAPR}"
FMT0="#[align=left bg=$BG]${LEFT_R1}#[list=on]#{W:#{T:@pw-fmt},#{T:@pw-cur}}#[nolist align=right]${RIGHT_R1}#[align=absolute-centre]${CLUSTER}"

# ── pane shell: byte-exact Starship clone (catppuccin_mocha), user = "dev" —
#    same segmented prompt as the rest of the plugin family ──
cat > "$WORK/rc.sh" <<'RC'
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG=en_US.UTF-8
_SEP=$(printf '\xee\x82\xb0'); _CAPL=$(printf '\xee\x82\xb6'); _CAPR=$(printf '\xee\x82\xb4')
_APPLE=$(printf '\xef\x85\xb9'); _BRANCH=$(printf '\xef\x90\x98')
_CLOCKG=$(printf '\xef\x90\xba'); _ARROW=$(printf '\xef\x90\xb2')
_SURF0='49;50;68'; _PEACH='250;179;135'; _GREEN='166;227;161'; _TEAL='148;226;213'
_BLUE='137;180;250'; _PINK='245;194;231'; _TEXT='205;214;244'; _MANTLE='24;24;37'; _BASE='30;30;46'
_p10line() {
  local b git=""
  if b=$(git branch --show-current 2>/dev/null) && [ -n "$b" ]; then
    git=$(printf '\033[38;2;%s;48;2;%sm %s %s ' "$_BASE" "$_GREEN" "$_BRANCH" "$b")
  fi
  printf '\033[38;2;%sm%s\033[38;2;%s;48;2;%sm%s dev \033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm …/%s \033[38;2;%s;48;2;%sm%s%s\033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm %s %s \033[0m\033[38;2;%sm%s\033[0m \n' \
    "$_SURF0" "$_CAPL" "$_TEXT" "$_SURF0" "$_APPLE" "$_SURF0" "$_PEACH" "$_SEP" \
    "$_MANTLE" "$_PEACH" "${PWD##*/}" "$_PEACH" "$_GREEN" "$_SEP" "$git" \
    "$_GREEN" "$_TEAL" "$_SEP" "$_TEAL" "$_BLUE" "$_SEP" "$_BLUE" "$_PINK" "$_SEP" \
    "$_MANTLE" "$_PINK" "$_CLOCKG" "$(date '+%I:%M %p')" "$_PINK" "$_CAPR"
}
PROMPT_COMMAND=_p10line
PS1='\[\033[1;38;2;166;227;161m\]'"$_ARROW"'\[\033[0m\] '
RC
printf "pb='%s/pillbar.tmux'\n" "$PLUGIN" >> "$WORK/rc.sh"

# ── staged sample project so the Starship prompt shows a …/path + branch pill ──
APP="$WORK/demo-app"
rm -rf "$APP"; mkdir -p "$APP/src"
printf '# demo-app\n\nA tiny sample project.\n' > "$APP/README.md"
printf 'flask\npytest\n' > "$APP/requirements.txt"
git -C "$APP" init -q -b main
git -C "$APP" -c user.name=dev -c user.email=dev@example.com add -A
git -C "$APP" -c user.name=dev -c user.email=dev@example.com commit -qm "initial commit"

# ── three pillbar slot providers. Each pipes `icon|label|value|fg|bg` lines
#    through the repo's own pill.sh (nerd style, row-bg #1E1E1E). This is the
#    "content" half of pillbar's contract — pillbar assembles, pill.sh renders,
#    no #[align=...] ever escapes a slot (that would wedge tmux at 100% CPU).
#    LEFT + CENTER carry fixed demo lines; RIGHT reads REAL live system stats. ──
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
# REAL live readings (all instant, non-blocking): 1-min load average, total
# physical memory, and root-filesystem usage. No cache needed — these are cheap.
load=\$(sysctl -n vm.loadavg 2>/dev/null | awk '{printf "%.2f", \$2}')
mem=\$(( \$(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))
disk=\$(df -h / 2>/dev/null | awk 'NR==2{print \$5}')
printf '%s\n' "|LOAD|\${load:-–}|#11111b|#a6e3a1" "|MEM|\${mem:-0}G|#11111b|#f9e2af" "|DISK|\${disk:-–}|#11111b|#94e2d5" | "$PILL" nerd '#1E1E1E'
PROV
chmod +x "$WORK/prov-left.sh" "$WORK/prov-center.sh" "$WORK/prov-right.sh"

# ── base theme (static parts; row-1 format is set after server start). SINGLE
#    row to start (status on): row 2 belongs to pillbar and appears only once the
#    plugin is loaded on camera. ──
cat > "$WORK/theme.conf" <<'CONF'
set -g default-terminal "tmux-256color"
set -as terminal-overrides ",xterm-256color:Tc"
set -g mouse on
setw -g automatic-rename off
set -g escape-time 0
set -g status on
set -g status-interval 2
set -g status-style "bg=#1E1E1E,fg=#cdd6f4"
set -g status-left-length 30
set -g status-right-length 200
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
"$TMUX_BIN" -L "$SOCK" -f "$WORK/theme.conf" new-session -d -s demo -x 118 -y 18 -n workspace -c "$APP" "bash --rcfile $WORK/rc.sh -i"
"$TMUX_BIN" -L "$SOCK" set -g default-command "bash --rcfile $WORK/rc.sh -i"

# row-1 STAGED cockpit chrome (composed above with byte-escape glyphs). pillbar
# never touches this row — it owns status-format[1] only.
"$TMUX_BIN" -L "$SOCK" set -g @pw-fmt "$WINF"
"$TMUX_BIN" -L "$SOCK" set -g @pw-cur "$WINCUR"
"$TMUX_BIN" -L "$SOCK" set -g 'status-format[0]' "$FMT0"

# ── stage the three pillbar slots. @pillbar-bg matches the status bar so the
#    nerd caps blend into row 2. The plugin is loaded ON CAMERA by the tape, so
#    the second row is assembled live by pillbar.tmux — this script sets no
#    status-format[1] and leaves status at a single row. ──
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-bg '#1E1E1E'
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-pill-style nerd
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-left "#($WORK/prov-left.sh)"
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-center "#($WORK/prov-center.sh)"
"$TMUX_BIN" -L "$SOCK" set -g @pillbar-right "#($WORK/prov-right.sh)"
