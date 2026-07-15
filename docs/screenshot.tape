# tmux-pillbar HERO — the family two-row pill cockpit with pillbar's SECOND status
# row (left / center / right capsules) assembled live from the three @pillbar-*
# slots. Fully self-contained: docs/demo-setup.sh stages an anonymous
# Starship-style shell + a catppuccin-mocha ISOLATED tmux server (socket pb-demo)
# that starts at a SINGLE status row; the plugin is loaded on camera so the
# capsule row slides in beneath the staged row-1 chrome. Row 2 is drawn only by
# pillbar (its RIGHT slot reads REAL live stats). Re-shoot from the repo root
# with:  vhs docs/screenshot.tape
Output "docs/demo-raw.gif"
Require tmux

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 2392
Set Height 400
Set Padding 20
Set TypingSpeed 35ms

# ---- hidden setup: isolated pb-demo server staged, then attach ----
Hide
Type "bash docs/demo-setup.sh"
Enter
Sleep 3s
Type "clear; tmux -L pb-demo attach -t demo"
Enter
Sleep 2s
Show

# one status row to start: the staged family cockpit (row 1). Narrate, then load
# the plugin so pillbar's capsule row slides in beneath the status bar.
Sleep 1500ms
Type "# tmux-pillbar: add a SECOND status row of capsules — left / center / right"
Enter
Sleep 1200ms
Type `tmux run-shell "$pb"`
Enter
Sleep 4000ms
Type "# the row is yours: each slot is any command; here LEFT/CENTER are staged, RIGHT is live"
Enter
Sleep 2500ms

# freeze the shutter on the two-row cockpit + pillbar's capsule row
Screenshot docs/screenshot.png
Sleep 300ms

# ---- hidden teardown: kill ONLY our isolated server ----
Hide
Ctrl+B
Type "d"
Sleep 400ms
Type "tmux -L pb-demo kill-server"
Enter
Sleep 500ms
