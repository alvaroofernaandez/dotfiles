#!/usr/bin/env bash
# Guards against committing credentials.
#
# This exists because a token did reach GitHub from this repo. The hand-rolled
# scan that cleared the file looked for `token` as a standalone word before ':'
# or '='; the key was named ENGRAM_CLOUD_TOKEN, so it never matched and the file
# was reported clean. A dedicated scanner replaces that guesswork.
#
# The second test matters as much as the first: a detector that cannot be shown
# to catch anything is decoration. It plants a credential and requires a hit.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "secrets"

if ! command -v gitleaks >/dev/null 2>&1; then
  printf '  \033[31mFAIL\033[0m gitleaks is required to verify this repo carries no credentials\n'
  printf '\n0 passed, 1 failed\n'
  exit 1
fi
ok "gitleaks is available"

# --- the tracked tree and its history are clean ------------------------------
# Judged by exit status: gitleaks prints "no leaks found" on success, so a
# naive /leaks found/ match would read a clean run as a failure.
(cd "$REPO" && gitleaks detect --source . --redact --no-banner >/dev/null 2>&1)
assert_eq "no credentials in the working tree or git history" "0" "$?"

# --- specific values that must never come back -------------------------------
# Named explicitly: this one was published once already.
# The value is reassembled at run time rather than written out.
#
# The scan below reads every commit, and one of those commits added this file.
# Spelled in full, the check finds its own source and reports the token as
# still present. It passed locally only by accident: `rg -q` exits at the first
# match, `git log` dies of SIGPIPE, and pipefail turned that into a non-zero
# pipeline — so the `&&` branch never ran and the failure looked like a pass.
# CI, with different timing, reported it honestly.
rotated_half_a="7c346f3e53d1b1a79c6aacaa4f10302"
rotated_half_b="49c42901779c304c24ba409a5ef00e045"
rotated="${rotated_half_a}${rotated_half_b}"

# Counted rather than short-circuited, so neither SIGPIPE nor pipefail can
# turn the answer into its opposite.
rotated_hits="$(cd "$REPO" && git log --all -p 2>/dev/null | rg -c "$rotated" || true)"
assert_eq "the rotated Engram token is absent from every commit" "0" "${rotated_hits:-0}"

assert_eq "the token is referenced by env var, not by value" "yes" \
  "$(rg -q '"ENGRAM_CLOUD_TOKEN"\s*:\s*"\{env:' "$REPO/config/opencode/opencode.json" 2>/dev/null && echo yes || echo no)"

# --- the detector actually detects -------------------------------------------
# Without this, a silently broken scanner would report success forever, which is
# precisely the failure mode that let the token through the first time.
canary_dir="$(mktemp -d)"
trap 'rm -rf "$canary_dir"' EXIT

# Built at runtime from random characters rather than written literally. A real
# token pattern sitting in this file would be flagged by the very scan above —
# the guard would trip over its own canary and report the repo as dirty forever.
canary="$(printf 'gh%s_%s' 'p' "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)")"
printf '{\n  "environment": {\n    "SOME_SERVICE_TOKEN": "%s"\n  }\n}\n' "$canary" \
  > "$canary_dir/planted.json"
gitleaks detect --source "$canary_dir" --no-git --redact --no-banner >/dev/null 2>&1
assert_eq "a planted credential is detected" "1" "$?"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
