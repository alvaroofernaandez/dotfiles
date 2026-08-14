#!/usr/bin/env bash
# Tests for the paste router behind cmd+v.
#
# cmd+v cannot carry an image on its own: Ghostty's paste_from_clipboard only
# pushes TEXT down the pty, and image bytes do not fit through it. TUIs that
# accept pasted images (Claude Code) instead watch for ctrl+v — 0x16 — and read
# the system clipboard natively, bypassing the pty.
#
# So one key has to mean two things, and the branch cannot be decided by which
# app is in front: a Claude Code pane reports `2.1.232` as its command, a
# version string that changes on every update. The clipboard CONTENT is the
# stable signal, which is what this router reads.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ROUTER="$REPO/config/tmux/paste-router.sh"

# Real `osascript -e 'clipboard info'` output, captured on macOS 15.
CLIP_SCREENSHOT='«class PNGf», 703838, «class AVIF», 164185, «class 8BPS», 5245480, GIF picture, 265978, TIFF picture, 23758990'
CLIP_TEXT='«class utxt», 10, «class ut16», 22'
CLIP_RICH_TEXT='«class utxt», 41, «class ut16», 84, «class RTF », 233, TIFF picture, 9210'
CLIP_EMPTY=''

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

# ROUTE_ONLY keeps the decision inspectable without a tmux server attached,
# mirroring how launch.sh exposes LAUNCH_RESOLVE_ONLY.
route_for() { CLIPBOARD_INFO="$1" ROUTE_ONLY=1 sh "$ROUTER" 2>/dev/null; }

echo "paste-router"

assert_eq "the router is executable" "yes" \
  "$([ -x "$ROUTER" ] && echo yes || echo no)"

# --- the case this exists for -------------------------------------------------
assert_eq "a screenshot routes to the image path" "image" "$(route_for "$CLIP_SCREENSHOT")"

# --- the case that must not regress -------------------------------------------
# 0x16 is quoted-insert in zsh, so sending it for ordinary text would corrupt
# the prompt line. Text has to stay on the plain paste path.
assert_eq "plain text routes to the text path" "text" "$(route_for "$CLIP_TEXT")"

# Copying from a browser or word processor often carries a TIFF rendering
# ALONGSIDE the text. Pasting text is the common intent and the cheaper mistake,
# so the presence of plain text wins over an image flavour.
assert_eq "rich text carrying a TIFF still routes to text" "text" "$(route_for "$CLIP_RICH_TEXT")"

# --- degenerate input ---------------------------------------------------------
assert_eq "an empty clipboard routes to text" "text" "$(route_for "$CLIP_EMPTY")"

# --- the probe must not be hardcoded to a stub --------------------------------
# Without an override the router has to ask the real system clipboard.
assert_eq "falls back to osascript when no override is given" "yes" \
  "$(rg -q 'clipboard info' "$ROUTER" 2>/dev/null && echo yes || echo no)"

# --- the two sides of the branch ----------------------------------------------
assert_eq "the image path sends the 0x16 byte" "yes" \
  "$(rg -q 'send-keys .*0x16|send-keys .*C-v' "$ROUTER" 2>/dev/null && echo yes || echo no)"
assert_eq "the text path pastes through tmux rather than 0x16" "yes" \
  "$(rg -q 'paste-buffer' "$ROUTER" 2>/dev/null && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
