---
name: orbstack-health
description: "Trigger: docker no funciona, revisa orbstack, health check docker, restos de colima, docker context. Diagnose OrbStack, Docker context, disk and Colima leftovers."
metadata:
  author: "alvaroofernaandez"
  version: "1.0"
---

## Activation Contract

Load when Docker fails, the user asks for a Docker/OrbStack health check, or there is any suspicion of a second runtime (Colima, Lima, Docker Desktop) on the machine.

## Hard Rules

- Read-only by default: diagnose and report; change nothing without approval.
- If Colima/Lima/ColimaBar traces are found, NEVER remove them automatically: show the exact removal plan (commands, paths, sizes) and wait for confirmation.
- Report only measured values; a check that was not run is reported as "not run".

## Decision Gates

| Check | Healthy | Recommended action if not |
|---|---|---|
| `docker context show` | `orbstack` | `docker context use orbstack` |
| `echo $DOCKER_HOST` | empty | remove it from shell rc files (ask) |
| `orbctl status` | `Running` | `orbctl start` |
| `docker info` | succeeds, `OperatingSystem=OrbStack` | restart OrbStack, re-check |
| `command -v colima limactl` | none | removal plan (ask) |
| `~/.colima`, `~/.lima`, ColimaBar.app, login items | absent | removal plan with `du -sh` sizes (ask) |
| Contexts `colima*` in `docker context ls` | absent | `docker context rm <name>` (ask) |
| `df -h /` free | > 20 GiB | load `docker-space-optimizer` |
| Build cache in `docker system df` | < 10 GB | load `docker-space-optimizer` |

## Execution Steps

1. Run: `docker context ls`, `docker context show`, `docker info`, `docker system df`, `orbctl status`, `orbctl version`, `df -h /`.
2. Run: `ps aux | rg -i 'colima|lima|orbstack' | rg -v ' rg '`, `command -v colima limactl`, `rg -n -i 'colima|DOCKER_HOST' ~/.zshrc ~/.zprofile ~/.bashrc ~/.profile`, `brew list | rg -i 'colima|lima'`.
3. Measure OrbStack data: `du -sh ~/Library/Group\ Containers/HUAQ24HBR6.dev.orbstack/data`.
4. Evaluate every row of the decision table.

## Output Contract

Return one table: Check | Status (OK / WARN / FAIL / not run) | Measured value | Recommended action. Then, if any Colima trace exists, the removal plan awaiting confirmation.

## References

- `../docker-space-optimizer/SKILL.md` — when space checks fail.
