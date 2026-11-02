#!/usr/bin/env bash
# Tests for the versioned Orca config snapshot.
#
# Orca's Application Support directory mixes declarative config with account
# state and key material (session authority key, E2EE keypair, cookies, pane
# accounts, a profile index carrying the account email and cloud ids). This repo
# is public, so only the declarative part may be committed. These tests pin the
# snapshot's shape and fail the moment any of the private files sneak in.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORCA="$REPO/config/orca"

pass=0
fail=0
ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "orca-config"

# --- shape --------------------------------------------------------------------
assert_eq "README explains the snapshot" "yes" "$([ -f "$ORCA/README.md" ] && echo yes || echo no)"
assert_eq "plugin lock is versioned" "yes" "$([ -f "$ORCA/plugins.lock.json" ] && echo yes || echo no)"
assert_eq "plugin lock is valid JSON" "yes" \
  "$(python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$ORCA/plugins.lock.json" 2>/dev/null && echo yes || echo no)"
assert_eq "agent hooks snapshot is present" "yes" \
  "$([ -f "$ORCA/agent-hooks/claude-hook.sh" ] && echo yes || echo no)"

# --- nothing private ----------------------------------------------------------
FORBIDDEN="$(fd -H -t f -i '(\.key$|keypair|\.db($|-)|cookies|accounts|profile-index|\.enc$|devices|usage|journal|\.lock$|trust)' "$ORCA" 2>/dev/null \
  | rg -v '/plugins\.lock\.json$' | tr '\n' ' ')"
assert_eq "no key, db, cookie or account files" "" "$FORBIDDEN"

LEAKS="$(rg -l -i '(@gmail\.com|usr_[0-9a-f]{8}|prof_[0-9a-f]{8}|BEGIN [A-Z ]*PRIVATE KEY)' "$ORCA" 2>/dev/null | tr '\n' ' ')"
assert_eq "no account identifiers or private keys in content" "" "$LEAKS"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
