#!/usr/bin/env bash
# Tests for install.sh. Every run happens inside a throwaway $HOME, so the real
# dotfiles of whoever runs the suite are never touched.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$REPO/install.sh"

pass=0
fail=0
SANDBOX=""

cleanup() { [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"; }
trap cleanup EXIT

ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31mFAIL\033[0m %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fail=$((fail + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || ko "$1" "$2" "$3"; }

fresh_home() {
  [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"
  SANDBOX="$(mktemp -d)"
}

run_install() { HOME="$SANDBOX" bash "$INSTALL" "$@" 2>&1; }

# Backups live in a quarantine directory, never beside the original.
BACKUP_ROOT_NAME=".dotfiles-backup"
count_backups() {
  [ -d "$SANDBOX/$BACKUP_ROOT_NAME" ] || { echo 0; return; }
  find "$SANDBOX/$BACKUP_ROOT_NAME" -mindepth 2 -maxdepth 4 \( -type f -o -type d \) 2>/dev/null \
    | rg -v "^$SANDBOX/$BACKUP_ROOT_NAME/[^/]+$" | head -100 | wc -l | tr -d ' '
}
# Path of a backed-up item, whatever timestamp it got.
backup_of() { find "$SANDBOX/$BACKUP_ROOT_NAME" -maxdepth 3 -path "*/$1" 2>/dev/null | head -1; }

echo "install"

# --- clean machine -----------------------------------------------------------
fresh_home
run_install >/dev/null

assert_eq "links ~/.config/tmux to the repo" \
  "$REPO/config/tmux" "$(readlink "$SANDBOX/.config/tmux")"
assert_eq "links ~/.config/yazi to the repo" \
  "$REPO/config/yazi" "$(readlink "$SANDBOX/.config/yazi")"
assert_eq "links ~/.config/yazi-sidebar to the repo" \
  "$REPO/config/yazi-sidebar" "$(readlink "$SANDBOX/.config/yazi-sidebar")"
assert_eq "links ~/.config/ghostty to the repo" \
  "$REPO/config/ghostty" "$(readlink "$SANDBOX/.config/ghostty")"
assert_eq "links ~/.tmux.conf to the repo" \
  "$REPO/home/tmux.conf" "$(readlink "$SANDBOX/.tmux.conf")"
assert_eq "creates no backups on a clean machine" "0" "$(count_backups)"

# The link must actually resolve to readable content, not just exist.
assert_eq "linked config is readable through the symlink" "yes" \
  "$([ -r "$SANDBOX/.config/tmux/sidebar-toggle.sh" ] && echo yes || echo no)"

# --- existing config is preserved, never destroyed ---------------------------
fresh_home
mkdir -p "$SANDBOX/.config/tmux"
printf 'MINE\n' > "$SANDBOX/.config/tmux/precious.conf"
printf 'MY TMUX\n' > "$SANDBOX/.tmux.conf"
run_install >/dev/null

assert_eq "replaces the existing directory with the link" \
  "$REPO/config/tmux" "$(readlink "$SANDBOX/.config/tmux")"

backup_dir="$(backup_of '.config/tmux')"
assert_eq "backs up the previous directory" "yes" \
  "$([ -n "$backup_dir" ] && echo yes || echo no)"
assert_eq "backup keeps the original contents intact" \
  "MINE" "$(cat "$backup_dir/precious.conf" 2>/dev/null)"
assert_eq "backs up an existing regular file" \
  "MY TMUX" "$(cat "$(backup_of '.tmux.conf')" 2>/dev/null)"

# Backups must never land inside a directory the tools scan: Claude Code reads
# every entry under ~/.claude/skills, so a "skills/ship.bak.<stamp>" would be
# loaded as a second, duplicate skill.
assert_eq "quarantines backups outside the destination tree" "0" \
  "$(find "$SANDBOX/.config" "$SANDBOX/.claude" "$SANDBOX/.opencode" -name '*.bak.*' 2>/dev/null | wc -l | tr -d ' ')"

# --- idempotency -------------------------------------------------------------
fresh_home
run_install >/dev/null
before="$(count_backups)"
out="$(run_install)"
assert_eq "second run creates no new backups" "$before" "$(count_backups)"
assert_eq "second run still leaves a valid link" \
  "$REPO/config/tmux" "$(readlink "$SANDBOX/.config/tmux")"
assert_eq "second run reports links as already in place" "yes" \
  "$(printf '%s' "$out" | rg -qi 'already|ok|skip' && echo yes || echo no)"

# --- dry run -----------------------------------------------------------------
fresh_home
mkdir -p "$SANDBOX/.config/tmux"
printf 'UNTOUCHED\n' > "$SANDBOX/.config/tmux/precious.conf"
run_install --dry-run >/dev/null

assert_eq "dry-run creates no symlink" "no" \
  "$([ -L "$SANDBOX/.config/tmux" ] && echo yes || echo no)"
assert_eq "dry-run creates no backups" "0" "$(count_backups)"
assert_eq "dry-run leaves existing files alone" \
  "UNTOUCHED" "$(cat "$SANDBOX/.config/tmux/precious.conf" 2>/dev/null)"
# Capture first, then match: piping straight into `rg -q` makes it exit on the
# first hit, and the SIGPIPE that kills install.sh trips pipefail.
dry_out="$(run_install --dry-run)"
assert_eq "dry-run still reports what it would do" "yes" \
  "$(printf '%s' "$dry_out" | rg -qi 'tmux' && echo yes || echo no)"

# --- agent configs are linked per-path, never wholesale ----------------------
# ~/.claude holds credentials and gigabytes of session history alongside the
# configs worth versioning, so only individual subpaths may be linked.
fresh_home
mkdir -p "$SANDBOX/.claude/projects" "$SANDBOX/.claude/skills/some-vendor-skill"
printf 'SECRET\n' > "$SANDBOX/.claude/.credentials.json"
printf 'log\n' > "$SANDBOX/.claude/projects/session.jsonl"
printf 'vendor\n' > "$SANDBOX/.claude/skills/some-vendor-skill/SKILL.md"

# Pre-seed an own skill as a real directory: this is the case that produced the
# duplicate-skill bug, since it forces a backup right inside the scanned dir.
preseeded="$(basename "$(find "$REPO/shared/skills" -maxdepth 1 -mindepth 1 -type d | head -1)")"
mkdir -p "$SANDBOX/.claude/skills/$preseeded"
printf 'old copy\n' > "$SANDBOX/.claude/skills/$preseeded/SKILL.md"

run_install >/dev/null

# Skills are linked ONE BY ONE, never as a directory. The skills directories
# also hold marketplace skills that this repo does not version; replacing the
# directory with a link would take all of them out of service.
first_skill="$(basename "$(find "$REPO/shared/skills" -maxdepth 1 -mindepth 1 -type d | head -1)")"

assert_eq "links each own skill into ~/.claude/skills" \
  "$REPO/shared/skills/$first_skill" "$(readlink "$SANDBOX/.claude/skills/$first_skill")"
assert_eq "links each own skill into ~/.config/opencode/skills" \
  "$REPO/shared/skills/$first_skill" "$(readlink "$SANDBOX/.config/opencode/skills/$first_skill")"
assert_eq "links each own skill into ~/.opencode/skills" \
  "$REPO/shared/skills/$first_skill" "$(readlink "$SANDBOX/.opencode/skills/$first_skill")"

assert_eq "links every own skill, not just one" "yes" \
  "$([ "$(find "$SANDBOX/.claude/skills" -maxdepth 1 -type l | wc -l | tr -d ' ')" \
      -eq "$(find "$REPO/shared/skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')" ] && echo yes || echo no)"

assert_eq "never replaces the skills directory itself" "real directory" \
  "$([ -L "$SANDBOX/.claude/skills" ] && echo symlink || echo "real directory")"

# Regression: a backup left here would be loaded as a duplicate skill.
assert_eq "no backup pollutes the skills directory" "0" \
  "$(find "$SANDBOX/.claude/skills" -maxdepth 1 -name '*.bak.*' 2>/dev/null | wc -l | tr -d ' ')"

# The whole point: marketplace skills must keep working after install.
assert_eq "leaves third-party skills untouched" \
  "vendor" "$(cat "$SANDBOX/.claude/skills/some-vendor-skill/SKILL.md" 2>/dev/null)"

assert_eq "keeps tool-specific commands separate" "yes" \
  "$([ "$(readlink "$SANDBOX/.claude/commands")" != "$(readlink "$SANDBOX/.config/opencode/commands")" ] && echo yes || echo no)"

assert_eq "links ~/.claude/agents" \
  "$REPO/config/claude/agents" "$(readlink "$SANDBOX/.claude/agents")"
assert_eq "links ~/.claude/CLAUDE.md" \
  "$REPO/config/claude/CLAUDE.md" "$(readlink "$SANDBOX/.claude/CLAUDE.md")"
assert_eq "links ~/.claude/settings.json" \
  "$REPO/config/claude/settings.json" "$(readlink "$SANDBOX/.claude/settings.json")"

assert_eq "never links ~/.claude itself" "real directory" \
  "$([ -L "$SANDBOX/.claude" ] && echo symlink || echo "real directory")"
assert_eq "leaves credentials untouched" \
  "SECRET" "$(cat "$SANDBOX/.claude/.credentials.json" 2>/dev/null)"
assert_eq "leaves session history untouched" \
  "log" "$(cat "$SANDBOX/.claude/projects/session.jsonl" 2>/dev/null)"

assert_eq "links ~/.config/opencode/agents" \
  "$REPO/config/opencode/agents" "$(readlink "$SANDBOX/.config/opencode/agents")"
assert_eq "links ~/.config/opencode/opencode.json" \
  "$REPO/config/opencode/opencode.json" "$(readlink "$SANDBOX/.config/opencode/opencode.json")"
assert_eq "never links ~/.config/opencode itself" "real directory" \
  "$([ -L "$SANDBOX/.config/opencode" ] && echo symlink || echo "real directory")"

# node_modules living beside the linked configs must survive.
fresh_home
mkdir -p "$SANDBOX/.config/opencode/node_modules"
printf 'dep\n' > "$SANDBOX/.config/opencode/node_modules/marker"
run_install >/dev/null
assert_eq "leaves opencode node_modules in place" \
  "dep" "$(cat "$SANDBOX/.config/opencode/node_modules/marker" 2>/dev/null)"

# --- missing source ----------------------------------------------------------
fresh_home
out="$(HOME="$SANDBOX" REPO_ROOT="$SANDBOX/not-a-repo" bash "$INSTALL" 2>&1)"
rc=$?
assert_eq "fails when the source tree is missing" \
  "nonzero" "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)"
assert_eq "says which path was missing" "yes" \
  "$(printf '%s' "$out" | rg -qi 'not-a-repo|missing|no such' && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
