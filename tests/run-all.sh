#!/usr/bin/env bash
# Run every test suite in the repo and summarise the result.
#
# The tmux/yazi suites exercise the *installed* configs under ~/.config, so run
# ./install.sh first on a fresh machine or they will report missing files.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Fail loudly on a missing tool rather than quietly miscounting.
#
# This runner parses each suite's summary with rg and sd. When one of them is
# absent the parse yields an empty string, every count becomes 0, and suites
# that actually passed are printed in red — which is how a CI run once reported
# a broken test suite when the only thing missing was a binary.
missing=()
for tool in rg sd; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [ "${#missing[@]}" -gt 0 ]; then
  printf '\033[31mmissing required tools: %s\033[0m\n' "${missing[*]}" >&2
  printf 'install them with: brew install %s\n' "${missing[*]}" >&2
  exit 2
fi

SUITES=(
  "$REPO/tests/secrets.test.sh"
  "$REPO/tests/manifest.test.sh"
  "$REPO/tests/no-proprietary.test.sh"
  "$REPO/tests/zshrc-secrets.test.sh"
  "$REPO/tests/shell-hygiene.test.sh"
  "$REPO/tests/install.test.sh"
  "$REPO/tests/launch.test.sh"
  "$REPO/tests/ghostty-keys.test.sh"
  "$REPO/config/tmux/tests/sidebar-toggle.test.sh"
  "$REPO/config/tmux/tests/open-file.test.sh"
  "$REPO/config/tmux/tests/yazi-sidebar-config.test.sh"
  "$REPO/config/tmux/tests/statusbar.test.sh"
  "$REPO/config/tmux/tests/status-style.test.sh"
  "$REPO/config/tmux/tests/keybindings.test.sh"
  "$REPO/config/tmux/tests/sidebar-button.test.sh"
  "$REPO/config/tmux/tests/close-file.test.sh"
  "$REPO/config/tmux/tests/sidebar-follow.test.sh"
  "$REPO/config/tmux/tests/sidebar-watch.test.sh"
  "$REPO/config/tmux/tests/paste-router.test.sh"
)

total_pass=0
total_fail=0
failed_suites=()

for suite in "${SUITES[@]}"; do
  name="$(basename "$suite" .test.sh)"
  [ "$name" = "install" ] || name="${name}"

  if [ ! -x "$suite" ]; then
    printf '\033[31m%-22s SKIP (not executable)\033[0m\n' "$name"
    failed_suites+=("$name")
    total_fail=$((total_fail + 1))
    continue
  fi

  # Output goes to a file, never through a pipe into $( ).
  #
  # A command substitution waits for the pipe to close, not for the process to
  # exit. The tmux suites start a server that inherits stdout and outlives the
  # test that spawned it, so the pipe stayed open and this loop hung — for 30
  # minutes on CI, until the job was cancelled by hand. It never reproduced
  # locally, where a tmux server is usually already running and no new one
  # inherits these descriptors.
  #
  # Redirecting to a file waits only on the suite itself; a lingering grandchild
  # holding the file descriptor cannot block the read.
  out="$(mktemp)"

  # stdin is closed too: a suite that reads from it would otherwise wait
  # forever on a runner with no terminal attached.
  if command -v timeout >/dev/null 2>&1; then
    timeout "${SUITE_TIMEOUT:-300}" "$suite" </dev/null >"$out" 2>&1
    suite_rc=$?
  else
    "$suite" </dev/null >"$out" 2>&1
    suite_rc=$?
  fi

  summary="$(tail -1 "$out")"

  # 124 is timeout(1)'s signal that it killed the suite. Reported explicitly:
  # a hang that shows up as "0 passed" reads like a broken test rather than a
  # suite that never finished.
  if [ "$suite_rc" -eq 124 ]; then
    printf '\033[31m%-22s TIMEOUT after %ss\033[0m\n' "$name" "${SUITE_TIMEOUT:-300}"
    rg -n 'FAIL' "$out" | tail -3
    failed_suites+=("$name")
    total_fail=$((total_fail + 1))
    rm -f "$out"
    continue
  fi
  p="$(printf '%s' "$summary" | sd '^(\d+) passed.*' '$1')"
  f="$(printf '%s' "$summary" | sd '.*, (\d+) failed.*' '$1')"
  [[ "$p" =~ ^[0-9]+$ ]] || p=0
  [[ "$f" =~ ^[0-9]+$ ]] || f=0

  total_pass=$((total_pass + p))
  total_fail=$((total_fail + f))

  if [ "$f" -eq 0 ] && [ "$p" -gt 0 ]; then
    printf '\033[32m%-22s %s\033[0m\n' "$name" "$summary"
  else
    printf '\033[31m%-22s %s\033[0m\n' "$name" "$summary"
    # Which assertion failed, not just how many. A runner that reports a count
    # and nothing else sends you off to re-run the suite by hand to find out
    # what broke — and an intermittent failure may not reproduce when you do.
    rg -A2 'FAIL' "$out" 2>/dev/null | head -12 | sd '^' '      '
    failed_suites+=("$name")
  fi
  rm -f "$out"
done

# --- the Go installer --------------------------------------------------------
# Counted in the same total as the shell suites, so "everything green" means
# every test in the repository rather than only the ones written in bash.
#
# A missing toolchain is a skip, not a failure: install.sh is the installer that
# has to work everywhere, and it needs nothing but bash.
if command -v go >/dev/null 2>&1; then
  go_out="$(cd "$REPO" && go test ./... 2>&1)"
  go_rc=$?
  # `go test` reports per package, not per assertion. Counting packages keeps
  # the total honest rather than inventing an assertion count.
  go_pkgs="$(printf '%s\n' "$go_out" | rg -c '^(ok|FAIL|---)' || echo 0)"
  go_fail="$(printf '%s\n' "$go_out" | rg -c '^(FAIL|--- FAIL)' || echo 0)"
  go_pass=$((go_pkgs - go_fail))

  total_pass=$((total_pass + go_pass))
  total_fail=$((total_fail + go_fail))

  if [ "$go_rc" -eq 0 ]; then
    printf '\033[32m%-22s %d package(s) passed, 0 failed\033[0m\n' "go" "$go_pass"
  else
    printf '\033[31m%-22s %d package(s) passed, %d failed\033[0m\n' "go" "$go_pass" "$go_fail"
    printf '%s\n' "$go_out" | rg '^(FAIL|--- FAIL|\s+\S+_test\.go)' | head -20
    failed_suites+=("go")
  fi
else
  printf '\033[33m%-22s SKIP (go toolchain not installed)\033[0m\n' "go"
fi

# --- the npm packaging -------------------------------------------------------
# Same reasoning as the Go block: one command covers every test in the repo.
# These check what actually gets published — the os/cpu fields are the entire
# delivery mechanism, and getting them wrong ships six binaries to every machine.
if command -v node >/dev/null 2>&1; then
  npm_out="$(cd "$REPO" && node --test npm/cli/lib/*.test.js 2>&1)"
  npm_rc=$?
  # `node --test` reports "ℹ pass N" in its default reporter and "# pass N"
  # under TAP. Both are matched so the count does not silently read as zero if
  # the reporter changes between Node releases.
  npm_pass="$(printf '%s\n' "$npm_out" | rg -o '^[ℹ#] pass (\d+)' -r '$1' | head -1)"
  npm_fail="$(printf '%s\n' "$npm_out" | rg -o '^[ℹ#] fail (\d+)' -r '$1' | head -1)"
  [[ "$npm_pass" =~ ^[0-9]+$ ]] || npm_pass=0
  [[ "$npm_fail" =~ ^[0-9]+$ ]] || npm_fail=0

  total_pass=$((total_pass + npm_pass))
  total_fail=$((total_fail + npm_fail))

  if [ "$npm_rc" -eq 0 ]; then
    printf '\033[32m%-22s %d passed, 0 failed\033[0m\n' "npm-packaging" "$npm_pass"
  else
    printf '\033[31m%-22s %d passed, %d failed\033[0m\n' "npm-packaging" "$npm_pass" "$npm_fail"
    printf '%s\n' "$npm_out" | rg '^not ok|^\s+error:' | head -10
    failed_suites+=("npm-packaging")
  fi
else
  printf '\033[33m%-22s SKIP (node not installed)\033[0m\n' "npm-packaging"
fi

printf '\n%d passed, %d failed' "$total_pass" "$total_fail"
[ "${#failed_suites[@]}" -eq 0 ] || printf ' — failing: %s' "${failed_suites[*]}"
printf '\n'

[ "${#failed_suites[@]}" -eq 0 ]
