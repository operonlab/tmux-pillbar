# tmux-pillbar demo — a framework for a second status row with left / centre /
# right "capsule" slots. Load it and the second row slides in; you bring the
# content and the colours.
#
# Recorded against an isolated tmux server (socket: vhsdemo-pillbar,
# -f /dev/null), never the user's live server. The three capsules are rendered
# by the bundled pill.sh from stand-in providers.
Output docs/demo.gif
Require tmux

Set Shell "bash"
Set Width 1200
Set Height 600
Set FontSize 15
Set Padding 12
Set TypingSpeed 55ms

# ---- hidden setup: isolated server, slot options (plugin loaded on camera) ----
Hide
Type "bash /private/tmp/claude-501/-Users-joneshong/aaff1254-ec36-4c2f-98bf-76d62cc8b483/scratchpad/vhs-visual/setup-pillbar.sh"
Enter
Sleep 1s
Type "clear; tmux -L vhsdemo-pillbar attach -t demo"
Enter
Sleep 1500ms
Show

# ---- visible demo ----
Sleep 2s

# load the plugin -> the second capsule row appears under the normal status bar
Type "tmux run-shell /Users/joneshong/work/tmux-plugins/tmux-pillbar/pillbar.tmux"
Enter
Sleep 4s

# ---- hidden teardown ----
Hide
Type "tmux -L vhsdemo-pillbar kill-server"
Enter
Sleep 500ms
