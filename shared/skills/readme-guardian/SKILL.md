---
name: readme-guardian
description: >
  Ensures the README.md is always up-to-date before pushing changes to GitHub.
  Automatically detects new features, dependencies, scripts, config changes, and
  architectural modifications, then updates the README accordingly.
  Trigger: PROACTIVELY before any git push, PR creation, or when user asks to update docs.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent
---

# Skill: readme-guardian

## When to Activate

This skill MUST activate **PROACTIVELY** (without being asked) in these scenarios:

1. **Before any `git push`** — check if README needs updating
2. **Before creating a PR** — ensure README reflects the changes in the PR
3. **After completing a feature/fix** that changes architecture, dependencies, scripts, or config
4. **When the user explicitly asks** to update docs, README, or documentation

---

## Core Principle

The README is the **first thing a new team member reads**. If it's outdated, it's worse than having no README at all — it actively misleads. Every push to a shared repository MUST leave the README accurate.

---

## Pre-Push Checklist

Before pushing or creating a PR, run this checklist:

### 1. Dependency Changes

```bash
git diff HEAD~1..HEAD -- package.json pnpm-lock.yaml yarn.lock | head -100
```

Check for:
- New dependencies added → Add to tech stack table
- Major version bumps → Update version numbers
- Removed dependencies → Remove from README
- New dev tools → Add to relevant section

### 2. Script Changes

```bash
git diff HEAD~1..HEAD -- package.json | grep '"scripts"' -A 50
```

Check for:
- New scripts → Add to scripts table
- Renamed scripts → Update references
- Removed scripts → Remove from table

### 3. Environment Variable Changes

```bash
git diff HEAD~1..HEAD -- .env.example src/lib/env.ts
```

Check for:
- New env vars → Add to env vars table with description
- Removed env vars → Remove from table
- Changed defaults → Update documentation

### 4. Architectural Changes

```bash
# New directories
git diff HEAD~1..HEAD --stat | grep -E '^\s*src/.*/' | head -20

# New route groups
git diff HEAD~1..HEAD --stat | grep 'app/' | head -20

# New components/hooks
git diff HEAD~1..HEAD --stat | grep -E '(components|hooks)/' | head -20
```

Check for:
- New directories or modules → Update project structure tree
- New route groups → Update routing section
- New component categories → Update component organization
- New hooks → Update hooks listing

### 5. Configuration Changes

```bash
git diff HEAD~1..HEAD -- next.config.ts Dockerfile docker-compose.yml .github/workflows/ vitest.config.ts playwright.config.ts tsconfig.json
```

Check for:
- Docker changes → Update Docker section
- CI changes → Update CI/CD section
- Build config → Update relevant sections
- Test config → Update testing section

### 6. Security Changes

```bash
git diff HEAD~1..HEAD -- src/lib/security.ts src/lib/sanitize.ts src/lib/validation/ next.config.ts | grep -E '(CSP|header|security|validation)' | head -20
```

Check for:
- New security headers → Update security table
- New validation schemas → Mention in security section
- CSP changes → Update security section

---

## How to Update

### Rules

1. **Match the existing style** — read the current README first, maintain tone, formatting, emoji usage
2. **Only update what changed** — do NOT rewrite sections that are already accurate
3. **Keep it in Spanish neutro** — professional, no regional slang, no informal expressions
4. **Update metrics** if they changed significantly (file counts, component counts, etc.)
5. **Mermaid diagrams** — update if the architecture, flow, or pipeline changed
6. **Tables** — keep them aligned and complete
7. **Do NOT add fluff** — every line must be useful to a developer joining the team

### What to Update (by change type)

| Change Type | README Sections to Update |
|------------|--------------------------|
| New dependency | Stack tecnológico table |
| New script | Scripts disponibles table |
| New env var | Variables de entorno tables |
| New component dir | Estructura del proyecto tree |
| New hook | Estructura del proyecto tree, hooks count in metrics |
| Architecture change | Arquitectura diagram, Flujo de datos diagram |
| Auth change | Autenticación section + diagram |
| Pipeline change | Pipeline de facturas section + state diagram |
| Docker change | Docker section |
| CI change | CI/CD section + diagram |
| Security change | Seguridad table |
| i18n change | Internacionalización section |
| Test changes | Testing section, coverage targets |

### Metrics to Keep Current

After significant changes, recount:

```bash
# TypeScript files
find src -name "*.ts" -o -name "*.tsx" | wc -l

# Components
find src/components -name "*.tsx" | wc -l

# Hooks
find src/hooks -maxdepth 1 -name "use-*.ts" | wc -l

# Tests
find src -path "*__tests__*" -name "*.test.*" | wc -l

# Translation keys (approximate)
cat src/messages/es.json | grep -c '":"'
```

---

## Anti-Patterns

- ❌ Pushing without checking if README is still accurate
- ❌ Adding a dependency without documenting it
- ❌ Creating a new module/directory without updating the structure tree
- ❌ Changing env vars without updating the table
- ❌ Rewriting the entire README when only one section changed
- ❌ Adding placeholder text like "TODO" or "coming soon"
- ❌ Using regional slang or informal language
- ❌ Outdated metrics (file counts, component counts)
- ❌ Mermaid diagrams that no longer reflect reality

---

## Workflow Example

```
User: "Sube los cambios y haz PR"

Agent thinks:
1. What files changed? → git diff --stat
2. Do any changes affect README sections? → Check against checklist
3. If YES → Update README FIRST, then commit README update, then push/PR
4. If NO → Proceed with push/PR directly
```

---

## When NOT to Update

- Typo fixes in code (no architectural impact)
- Code refactors that don't change public API or structure
- Test additions that don't change coverage thresholds
- Translation key additions (unless significantly changing the count)
- Style/CSS changes
- Bug fixes in existing features (unless they reveal a documentation error)

---

## Integration with CLAUDE.md

Add this to the project or global CLAUDE.md skills table:

```markdown
| Pushing code, creating PRs, updating documentation | readme-guardian |
```

This ensures the skill activates automatically before any push or PR operation.
