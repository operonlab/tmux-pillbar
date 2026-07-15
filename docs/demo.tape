# tmux-pillbar demo — a framework for a SECOND status row of left / center /
# right capsules, shown inside the family two-row pill cockpit. Fully
# self-contained: docs/demo-setup.sh stages an anonymous Starship-style shell and
# a catppuccin-mocha ISOLATED tmux server (socket pb-demo) that starts at a SINGLE
# status row (the staged row-1 cockpit). The theme deliberately leaves
# status-format[1] unset — so when the plugin is loaded on camera, the capsule row
# it assembles from the three @pillbar-* demo slots (each piped through the
# bundled scripts/pill.sh) slides in beneath the status bar. Row 1 is staged
# chrome; row 2 is drawn only by pillbar (its RIGHT slot reads REAL live stats).
# Re-record from the repo root with:  vhs docs/demo.tape
Output "docs/demo.gif"
Require tmux

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 2496
Set Height 620
Set Padding 20
Set TypingSpeed 35ms

Hide
Type "bash docs/demo-setup.sh"
Enter
Sleep 3s
Type "clear; tmux -L pb-demo attach -t demo"
Enter
Sleep 2s
Show

# one status row to start: the staged family cockpit (session / window / cluster
# chrome on the left, weather + clock on the right)
Sleep 2500ms
Type "# tmux-pillbar: add a SECOND status row of capsules — left / center / right"
Enter
Sleep 2500ms

# load the plugin -> the capsule row slides in beneath the status bar
Type `tmux run-shell "$pb"`
Enter
Sleep 4500ms

Type "# the row is yours: each slot is any command; here LEFT/CENTER are staged, RIGHT is live"
Enter
Sleep 3500ms

Hide
Ctrl+B
Type "d"
Sleep 400ms
Type "tmux -L pb-demo kill-server"
Enter
Sleep 500ms
