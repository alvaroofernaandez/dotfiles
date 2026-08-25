#!/usr/bin/env bash
# Scaffold a new PDF report project.
# Usage: init.sh <project-dir> [--people person-1,person-2]
set -euo pipefail

SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${1:?usage: init.sh <project-dir> [--people a,b,c]}"
shift || true
PEOPLE=""
[[ "${1:-}" == "--people" ]] && PEOPLE="$2"

mkdir -p "$DIR/.agents"
cp "$SKILL/assets/template.html" "$DIR/informe.html"
cp "$SKILL/scripts/render.mjs" "$DIR/render.mjs"
cp "$SKILL/scripts/build-assets.py" "$DIR/build-assets.py"
cp "$SKILL/references/DESIGN.template.md" "$DIR/.agents/DESIGN.md"

cd "$DIR"
uvx --from pillow python build-assets.py . ${PEOPLE:+--people "$PEOPLE"}
npm init -y >/dev/null 2>&1
npm i playwright >/dev/null 2>&1

echo
echo "Ready in $DIR"
echo "  1. Edit informe.html (structure only: never touch the <style> block)"
echo "  2. node render.mjs"
echo "  3. Every guard must read 'none' before you ship"
