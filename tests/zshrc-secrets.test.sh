#!/usr/bin/env bash
# Verifies that ~/.zshrc carries no credentials, so it can be versioned.
#
# Its tool configuration (zoxide, bat, fzf, eza) has no config files of its own
# and lives entirely in this file, so versioning it is the only way to capture
# that setup. Credentials therefore have to live somewhere else.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSHRC="$REPO/home/zshrc"
SECRETS="$HOME/.config/zsh/secrets.zsh"

pass=0
fail=0

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

echo "zshrc-secrets"

assert_eq "the versioned zshrc exists" "yes" \
  "$([ -f "$ZSHRC" ] && echo yes || echo no)"

# --- no credentials, checked two independent ways ----------------------------
# gitleaks found only 2 of the 4 secret-bearing lines in the original file, so
# it is paired with explicit patterns rather than trusted on its own.
scan_dir="$(mktemp -d)"
trap 'rm -rf "$scan_dir"' EXIT
cp "$ZSHRC" "$scan_dir/zshrc.sh" 2>/dev/null
# Judged by exit status, not by grepping the output: gitleaks prints
# "no leaks found" on success, and a naive /leaks found/ match reports that
# clean run as a failure. Exit 0 means clean, 1 means findings.
gitleaks detect --source "$scan_dir" --no-git --redact --no-banner >/dev/null 2>&1
assert_eq "gitleaks finds no credentials" "0" "$?"

assert_eq "no assignment carries a long literal secret" "yes" \
  "$(rg -q '(TOKEN|API_KEY|SECRET|PASSWORD)\s*=\s*"?[A-Za-z0-9_-]{20,}' "$ZSHRC" 2>/dev/null && echo no || echo yes)"

for pat in 'apikey[A-Za-z0-9]{20,}' 'ghp_[A-Za-z0-9]{20,}' 'sk-[A-Za-z0-9]{20,}' '[0-9a-f]{56,}'; do
  assert_eq "no value matching /$pat/" "yes" \
    "$(rg -q "$pat" "$ZSHRC" 2>/dev/null && echo no || echo yes)"
done

# --- secrets are loaded from outside the repo --------------------------------
assert_eq "sources an out-of-repo secrets file" "yes" \
  "$(rg -q 'secrets\.zsh' "$ZSHRC" 2>/dev/null && echo yes || echo no)"

assert_eq "the source is guarded so a missing file does not break the shell" "yes" \
  "$(rg -q '\[ *-[fr] *"?\$\{?HOME.*secrets\.zsh' "$ZSHRC" 2>/dev/null && echo yes || echo no)"

# --- the secrets file itself is never versioned ------------------------------
assert_eq "secrets.zsh is not tracked by git" "0" \
  "$(cd "$REPO" && git ls-files | rg -c 'secrets\.zsh' || echo 0)"

assert_eq "the zsh secrets path is gitignored" "yes" \
  "$(rg -q 'secrets\.zsh|zsh/secrets' "$REPO/.gitignore" 2>/dev/null && echo yes || echo no)"

# --- the split did not lose anything -----------------------------------------
if [ -f "$SECRETS" ]; then
  for v in ENGRAM_CLOUD_TOKEN DOKPLOY_API_KEY; do
    assert_eq "$v still defined in the secrets file" "yes" \
      "$(rg -q "$v" "$SECRETS" 2>/dev/null && echo yes || echo no)"
  done
  assert_eq "the secrets file is not world-readable" "600" \
    "$(stat -f '%OLp' "$SECRETS" 2>/dev/null)"
else
  printf '  \033[33mSKIP\033[0m secrets file checks (%s absent)\n' "$SECRETS"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
