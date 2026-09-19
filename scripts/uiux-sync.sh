#!/usr/bin/env bash
# Vendor the ui-ux-pro-max design reference skill.
#
# Why vendored
# ------------
# It was installed as a loose directory in ~/.claude/skills: unversioned,
# invisible to install.manifest, and reachable by Claude Code only. Nothing
# could update it and nothing did — measured 2026-09-19 the local copy carried
# 97 palette rows against upstream's 193, 50 font pairings against 74, and 9
# stacks against 22, roughly six months stale. A skill no mechanism can update
# is a skill that rots quietly while still answering questions.
#
# Under shared/skills it gets the same pin-and-sync discipline as the design
# gates, and the manifest fanout carries it to OpenCode too.
#
# Only the `ui-ux-pro-max` skill itself is taken (~3.6MB of CSV reference data).
# Upstream's other six skills — ui-styling (5.8MB), design, design-system,
# brand, banner-design, slides — are left behind: each would add its own
# always-on description, and the pipeline's direction step reads this one.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO/shared/skills/ui-ux-pro-max"
PIN_FILE="$REPO/UIUX_PIN"
UPSTREAM="https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git"

say() { printf '\033[36m%s\033[0m\n' "$*"; }

PIN="${1:-}"
if [ -z "$PIN" ] && [ -f "$PIN_FILE" ]; then
  PIN="$(rg -o '^commit: (\S+)' -r '$1' "$PIN_FILE" 2>/dev/null | head -1)"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "cloning $UPSTREAM"
git clone -q "$UPSTREAM" "$TMP/src"
if [ -n "$PIN" ]; then git -C "$TMP/src" checkout -q "$PIN"; else PIN="$(git -C "$TMP/src" rev-parse HEAD)"; fi
DATE="$(git -C "$TMP/src" log -1 --format=%ad --date=short)"

SRC="$TMP/src/.claude/skills/ui-ux-pro-max"
[ -d "$SRC" ] || { echo "uiux-sync: upstream layout changed, $SRC missing" >&2; exit 1; }

rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -R "$SRC" "$DEST"

cat >"$PIN_FILE" <<PIN_EOF
# Pin for the vendored ui-ux-pro-max reference skill. Regenerate with
# scripts/uiux-sync.sh.
upstream: $UPSTREAM
commit: $PIN
date: $DATE
PIN_EOF

say "vendored ui-ux-pro-max at ${PIN:0:12} ($DATE) — $(du -sh "$DEST" | cut -f1), $(wc -l <"$DEST/data/colors.csv" | tr -d ' ') palette rows"
