---
name: docs-guardian
description: >
  Ensures project documentation (docs/) is always up-to-date before pushing changes to GitHub.
  Automatically detects architectural changes, new modules, API modifications, configuration changes,
  and updates the relevant documentation files accordingly.
  Trigger: PROACTIVELY before any git push, PR creation, or when user asks to update docs.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent
---

# Skill: docs-guardian

## When to Activate

This skill MUST activate **PROACTIVELY** (without being asked) in these scenarios:

1. **Before any `git push`** — check if docs/ needs updating
2. **Before creating a PR** — ensure documentation reflects the changes
3. **After completing a feature/fix** that changes architecture, data models, API contracts, security, testing, or deployment
4. **When the user explicitly asks** to update documentation

This skill works in conjunction with `readme-guardian` — README covers the project overview, while this skill covers the detailed `docs/` folder.

---

## Documentation Structure

The `docs/` folder follows this structure:

```
docs/
├── README.md                    # Index and navigation map
├── architecture/
│   ├── overview.md              # Architecture diagrams, layers, routing, decisions
│   └── patterns.md              # Component patterns, hook patterns, validation, error handling
├── product/
│   ├── overview.md              # Product vision, users, modules
│   ├── features.md              # Feature map with status per module
│   └── invoice-pipeline.md      # Pipeline flow, states, transitions, errors
├── data/
│   ├── api-contracts.md         # Endpoints, request/response types, proxy behavior
│   └── types-reference.md       # TypeScript type definitions, enums, DTOs
├── development/
│   ├── setup.md                 # Environment setup, scripts, IDE config
│   └── workflow.md              # Branch conventions, commits, PRs, git hooks
├── deployment/
│   ├── docker.md                # Dockerfile, build, run, health check
│   ├── ci-cd.md                 # GitHub Actions pipeline, Dependabot
│   └── environments.md          # Environment variables by category
├── security/
│   └── overview.md              # Headers, CSP, validation, sanitization, rate limiting
├── testing/
│   └── strategy.md              # Vitest, Playwright, coverage, mocking
└── guides/
    └── onboarding.md            # New team member guide
```

---

## Pre-Push Checklist

Before pushing or creating a PR, check each category against the changes:

### 1. Architecture changes

```bash
git diff HEAD~1..HEAD --stat | grep -E 'src/(app|components|hooks|lib|context|types)/'
```

| Change | Doc to update |
|--------|--------------|
| New route group or page | `architecture/overview.md` (Routing section) |
| New component directory | `architecture/overview.md` (Components table) |
| New context provider | `architecture/overview.md` (State layer) |
| New architectural pattern | `architecture/patterns.md` |
| Component organization change | `architecture/overview.md` + `architecture/patterns.md` |

### 2. Product changes

```bash
git diff HEAD~1..HEAD --stat | grep -E 'src/components/(invoices|clients|dashboard|settings|empresa)/'
```

| Change | Doc to update |
|--------|--------------|
| New feature or module | `product/features.md` (Feature map) |
| Invoice pipeline change | `product/invoice-pipeline.md` |
| New user-facing functionality | `product/overview.md` (if significant) |
| New invoice state or transition | `product/invoice-pipeline.md` (States + Transitions) |

### 3. Data / API changes

```bash
git diff HEAD~1..HEAD --stat | grep -E 'src/(types|hooks/use-|app/api)/'
```

| Change | Doc to update |
|--------|--------------|
| New API endpoint | `data/api-contracts.md` (Endpoints table) |
| New or modified TypeScript type | `data/types-reference.md` |
| New hook | `data/api-contracts.md` (Hook column in endpoints table) |
| New DTO or mapper | `data/types-reference.md` |
| Proxy behavior change | `data/api-contracts.md` (Proxy section) |

### 4. Development workflow changes

```bash
git diff HEAD~1..HEAD -- package.json .husky/ .eslintrc* tsconfig.json
```

| Change | Doc to update |
|--------|--------------|
| New script | `development/setup.md` (Scripts table) |
| New dev dependency or tool | `development/setup.md` |
| Git hook change | `development/workflow.md` |
| Lint rule change | `development/workflow.md` |

### 5. Deployment changes

```bash
git diff HEAD~1..HEAD -- Dockerfile docker-compose* .github/workflows/ .env.example
```

| Change | Doc to update |
|--------|--------------|
| Dockerfile change | `deployment/docker.md` |
| CI pipeline change | `deployment/ci-cd.md` |
| New env var | `deployment/environments.md` |
| Dependabot config change | `deployment/ci-cd.md` |

### 6. Security changes

```bash
git diff HEAD~1..HEAD -- next.config.ts src/lib/security.ts src/lib/sanitize.ts src/lib/validation/ src/lib/file-validation.ts
```

| Change | Doc to update |
|--------|--------------|
| CSP header change | `security/overview.md` (Headers + CSP sections) |
| New validation schema | `security/overview.md` (Validation table) |
| New sanitization function | `security/overview.md` (Sanitization table) |
| File validation change | `security/overview.md` (File validation table) |

### 7. Testing changes

```bash
git diff HEAD~1..HEAD -- vitest.config.ts playwright.config.ts src/**/__tests__/ e2e/
```

| Change | Doc to update |
|--------|--------------|
| Coverage threshold change | `testing/strategy.md` (Coverage section) |
| New test pattern | `testing/strategy.md` |
| Playwright config change | `testing/strategy.md` |
| New E2E test file | `testing/strategy.md` (E2E section) |

---

## Rules for Updating

1. **Match existing style** — read the document first, maintain tone, Mermaid themes, table formats
2. **Only update what changed** — do NOT rewrite documents that are already accurate
3. **Spanish neutro** — professional, no regional expressions
4. **Mermaid diagrams** — use `%%{init}%%` custom theming, different palettes per diagram
5. **Keep docs/README.md index accurate** — if you add/remove/rename a file, update the index
6. **Update the onboarding guide** if the getting-started process changes

---

## When NOT to Update

- Typo fixes in code (no doc impact)
- CSS/style changes
- Bug fixes that don't change behavior documented
- Test additions (unless changing coverage thresholds or strategy)
- i18n key additions (unless adding a new language)
- Refactors that don't change public interfaces

---

## Workflow

```
Agent thinks before push/PR:
1. What files changed? → git diff --stat
2. Do changes affect documented architecture/data/security/etc?
3. If YES → update relevant docs FIRST, include in commit, THEN push
4. If NO → proceed directly
5. Always verify docs/README.md index is current
```
