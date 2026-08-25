# VHS tape for the environment screenshot.
#
#   vhs docs/environment.tape
#
# Captures the real thing — tmux running this repo's config, with the yazi
# sidebar open beside a working pane — rather than the ASCII sketch that stood
# in for it. A drawing of a UI ages the moment the UI changes; a screenshot
# taken from the actual config cannot.
#
# Runs on an isolated tmux socket, so recording this never touches a live
# session. The sample project is created under ~/Proyectos and removed
# afterwards, because the prompt shows the working directory and a
# /var/folders/... temp path is not what anyone's terminal looks like.

Output docs/assets/environment.png

Set Shell "bash"
Set FontSize 15
Set Width 1500
Set Height 470
Set Padding 18
Set Framerate 24

Set Theme { "name": "Tokyo Night", "background": "#1a1b26", "foreground": "#c0caf5", "black": "#15161e", "red": "#f7768e", "green": "#9ece6a", "yellow": "#e0af68", "blue": "#7aa2f7", "magenta": "#bb9af7", "cyan": "#7dcfff", "white": "#a9b1d6", "brightBlack": "#414868", "brightRed": "#f7768e", "brightGreen": "#9ece6a", "brightYellow": "#e0af68", "brightBlue": "#7aa2f7", "brightMagenta": "#bb9af7", "brightCyan": "#7dcfff", "brightWhite": "#c0caf5" }

Hide
Type "export DEMO=$HOME/Proyectos/demo-readme" Enter
Type "mkdir -p $DEMO/{src,.github,.agents} && touch $DEMO/{package.json,.env,README.md} $DEMO/src/{index.ts,app.ts}" Enter
Type "git -C $DEMO init -q 2>/dev/null" Enter
Type "clear" Enter

# An isolated socket: recording this must never disturb a real session.
# TMUX_SOCKET is exported before the server starts, so run-shell inherits it
# and sidebar-toggle.sh talks to this socket instead of the default one. Without
# it the binding fires inside the isolated server but the script looks for the
# pane on the real one, and exits 1.
Type "export TMUX_SOCKET=readme-shot" Enter
Type "tmux -L readme-shot kill-server 2>/dev/null; tmux -L readme-shot -f ~/.tmux.conf new-session -d -s demo -c $DEMO -x 176 -y 23" Enter
Sleep 2s
# The sidebar is opened by calling the toggle directly rather than through its
# keybinding. The binding works in a real session, but inside a recording the
# keystroke has to survive VHS, the terminal and tmux's key table before it
# arrives, and a screenshot should not be betting on that chain. The result on
# screen is identical.
Type "PANE=$(tmux -L readme-shot list-panes -t demo -F '#{pane_id}')" Enter
Type "TMUX_SOCKET=readme-shot TMUX_PANE=$PANE bash ~/.config/tmux/sidebar-toggle.sh" Enter
Sleep 3s
Type "clear && tmux -L readme-shot attach -t demo" Enter
# Long enough for the status bar to refresh at least once (status-interval is
# 15s) so the CPU segment shows the machine at rest rather than mid-recording.
Sleep 20s
Show

Sleep 3s
