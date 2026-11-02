---
name: orbstack-docker
description: "Trigger: docker, docker compose, buildx, contenedor, imagen, levantar servicios, docker run/exec. Run all Docker work against OrbStack, the only runtime."
metadata:
  author: "alvaroofernaandez"
  version: "1.0"
---

## Activation Contract

Load for any Docker task on this Mac: running or building images, containers, Compose stacks, Buildx, `docker exec`, logs, or setting up/repairing the Docker environment.

## Hard Rules

- OrbStack is the ONLY permitted runtime. Never use, install or recommend Colima, Lima, Docker Desktop or Podman.
- Check `docker context show` before operating; if it is not `orbstack`, run `docker context use orbstack`.
- Never set `DOCKER_HOST`; the context is the single source of truth.
- Kubernetes stays disabled unless the user explicitly asks for it.
- Stopping containers is safe; `docker compose down -v`, `docker rm -v` or deleting volumes needs explicit confirmation.
- amd64 images run natively via Rosetta on the `orbstack` builder; do not create extra emulation builders unless a build fails without one.

## Decision Gates

| Situation | Command |
|---|---|
| Start a stack | `docker compose up -d` (add `--build` after code changes) |
| Stop a stack, keep data | `docker compose down` |
| Build an image | `docker buildx build --tag <app>:<tag> --load .` → load `docker-build-optimized` |
| Shell into a container | `docker exec -it <name> sh` |
| Docker misbehaves / unsure | `docker info`, `docker compose version`, `docker buildx version`, then `orbstack-health` |
| Low disk space | `docker-space-optimizer` |

## Execution Steps

1. `docker context show` → switch to `orbstack` if needed.
2. If the environment is in doubt: `orbctl status`, `docker info`.
3. Run the task with `docker`, `docker compose` or `docker buildx`.
4. After configuring or repairing the environment, prove it with `docker run --rm hello-world`.

## Output Contract

Return the commands run, their relevant output, the active context, and the state of affected containers (`docker compose ps` or `docker ps`).

## References

- `../orbstack-health/SKILL.md` — diagnosis.
- `../docker-build-optimized/SKILL.md` — builds.
- `../docker-space-optimizer/SKILL.md` — disk space.
