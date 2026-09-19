#!/usr/bin/env bash
# Mirror the blocking agent rules from CLAUDE.md into OpenCode's AGENTS.md.
#
# One rule set, two agents, one source. CLAUDE.md owns the block between the
# markers; this copies it verbatim into AGENTS.md between the same markers,
# appending them if AGENTS.md does not have them yet.
#
# Only the BLOCKING SUMMARY is shared. The detail — the pipeline procedure, the
# TDD scope, the gstack policy — lives in skills, and the manifest fanout
# already carries those to OpenCode. Copying detail into two instruction files
# is how the two drift; copying the part that must hold before a skill can load
# is what keeps them honest.
#
# Idempotent: re-running with nothing changed rewrites identical bytes.
# Tests: tests/agent-rules-sync.test.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/config/claude/CLAUDE.md"
DST="$REPO/config/opencode/AGENTS.md"
BEGIN='<!-- shared:agent-rules -->'
END='<!-- /shared:agent-rules -->'

block="$(awk -v b="$BEGIN" -v e="$END" '$0==b{f=1;next} $0==e{f=0} f' "$SRC")"
[ -n "$block" ] || { echo "sync-agent-rules: no block found in $SRC" >&2; exit 1; }

tmp="$(mktemp)"
trap 'rm -f "$tmp" "$tmp.block" "$tmp.out"' EXIT

printf '%s\n' "$block" >"$tmp.block"

if rg -qF -- "$BEGIN" "$DST"; then
  awk -v b="$BEGIN" -v e="$END" -v file="$tmp.block" '
    $0==b { print; while ((getline line < file) > 0) print line; close(file); skip=1; next }
    $0==e { skip=0 }
    !skip { print }
  ' "$DST" >"$tmp.out"
  mv "$tmp.out" "$DST"
else
  { printf '\n%s\n' "$BEGIN"; printf '%s\n' "$block"; printf '%s\n' "$END"; } >>"$DST"
fi

printf 'sync-agent-rules: %d lines mirrored into AGENTS.md\n' "$(printf '%s\n' "$block" | wc -l | tr -d ' ')"
