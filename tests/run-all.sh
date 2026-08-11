#!/usr/bin/env bash
# Run every test suite in the repo and summarise the result.
#
# The tmux/yazi suites exercise the *installed* configs under ~/.config, so run
# ./install.sh first on a fresh machine or they will report missing files.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SUITES=(
  "$REPO/tests/install.test.sh"
  "$REPO/tests/launch.test.sh"
  "$REPO/config/tmux/tests/sidebar-toggle.test.sh"
  "$REPO/config/tmux/tests/open-in-work-pane.test.sh"
  "$REPO/config/tmux/tests/yazi-sidebar-config.test.sh"
  "$REPO/config/tmux/tests/statusbar.test.sh"
  "$REPO/config/tmux/tests/status-style.test.sh"
  "$REPO/config/tmux/tests/keybindings.test.sh"
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

  summary="$("$suite" 2>&1 | tail -1)"
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
    failed_suites+=("$name")
  fi
done

printf '\n%d passed, %d failed' "$total_pass" "$total_fail"
[ "${#failed_suites[@]}" -eq 0 ] || printf ' — failing: %s' "${failed_suites[*]}"
printf '\n'

[ "${#failed_suites[@]}" -eq 0 ]
