---
name: mac-disk-cleanup
description: "Trigger: liberar espacio, disco lleno, limpiar caches, free disk space, docker/colima ocupa mucho. Reclaim macOS disk space safely: caches, build cache, fstrim."
metadata:
  author: "alvaroofernaandez"
  version: "1.0"
---

## Activation Contract

Load when the user asks to free disk space on this Mac, says the disk is full, or asks to clean caches, Docker images, or Colima/container VMs.

## Hard Rules

- Measure free space (`df -h /System/Volumes/Data`) BEFORE and AFTER; report both.
- Regenerable caches (Tier 1) need no confirmation. Everything else needs explicit user approval, item by item.
- NEVER delete: Docker images/volumes/containers, Colima profiles, `~/.local/share/opencode/opencode.db`, Steam games, WhatsApp data, without asking.
- Every prune inside a VM MUST be followed by `fstrim`; sparse disk images never shrink otherwise.
- zsh does not word-split variables: write `docker --context X ...` literally, never `$C rmi`.
- Never run `colima start` silently: it switches the docker context. Report the active context at the end.
- Before deleting images, list them (`repo:tag`, size, age) and recommend keeping the current/`latest` tag.

## Decision Gates

| Finding | Action |
|---|---|
| Tier 1 caches | Delete directly |
| Build cache in a VM | `builder prune -af` + fstrim (no confirmation; regenerable) |
| `docker system df` ≪ `du -sh ~/.colima` | Sparse bloat → fstrim only |
| Old image tags / unused profiles / big apps | List + recommend + ask |
| VM stopped | Ask before starting it to trim |

## Execution Steps

1. Baseline `df`; measure paths in `references/targets.md` with `du -sh`; run `docker context ls`, `colima list`, `container list -a`.
2. Tier 1: run the cache commands in `references/targets.md`.
3. Per running Colima profile P: `docker --context colima-P system df`, `docker --context colima-P builder prune -af`, `colima ssh -p P -- sudo fstrim -av`.
4. Apple `container` dind if present: `container exec dory-engine sh -c 'fstrim -v /var/lib/docker'`.
5. Present Tier 2 candidates (images, profiles, big dirs) as a table with sizes; delete only what the user approves; then fstrim again.
6. Final `df`; note that shared image layers may free ~0 B even when many tags are removed.

## Output Contract

Return: before/after free space, what was deleted with sizes, what was left untouched and why, the remaining biggest consumers, and the active docker context.

## References

- `references/targets.md` — paths, cleanup commands, and history of past passes.
