---
name: mac-disk-cleanup
description: "Trigger: liberar espacio, disco lleno, limpiar caches, free disk space, docker ocupa mucho. Reclaim macOS disk space safely: caches, build artifacts, OrbStack Docker data."
metadata:
  author: "alvaroofernaandez"
  version: "1.0"
---

## Activation Contract

Load when the user asks to free disk space on this Mac, says the disk is full, or asks to clean caches or Docker data.

## Hard Rules

- Measure free space (`df -h /System/Volumes/Data`) BEFORE and AFTER; report both.
- Regenerable caches (Tier 1) need no confirmation. Everything else needs explicit user approval, item by item.
- NEVER delete: Docker images/volumes/containers, `~/.local/share/opencode/opencode.db`, Steam games, WhatsApp data, without asking.
- Docker runs only on OrbStack (Colima removed 2026-11-02). Delegate all Docker cleanup to the `docker-space-optimizer` skill; never install or start Colima.
- zsh does not word-split variables: write `docker --context X ...` literally, never `$C rmi`.
- Report the active docker context at the end (must be `orbstack`).
- Before deleting images, list them (`repo:tag`, size, age) and recommend keeping the current/`latest` tag.

## Decision Gates

| Finding | Action |
|---|---|
| Tier 1 caches | Delete directly |
| Docker build cache / images | Load `docker-space-optimizer` |
| Old image tags / big apps | List + recommend + ask |

## Execution Steps

1. Baseline `df`; measure paths in `references/targets.md` with `du -sh`; run `docker context ls`, `docker system df`.
2. Tier 1: run the cache commands in `references/targets.md`.
3. Docker: follow `docker-space-optimizer` (safe prunes via its `scripts/cleanup.sh`; OrbStack's sparse disk shrinks on its own, no fstrim).
4. Present Tier 2 candidates (images, big dirs) as a table with sizes; delete only what the user approves.
5. Final `df`; note that shared image layers may free ~0 B even when many tags are removed.

## Output Contract

Return: before/after free space, what was deleted with sizes, what was left untouched and why, the remaining biggest consumers, and the active docker context.

## References

- `references/targets.md` — paths, cleanup commands, and history of past passes.
- `../docker-space-optimizer/SKILL.md` — Docker/OrbStack cleanup.
