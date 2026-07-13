# tmux-pillbar HERO screenshot — a second tmux status row with three colour
# capsules (left = CPU, centre = now-playing, right = clock), nerd-font rounded
# end-caps. Recorded against an ISOLATED tmux server (socket: shot-pillbar,
# -f /dev/null); the user's default socket / live server is never touched. The
# capsules are rendered by the repo's own scripts/pill.sh from stand-in
# providers. Height is kept short on purpose so the status rows read large.
Output "/private/tmp/claude-501/-Users-joneshong/aaff1254-ec36-4c2f-98bf-76d62cc8b483/scratchpad/hero-shots/tmux-pillbar/_throwaway.gif"
Require tmux

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 1600
Set Height 420
Set Padding 20

# ---- hidden setup: isolated server, plugin loaded, then attach ----
Hide
Type "bash /private/tmp/claude-501/-Users-joneshong/aaff1254-ec36-4c2f-98bf-76d62cc8b483/scratchpad/hero-shots/tmux-pillbar/setup.sh"
Enter
Sleep 1s
Type "clear; tmux -L shot-pillbar attach -t demo"
Enter
Sleep 2s
Show

# The second row is already assembled in setup; give tmux a beat to paint it,
# then freeze the shutter on the three capsules.
Sleep 1500ms
Screenshot docs/screenshot.png
Sleep 300ms

# ---- hidden teardown: kill ONLY our isolated server ----
Hide
Type "tmux -L shot-pillbar kill-server"
Enter
Sleep 500ms
