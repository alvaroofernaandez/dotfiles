# Cleanup targets

## Tier 1 — regenerable, delete without asking

```bash
rm -rf ~/Library/Caches/* ~/.cache/*
npm cache clean --force
rm -rf ~/.bun/install/cache
pnpm store prune            # ~/Library/pnpm/store, often 15-20 GB
go clean -modcache
brew cleanup -s --prune=all
```

## Measure (du -sh)

`~/Library/Caches ~/.cache ~/.npm ~/.bun/install/cache ~/Library/pnpm/store go/pkg/mod/cache
~/.cargo/registry ~/Library/Developer/Xcode/DerivedData ~/Library/Developer/CoreSimulator
~/.gradle/caches ~/.colima ~/Library/Containers/com.apple.container ~/.local/share/opencode
~/.Trash "~/Library/Application Support/Steam/steamapps/common" /opt/homebrew /nix`

## Container runtimes on this machine

- Colima profiles (`colima list`); docker context `colima-<profile>`. Default context historically `dory`.
- Apple `container` (dory-engine dind). Trim: `container exec dory-engine sh -c 'fstrim -v /var/lib/docker'`.
- TRIM support check inside guest: `cat /sys/block/vdX/queue/discard_max_bytes` (nonzero = OK).

## Tier 2 — ask first

- Docker images: usually per-commit tags of work images (`ghcr.io/<org>/*`); keep `latest` + its commit tag.
- Colima profiles / Apple container data: may hold running work containers.
- `~/.local/share/opencode/opencode.db` (session history, ~5-7 GB). Rotated `log/2026-*.log` are safe.
- Steam Baldur's Gate 3 (~146 GB), WhatsApp group container (~9 GB).

## Past results

- 2026-08-28: fstrim alone 2.2 → 182 GB free.
- 2026-10-01: deleted container data + profiles + pnpm prune, 2.1 → 72 GB.
- 2026-10-09: Tier 1 + Colima build cache 18.9 GB + fstrim, 4.3 → 45 GB. Removing 15 old image tags freed ~0 B (shared layers).
