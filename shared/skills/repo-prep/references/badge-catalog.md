# Badge catalog — shields.io for house-style READMEs

All badges use the `static badge` endpoint:

```
https://img.shields.io/badge/<LABEL>-<MESSAGE>-<COLOR>?logo=<slug>&logoColor=white&style=flat
```

For a single-segment badge (no separate label), use `<MESSAGE>-<COLOR>`:
`visibility-private-red` renders one pill reading "visibility private".

## URL encoding (critical — wrong encoding = broken badge)

| Character in text | Encode as |
|---|---|
| space | `%20` |
| `+` (plus sign) | `%2B` |
| `-` (literal dash in text) | `--` |
| `_` (literal underscore) | `__` |
| `&` | `%26` |

Example: "Markdown + Mermaid" → `Markdown%20%2B%20Mermaid`.

## Color conventions

| Role | Color value | When |
|---|---|---|
| Private visibility | `red` | `visibility-private` badge, always first for internal repos |
| Factual category | `22c55e` (green) | sector, modelo, estado, trazabilidad — verifiable facts |
| Type / classification | `6366f1` (indigo) | knowledge-base, decisiones, onboarding |
| Type (alt) | `3268B4` (blue) | `tipo-B2B`, audience/segment classification |
| Format / meta | `1f6feb` (blue) | formato, doc SLA |
| Tech badge | brand hex (below) | framework/runtime/db with its logo |

## Tech badge reference (brand hex + logo slug)

| Tech | Hex | logo slug |
|---|---|---|
| Next.js | `000000` | `next.js` |
| React | `61DAFB` | `react` |
| NestJS | `E0234E` | `nestjs` |
| TypeScript | `3178C6` | `typescript` |
| Node.js | `5FA04E` | `node.js` |
| Python | `3776AB` | `python` |
| Go | `00ADD8` | `go` |
| PostgreSQL | `4169E1` | `postgresql` |
| Redis | `DC382D` | `redis` |
| RabbitMQ | `FF6600` | `rabbitmq` |
| Docker | `2496ED` | `docker` |
| Turborepo | `EF4444` | `turborepo` |
| Prisma | `2D3748` | `prisma` |
| Drizzle | `C5F74F` | `drizzle` |
| Tailwind CSS | `06B6D4` | `tailwindcss` |
| Astro | `BC52EE` | `astro` |
| Clerk | `6C47FF` | `clerk` |
| GitHub | `181717` | `github` |
| Markdown | `000000` | `markdown` |

`logoColor=white` reads well on every dark/brand hex above; drop it (or use `black`) for
light backgrounds like Drizzle's `C5F74F`.

## Row composition

- **Row 1 (3–6 badges)**: the headline stack (product repos) OR visibility+format+status
  (docs repos). Most important first.
- **Row 2 (2–4 badges)**: factual category badges (green) + one type badge (indigo/blue).
- Separate the two rows with a blank line inside the `<div align="center">` block so they
  wrap onto two visual lines.
