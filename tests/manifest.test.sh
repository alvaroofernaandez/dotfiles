#!/usr/bin/env bash
# Tests for install.manifest — the single source of truth for what gets
# installed and where.
#
# The manifest exists because there are now two installers: install.sh for
# Unix, and the cross-platform TUI under cmd/dotfiles-installer. A second copy
# of the link list diverges the first time someone adds an entry to one and not
# the other, and the failure is silent: the config simply never gets linked.
#
# So the contract these tests defend is narrow and specific:
#   1. the manifest parses, and every group declares a platform
#   2. every source it names actually exists in the repo
#   3. install.sh installs exactly what the manifest says — no more, no less
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO/install.manifest"

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "manifest"

# --- it exists ---------------------------------------------------------------
assert_eq "install.manifest exists" "yes" "$([ -f "$MANIFEST" ] && echo yes || echo no)"
[ -f "$MANIFEST" ] || { printf '\n%d passed, %d failed\n' "$pass" $((fail + 1)); exit 1; }

# --- every group declares a valid platform -----------------------------------
# A group with no platform would be silently skipped everywhere, or installed
# everywhere: both are wrong, and neither shows up as an error.
groups="$(rg -o '^\[([a-z-]+)\]' -r '$1' "$MANIFEST")"
group_count="$(printf '%s\n' "$groups" | rg -c . || echo 0)"
assert_eq "declares at least one group" "yes" \
  "$([ "$group_count" -ge 1 ] && echo yes || echo no)"

bad_platform=0
for g in $groups; do
  p="$(rg -A6 "^\[$g\]" "$MANIFEST" | rg -o '^platforms\s*=\s*(\S+)' -r '$1' | head -1)"
  case "$p" in
    unix | all) ;;
    *) echo "     group [$g] has platform '$p'"; bad_platform=1 ;;
  esac
done
assert_eq "every group declares platforms as unix or all" "0" "$bad_platform"

bad_label=0
for g in $groups; do
  rg -A6 "^\[$g\]" "$MANIFEST" | rg -q '^label\s*=\s*\S' || { echo "     group [$g] has no label"; bad_label=1; }
done
assert_eq "every group carries a label for the TUI" "0" "$bad_label"

# --- every source exists -----------------------------------------------------
# A manifest entry naming a path that was renamed or deleted makes install.sh
# fail at run time, on the user's machine, halfway through installing.
missing=0
while read -r src _dest; do
  [ -n "$src" ] || continue
  [ -e "$REPO/$src" ] || { echo "     missing source: $src"; missing=1; }
done < <(rg '^\S+\s+\S+$' "$MANIFEST" | rg -v '^\s*#' | rg -v '=')
assert_eq "every source named in the manifest exists" "0" "$missing"

# --- the fan-out target exists ----------------------------------------------
fanout_src="$(rg -o '^fanout-source\s*=\s*(\S+)' -r '$1' "$MANIFEST" | head -1)"
assert_eq "the fan-out source directory exists" "yes" \
  "$([ -n "$fanout_src" ] && [ -d "$REPO/$fanout_src" ] && echo yes || echo no)"

# --- install.sh and the manifest agree ---------------------------------------
# The heart of it. install.sh --dry-run prints one destination per line; the
# manifest plus its fan-out must expand to exactly that set. Any drift in
# either direction fails here rather than on someone's machine.
actual_dests="$(cd "$REPO" && ./install.sh --dry-run 2>/dev/null | awk 'NF {print $1}' | sort -u)"

expected_dests="$(
  rg '^\S+\s+\S+$' "$MANIFEST" | rg -v '^\s*#' | rg -v '=' | awk '{print $2}'
  if [ -n "$fanout_src" ]; then
    for d in $(rg -o '^fanout-dests\s*=\s*(.+)$' -r '$1' "$MANIFEST" | head -1); do
      for s in "$REPO/$fanout_src"/*/; do
        [ -d "$s" ] && echo "$d/$(basename "$s")"
      done
    done
  fi
)"
expected_dests="$(printf '%s\n' "$expected_dests" | sort -u)"

assert_eq "install.sh installs exactly what the manifest declares" \
  "" "$(diff <(printf '%s\n' "$expected_dests") <(printf '%s\n' "$actual_dests") | head -20)"

assert_eq "the count is non-trivial" "yes" \
  "$([ "$(printf '%s\n' "$actual_dests" | rg -c .)" -ge 40 ] && echo yes || echo no)"

# --- the Go installer agrees with install.sh ---------------------------------
# The third leg of the same contract. Two installers reading one manifest is
# only worth anything if they actually resolve it the same way: a divergence
# here means a machine installed with the TUI differs from one installed with
# the script, which is precisely the bug the manifest exists to prevent.
if command -v go >/dev/null 2>&1; then
  bin="$(mktemp -d)/dotfiles-installer"
  if (cd "$REPO" && go build -o "$bin" ./cmd/dotfiles-installer 2>/dev/null); then
    ok "the Go installer builds"
    go_dests="$("$bin" --yes --dry-run --repo "$REPO" 2>/dev/null \
      | rg -o '~/\S+' | sed 's|^~/||' | sort -u)"
    assert_eq "the Go installer resolves the same destinations as install.sh" \
      "" "$(diff <(printf '%s\n' "$actual_dests") <(printf '%s\n' "$go_dests") | head -20)"
  else
    ko "the Go installer builds" "a binary" "build failed"
  fi
  rm -rf "$(dirname "$bin")"
else
  # Not a failure: the shell installer is the one that must work everywhere.
  printf '  \033[33mSKIP\033[0m go toolchain not available — Go installer parity unchecked\n'
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
