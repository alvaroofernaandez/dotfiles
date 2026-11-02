---
name: docker-space-optimizer
description: "Trigger: docker ocupa mucho, liberar espacio docker, build cache, prune, docker disk usage. Diagnose and reclaim OrbStack Docker space safely."
metadata:
  author: "alvaroofernaandez"
  version: "1.0"
---

## Activation Contract

Load when Docker images, build cache, volumes or OrbStack's disk use too much space, after large builds, or when free space on `/` is low.

## Hard Rules

- OrbStack is the only runtime. Confirm `docker context show` is `orbstack` before any prune; otherwise stop and switch.
- Measure BEFORE and AFTER, and report the difference.
- Safe cleanup needs no confirmation: `docker container prune -f`, `docker image prune -f`, `docker builder prune -af`.
- Destructive cleanup (`docker system prune -af --volumes`, `docker volume rm/prune`, `docker image prune -a`, `docker rmi`) runs ONLY after listing exactly what will be removed, with sizes, and getting explicit approval.
- Measure OrbStack's real usage at `~/Library/Group Containers/HUAQ24HBR6.dev.orbstack/data` (`~/.orbstack` is only config).
- `orbctl compact` does not exist in OrbStack 2.x; `data.img` is sparse and shrinks automatically. Never invent a compaction step.

## Decision Gates

| Finding | Action |
|---|---|
| Build cache large | Safe cleanup (script) |
| Dangling images / stopped containers | Safe cleanup (script) |
| Unused tagged images | List `repo:tag`, size, age → ask |
| Unused volumes | List name, size, owning compose project → ask; never prune DB volumes silently |
| Context ≠ orbstack | `docker context use orbstack`, re-measure |

## Execution Steps

1. Diagnose: `df -h /`, `docker system df`, `docker system df -v`, `du -sh ~/Library/Group\ Containers/HUAQ24HBR6.dev.orbstack/data`.
2. Run `scripts/cleanup.sh` (checks context, safe prunes, compact if available, before/after report).
3. If more space is needed, present destructive candidates as a table and wait for approval.
4. Re-measure with step 1 commands.

## Output Contract

Return a table: free space on `/` before/after, OrbStack data size before/after, total reclaimed, what was removed, what was kept and why.

## References

- `scripts/cleanup.sh` — safe cleanup with before/after report.
