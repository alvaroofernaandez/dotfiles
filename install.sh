#!/usr/bin/env bash
# Link this repository's configs into $HOME.
#
# Existing files and directories are never deleted: anything in the way is moved
# aside to <path>.bak.<timestamp> before the symlink is created. Re-running is
# safe — links already pointing at this repo are left alone.
#
#   ./install.sh            link everything
#   ./install.sh --dry-run  show what would happen, change nothing
set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run | -n) DRY_RUN=1 ;;
    -h | --help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# source-relative-to-repo : destination-relative-to-HOME
#
# Agent config directories are linked PER PATH, never wholesale: ~/.claude also
# holds .credentials.json and gigabytes of session history, and
# ~/.config/opencode holds node_modules. Linking either one entirely would
# displace all of it.
LINKS=(
  # --- terminal ---
  "config/tmux:.config/tmux"
  "config/yazi:.config/yazi"
  "config/yazi-sidebar:.config/yazi-sidebar"
  "config/ghostty:.config/ghostty"
  "home/tmux.conf:.tmux.conf"

  # --- claude code ---
  "config/claude/CLAUDE.md:.claude/CLAUDE.md"
  "config/claude/RTK.md:.claude/RTK.md"
  "config/claude/sdd-orchestrator.md:.claude/sdd-orchestrator.md"
  "config/claude/MCP-PER-PROJECT.md:.claude/MCP-PER-PROJECT.md"
  "config/claude/settings.json:.claude/settings.json"
  "config/claude/skills:.claude/skills"
  "config/claude/agents:.claude/agents"
  "config/claude/commands:.claude/commands"
  "config/claude/hooks:.claude/hooks"
  "config/claude/prompts:.claude/prompts"

  # --- opencode ---
  "config/opencode/opencode.json:.config/opencode/opencode.json"
  "config/opencode/AGENTS.md:.config/opencode/AGENTS.md"
  "config/opencode/package.json:.config/opencode/package.json"
  "config/opencode/agents:.config/opencode/agents"
  "config/opencode/commands:.config/opencode/commands"
  "config/opencode/plugin:.config/opencode/plugin"
  "config/opencode/plugins:.config/opencode/plugins"
  "config/opencode/profiles:.config/opencode/profiles"
  "config/opencode/prompts:.config/opencode/prompts"
  "config/opencode/skills:.config/opencode/skills"
  "config/opencode-home/skills:.opencode/skills"
)

stamp="$(date +%Y%m%d%H%M%S)"
failed=0

say() { printf '  %-24s %s\n' "$1" "$2"; }

for entry in "${LINKS[@]}"; do
  src="$REPO_ROOT/${entry%%:*}"
  dest="$HOME/${entry##*:}"
  name="${entry##*:}"

  if [ ! -e "$src" ]; then
    echo "install: missing source: $src" >&2
    failed=1
    continue
  fi

  # Already pointing where it should — nothing to do.
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    say "$name" "already linked"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      say "$name" "would back up, then link"
    else
      say "$name" "would link"
    fi
    continue
  fi

  mkdir -p "$(dirname "$dest")"

  # -e is false for a broken symlink, so test -L too or it would survive.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mv "$dest" "$dest.bak.$stamp"
    say "$name" "backed up -> $(basename "$dest").bak.$stamp"
  fi

  ln -s "$src" "$dest"
  say "$name" "linked"
done

[ "$failed" -eq 0 ] || exit 1
