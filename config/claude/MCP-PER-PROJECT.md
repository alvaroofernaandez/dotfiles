# MCP Servers — Per-Project Setup

Global scope now contains **only HTTP servers** (zero local RAM cost) plus `engram` via plugin.
All stdio servers were moved out of global scope on 2026-08-04 because each one costs
~80-125 MB of RAM **per Claude Code session**.

## Current global config

| Server | Type | Local RAM |
| ------ | ---- | --------- |
| context7 | http | 0 MB |
| engram | plugin (`engram@engram`) | ~13 MB |

`strava` was removed from global scope on 2026-08-04. It is an HTTP server (zero RAM cost),
so this was purely to reduce tool-listing noise in every session. Re-add it wherever needed:

```bash
claude mcp add strava -s project -t http https://mcp.strava.com/mcp
```

## Re-adding a server to a specific project

Run from the project root. Scope `project` writes to `.mcp.json` (committable, shared with the team).
Use scope `local` instead if you want it only on this machine.

```bash
# UI components — frontend projects
claude mcp add magicui -s project -- npx -y @magicuidesign/mcp@latest

# Image generation
claude mcp add nano-banana-pro -s project -- npx -y @rafarafarafa/nano-banana-pro-mcp@latest

# Transactional email
claude mcp add resend -s project -- npx -y resend-mcp

# Payments
claude mcp add stripe -s project -- npx -y @stripe/mcp

# Code review knowledge graph
claude mcp add code-review-graph -s project -- uvx code-review-graph serve
```

Verify with `claude mcp list`.

## RAM cost reference (measured 2026-08-04)

| Server | Cost per session |
| ------ | ---------------- |
| code-review-graph | 125 MB |
| stripe | 86 MB |
| resend | 83 MB |
| magicui | 80 MB |
| nano-banana-pro | 80 MB |

Rule of thumb: every stdio MCP server multiplies its cost by the number of concurrent
Claude Code sessions. Two sessions with five stdio servers = ~900 MB.

## Removed permanently

- `magic` (@21st-dev/magic) — broken, API keys were reset upstream, never started.
- `engram` global entry — was duplicated with the `engram@engram` plugin, spawning two
  identical servers per session.

## Backups

Original configs: `~/.claude/backups/*.20260804-200145.bak`
