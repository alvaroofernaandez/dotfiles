# VHS tape for the installer demo GIF.
#
#   vhs docs/installer-demo.tape
#
# Records a real install into a throwaway HOME, so the recording shows actual
# "linked" results rather than a dry run's "would install" — and can be remade
# at any time without touching a real machine.
#
# Typing speed is left close to human. A demo sped up until the keystrokes blur
# stops being a demonstration and becomes decoration.

Output docs/assets/installer.gif

Set Shell "bash"
Set FontSize 18
Set Width 1200
Set Height 760
Set Padding 24
Set Framerate 24

# Tokyo Night — the same palette the TUI and the rest of this repo use, so the
# recording sits in the same world as the thing it records.
Set Theme { "name": "Tokyo Night", "background": "#1a1b26", "foreground": "#c0caf5", "black": "#15161e", "red": "#f7768e", "green": "#9ece6a", "yellow": "#e0af68", "blue": "#7aa2f7", "magenta": "#bb9af7", "cyan": "#7dcfff", "white": "#a9b1d6", "brightBlack": "#414868", "brightRed": "#f7768e", "brightGreen": "#9ece6a", "brightYellow": "#e0af68", "brightBlue": "#7aa2f7", "brightMagenta": "#bb9af7", "brightCyan": "#7dcfff", "brightWhite": "#c0caf5" }

Hide
# A throwaway HOME so the install is real but harmless: the recording shows
# genuine "linked" results and cannot touch the machine it runs on.
#
# The binary is invoked as `dotfiles-installer`, which is what someone who
# installed it globally types. npx is not used here because its package cache
# lives in the real HOME, and replacing HOME turns the first frame into an
# "Ok to proceed?" prompt.
Type "export DOTFILES_NO_UPDATE_CHECK=1 DOTFILES_REPO=$PWD" Enter
Type "export PATH=/private/tmp/claude-501/-Users-alvaroofernaandez-dotfiles/7907223f-9ab6-4eaf-aa7f-fcd3528a0807/scratchpad/demobin:$PATH HOME=$(mktemp -d)" Enter
Type "clear" Enter
Show

Type "dotfiles-installer"
Sleep 700ms
Enter
Sleep 3s

# Let the selection screen land before anything moves.
Sleep 1800ms

# Move through the groups so the detail line under each is readable.
Down
Sleep 1s
Down
Sleep 1s
Down
Sleep 1s

# Deselect one, so the choice reads as real and the count responds.
Space
Sleep 1600ms
Space
Sleep 1200ms

Up
Sleep 500ms
Up
Sleep 500ms
Up
Sleep 800ms

# Install.
Enter
Sleep 5s

# Hold on the summary: it is the part worth reading.
Sleep 3s
