#!/usr/bin/env bash
# Vendor gstack at the pinned commit and regenerate the adopted skills.
#
# What this installs, and what it deliberately does not
# -----------------------------------------------------
# Upstream's own ./setup plants the whole repo in ~/.claude/skills/gstack, adds
# 54 slash commands, and registers four families of hooks. More than half of
# those skills duplicate something this configuration already has — planning
# (SDD), the design system, memory (engram), docs, security, PDF, release — and
# two skills competing for one trigger is worse than either alone.
#
# So this takes fifteen skills and three binaries, and nothing else.
#
# The split, and why
# ------------------
#   shared/skills/<skill>/SKILL.md   committed. ~255 KB, patched, diffable.
#                                    These are what loads into a session, so a
#                                    change to one should show up in review.
#   third_party/gstack/              gitignored. 42 MB of source plus a Bun
#                                    build plus whatever Chromium Playwright
#                                    downloads. Reproducible from the pin, so
#                                    committing it would only add weight. It is
#                                    third_party/ and not vendor/ because this
#                                    repo is a Go module, and `vendor/` at a
#                                    module root is reserved by the toolchain.
#   ~/.gstack -> third_party/gstack  a stable path in $HOME. The skills call
#                                    their binaries through it, which is what
#                                    lets the generated files be identical
#                                    whatever directory this repo lives in.
#
# Usage:
#   scripts/gstack-sync.sh              clone/checkout, build, regenerate
#   scripts/gstack-sync.sh --no-build   skip the Bun build (skills only, fast)
#   scripts/gstack-sync.sh --check      regenerate nowhere, just report drift
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$REPO/third_party/gstack"
SKILLS="$REPO/shared/skills"
PATCH="$REPO/scripts/gstack-patch.sh"
PIN_FILE="$REPO/GSTACK_PIN"
LINK="$HOME/.gstack"
UPSTREAM="https://github.com/garrytan/gstack.git"

# Keep this list in step with GSTACK_SKILLS in tests/gstack-skills.test.sh —
# that suite fails if a skill named there is not checked in.
GSTACK_SKILLS=(
  browse scrape
  qa qa-only
  careful freeze guard unfreeze
  investigate diagram
  canary benchmark retro
  land-and-deploy
  design-shotgun
)

DO_BUILD=1
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --no-build) DO_BUILD=0 ;;
    --check)    CHECK_ONLY=1; DO_BUILD=0 ;;
    -h|--help)  rg '^#' "$0" | head -30; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m warn\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[31merror\033[0m %s\n' "$1" >&2; exit 1; }

[ -x "$PATCH" ] || die "scripts/gstack-patch.sh is missing or not executable"
[ -f "$PIN_FILE" ] || die "GSTACK_PIN is missing"

PIN="$(rg -o '^[0-9a-f]{40}$' "$PIN_FILE" | head -1)"
[ -n "$PIN" ] || die "GSTACK_PIN does not contain a 40-character commit sha"

for tool in git rg sd; do
  command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

# --- the pinned checkout -------------------------------------------------------
if [ "$CHECK_ONLY" -eq 0 ]; then
  if [ ! -d "$VENDOR/.git" ]; then
    say "cloning gstack into third_party/gstack"
    mkdir -p "$(dirname "$VENDOR")"
    # No --depth: a shallow clone cannot check out an arbitrary pinned sha, and
    # the pin is the whole point. --filter=blob:none keeps it cheap anyway by
    # fetching blobs only for the commit actually checked out.
    git clone --filter=blob:none "$UPSTREAM" "$VENDOR" \
      || die "clone failed"
  fi

  current="$(git -C "$VENDOR" rev-parse HEAD 2>/dev/null || echo none)"
  if [ "$current" != "$PIN" ]; then
    say "checking out $PIN"
    git -C "$VENDOR" fetch --quiet origin || warn "fetch failed, trying the local object store"
    git -C "$VENDOR" checkout --quiet --detach "$PIN" \
      || die "cannot check out $PIN — is the sha in GSTACK_PIN real?"
  fi
fi

[ -d "$VENDOR" ] || die "third_party/gstack is absent — run without --check first"

# --- the stable symlink ------------------------------------------------------
# Created before the build so a partially built tree is still reachable at the
# path the skills use.
if [ "$CHECK_ONLY" -eq 0 ]; then
  if [ -L "$LINK" ]; then
    [ "$(readlink "$LINK")" = "$VENDOR" ] || { rm -f "$LINK"; ln -snf "$VENDOR" "$LINK"; }
  elif [ -e "$LINK" ]; then
    # A real directory here means a full upstream install, or something else
    # entirely. Replacing it would destroy content, so stop and let a human
    # look: the skills will not resolve until this is settled.
    die "$LINK exists and is not a symlink — move it aside, then re-run"
  else
    ln -snf "$VENDOR" "$LINK"
  fi
  say "~/.gstack -> third_party/gstack"
fi

# --- build the runtime -------------------------------------------------------
# Eight of the fifteen skills shell out to the compiled browse binary; without
# it they fail at their first command rather than degrading.
if [ "$DO_BUILD" -eq 1 ]; then
  if command -v bun >/dev/null 2>&1; then
    say "building the runtime (bun install, then compile)"
    ( cd "$VENDOR" && bun install --silent && bun run build ) \
      || warn "the build failed — the skills are still generated, but /browse, /qa, /canary, /benchmark, /scrape, /diagram, /land-and-deploy and /design-shotgun will not run until it succeeds"
  else
    warn "bun is not installed — skipping the build. The browser-backed skills need it: brew install oven-sh/bun/bun"
  fi
fi

# --- regenerate the skills ---------------------------------------------------
say "patching ${#GSTACK_SKILLS[@]} skills into shared/skills/"

changed=0
drifted=0
for s in "${GSTACK_SKILLS[@]}"; do
  src="$VENDOR/$s/SKILL.md"
  if [ ! -f "$src" ]; then
    warn "$s: not present at this pin — skipped"
    continue
  fi

  dest_dir="$SKILLS/$s"
  dest="$dest_dir/SKILL.md"
  tmp="$(mktemp)"

  "$PATCH" "$src" >"$tmp" || { rm -f "$tmp"; warn "$s: patch failed"; continue; }

  # An empty or frontmatter-less result means the filter broke on this file.
  # Writing it would take the skill out of service silently, so refuse.
  if [ ! -s "$tmp" ] || [ "$(head -1 "$tmp")" != "---" ]; then
    rm -f "$tmp"
    warn "$s: patch produced a file with no frontmatter — left untouched"
    continue
  fi

  if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    continue
  fi

  if [ "$CHECK_ONLY" -eq 1 ]; then
    printf '  drift: %s\n' "$s"
    drifted=$((drifted + 1))
    rm -f "$tmp"
    continue
  fi

  mkdir -p "$dest_dir"
  mv "$tmp" "$dest"
  changed=$((changed + 1))
  printf '  updated: %s\n' "$s"
done

if [ "$CHECK_ONLY" -eq 1 ]; then
  if [ "$drifted" -gt 0 ]; then
    die "$drifted skill(s) differ from the pin — run scripts/gstack-sync.sh"
  fi
  say "no drift: every committed skill matches the pin"
  exit 0
fi

if [ "$changed" -eq 0 ]; then
  say "already up to date"
else
  say "$changed skill(s) regenerated — review the diff before committing"
fi
