---
name: init-project
description: >
  Bootstraps a new project with complete documentation, README, .agents, CLAUDE.md, AGENTS.md,
  .gitignore, git hooks, and utility scripts. Run with /init-project to set up everything.
  Trigger: When user runs /init-project or asks to initialize/bootstrap a new project.
user-invocable: true
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent
---

# Skill: init-project

## When to Use

Activate when the user:
- Runs `/init-project`
- Says "inicializa el proyecto", "bootstrap", "configura todo", "prepara el repo"
- Starts a new project from scratch

---

## What It Does

Sets up the FULL project infrastructure in one command:

1. **README.md** — Professional, with Mermaid diagrams, emojis, complete sections
2. **docs/** — 8-folder documentation structure with 15+ documents
3. **.agents/** — Skills and personas for AI agents
4. **AGENTS.md** — Auto-generated skill index
5. **.claude/settings.local.json** — Project-level Claude permissions
6. **CLAUDE.md** (project) — Project-specific conventions (if missing)
7. **.gitignore** — Comprehensive ignore rules
8. **.husky/** — Git hooks (pre-commit + pre-push)
9. **scripts/** — Utility scripts (sync-skills, update-docs)

---

## Execution Steps

### Step 1: Detect Project Context

Before creating anything, analyze the project:

```bash
# Detect package manager
ls package.json pnpm-lock.yaml yarn.lock package-lock.json bun.lockb 2>/dev/null

# Detect framework
grep -l "next\|react\|vue\|angular\|svelte\|astro" package.json 2>/dev/null

# Detect language
ls tsconfig.json pyproject.toml Cargo.toml go.mod 2>/dev/null

# Detect existing structure
ls -la .git/ .gitignore README.md docs/ .agents/ .claude/ .husky/ 2>/dev/null
```

Store the detected stack for use in subsequent steps. ASK the user to confirm the detected stack before proceeding if anything is ambiguous.

### Step 2: Create .gitignore

Adapt to the detected stack. Base template:

```gitignore
# Dependencies
/node_modules/
/.pnp
.pnp.js

# Build output
/.next/
/out/
/build/
/dist/
/.turbo/

# Testing
/coverage/
/playwright-report/
/test-results/
/.vitest/
/.auth/

# Logs
*.log
npm-debug.log*
pnpm-debug.log*

# Environment / secrets
.env
.env.*
!.env.example

# Editor / OS
.DS_Store
*.pem
.idea/
.vscode/

# Framework-specific
.vercel/
*.tsbuildinfo
next-env.d.ts
```

**Adapt**: Add framework-specific patterns (Python: `__pycache__/`, `*.pyc`; Go: binary output; Rust: `target/`).

### Step 3: Create .agents/ structure

```bash
mkdir -p .agents/agents .agents/skills
```

#### .agents/agents/senior-architect.md

```markdown
# Senior Architect

You are a Senior Architect, a helpful but challenging persona who cares deeply about doing things right.
You prefer robust fundamentals, Clean Architecture, and strict boundaries over quick-and-dirty hacks.
```

#### .agents/skills/

Copy the following skill directories from the user's global skills collection, adapted to the project's stack. At MINIMUM include:

**For ANY project:**
- `accessibility/` (if frontend)
- `seo/` (if frontend)

**For Next.js/React:**
- `next-best-practices/`
- `shadcn/`
- `tailwind-css-patterns/`
- `typescript-advanced-types/`
- `vercel-react-best-practices/`

**For backend projects:**
- `nodejs-backend-patterns/` or `django-drf/` depending on stack

**Always create project-specific skills:**
- `feature-architecture-standard/SKILL.md` — Adapted to the project's patterns
- `docs-standard/SKILL.md` — Documentation conventions
- `devops-quality-gates/SKILL.md` — CI/CD quality gates

### Step 4: Create scripts/

#### scripts/sync-skills.sh

```bash
#!/bin/bash
AGENTS_DIR=".agents"
INDEX_FILE="AGENTS.md"

echo -e "\033[0;34m📚 Generando índice de $INDEX_FILE...\033[0m"

cat << 'HEADER' > "$INDEX_FILE"
# Project Agents and Skills

This file tracks the active agents and skills available in this repository.

## Available Skills

| Skill | Description | URL |
| --- | --- | --- |
HEADER

if [ -d "$AGENTS_DIR/skills" ]; then
  for dir in "$AGENTS_DIR/skills"/*/; do
    if [ -f "${dir}SKILL.md" ]; then
      name=$(grep -m 1 "^name:" "${dir}SKILL.md" | sed 's/name: *//')
      desc=$(grep -m 1 "^description:" "${dir}SKILL.md" | sed 's/description: *//')
      path="${dir}SKILL.md"
      if [ -n "$name" ] && [ -n "$desc" ]; then
        echo "| \`$name\` | $desc | [$path]($path) |" >> "$INDEX_FILE"
      fi
    fi
  done
fi

echo -e "\n## Workflows (Slash Commands)\n" >> "$INDEX_FILE"
echo -e "## Personas\n" >> "$INDEX_FILE"
echo "| Persona | Description | Path |" >> "$INDEX_FILE"
echo "| --- | --- | --- |" >> "$INDEX_FILE"

if [ -d "$AGENTS_DIR/agents" ]; then
  for file in "$AGENTS_DIR/agents"/*.md; do
    if [ -f "$file" ]; then
      filename=$(basename "$file" .md)
      desc=$(head -n 5 "$file" | grep -v "^#" | grep -v "^$" | head -n 1)
      echo "| \`$filename\` | $desc | [$file]($file) |" >> "$INDEX_FILE"
    fi
  done
fi

echo -e "\033[0;32m✅ $INDEX_FILE actualizado correctamente.\033[0m"
```

#### scripts/update-docs.sh

```bash
#!/bin/bash
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo -e "\033[0;34m📚 Synchronizing documentation and agent skills...\033[0m"
bash "$REPO_ROOT/scripts/sync-skills.sh"
echo -e "\033[0;32m✅ Documentation synchronized successfully.\033[0m"
```

Make both executable:
```bash
chmod +x scripts/sync-skills.sh scripts/update-docs.sh
```

### Step 5: Create .husky/ hooks

First ensure husky is installed:
```bash
# Check if husky exists, install if not
grep -q '"husky"' package.json || pnpm add -D husky lint-staged
npx husky init 2>/dev/null || true
```

#### .husky/pre-commit

```bash
pnpm exec lint-staged
./scripts/update-docs.sh
git add AGENTS.md 2>/dev/null || true
```

#### .husky/pre-push

```bash
echo "[husky] Running quality gates before push..."

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  RANGE="@{u}..HEAD"
else
  RANGE="origin/main..HEAD"
fi

CHANGED=$(git diff --name-only --diff-filter=ACMR "$RANGE" -- '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' 2>/dev/null)

if [ -n "$CHANGED" ]; then
  echo "[husky] Linting changed files:"
  echo "$CHANGED" | sed 's/^/  - /'
  echo "$CHANGED" | xargs pnpm exec eslint --max-warnings=0 || exit 1
else
  echo "[husky] No JS/TS files changed in push range, skipping lint."
fi

pnpm type-check || exit 1

if node -e "const s=require('./package.json').scripts||{}; process.exit(s.test?0:1)"; then
  pnpm test || exit 1
fi
```

### Step 6: Create .claude/settings.local.json

```json
{
  "permissions": {
    "allow": [
      "mcp__engram__mem_search",
      "mcp__engram__mem_save"
    ]
  }
}
```

### Step 7: Create docs/ structure

Create the full documentation structure adapted to the project. Follow the same 8-folder pattern:

```
docs/
├── README.md                    # Index and navigation
├── architecture/
│   ├── overview.md              # High-level architecture with Mermaid diagrams
│   └── patterns.md              # Code patterns and conventions
├── product/
│   ├── overview.md              # What the product does
│   └── features.md              # Feature map
├── data/
│   ├── api-contracts.md         # API endpoints (if applicable)
│   └── types-reference.md       # Type definitions (if applicable)
├── development/
│   ├── setup.md                 # Environment setup
│   └── workflow.md              # Git workflow, conventions
├── deployment/
│   ├── docker.md                # Docker setup (if applicable)
│   ├── ci-cd.md                 # CI pipeline
│   └── environments.md          # Environment variables
├── security/
│   └── overview.md              # Security measures
├── testing/
│   └── strategy.md              # Test strategy
└── guides/
    └── onboarding.md            # New member guide
```

**Rules for docs content:**
- Read the ACTUAL project code to write accurate documentation
- Include Mermaid diagrams with `%%{init}%%` custom theming (different palettes per diagram)
- Use emojis in section headers
- Spanish neutro, professional tone
- Every document must be self-contained
- Tables for structured information
- Code examples from the actual project

### Step 8: Create README.md

Professional README following the `readme-guardian` skill pattern:

**Required sections:**
1. Project title with emoji + one-line description
2. Table of contents
3. Architecture diagram (Mermaid)
4. Tech stack table
5. Project structure tree
6. Quick start guide
7. Environment variables
8. Available scripts
9. Testing
10. Internationalization (if applicable)
11. Authentication (if applicable)
12. Main business flow (if applicable)
13. Docker (if applicable)
14. CI/CD
15. Security
16. Conventions
17. Metrics

**Rules:**
- Read actual package.json, config files, source code FIRST
- Every section must be accurate to the real project
- Mermaid diagrams with custom theming
- Emojis in headers
- Spanish neutro
- Tables for structured data

### Step 9: Generate AGENTS.md

```bash
bash scripts/sync-skills.sh
```

### Step 10: Initial commit

```bash
git add .gitignore .agents/ AGENTS.md scripts/ .husky/ docs/ README.md .claude/
git commit -m "chore: bootstrap project infrastructure — docs, agents, hooks, scripts"
```

---

## Adaptations by Stack

### Next.js / React

- Include CSP, Clerk, i18n sections in docs if detected
- Include shadcn, tailwind, React patterns in .agents/skills/
- Add React-specific .gitignore patterns

### Python / Django / FastAPI

- Include virtualenv, pytest, migrations sections
- Add Python-specific .gitignore (`__pycache__/`, `*.pyc`, `.venv/`)
- Adapt scripts to use `uv`, `pip`, `poetry` as appropriate

### Go

- Include module structure, testing, build sections
- Add Go-specific .gitignore (`/bin/`, `*.exe`)
- Adapt pre-push hooks for `go vet`, `go test`

### Rust

- Include cargo, crate structure sections
- Add Rust-specific .gitignore (`/target/`)
- Adapt hooks for `cargo clippy`, `cargo test`

---

## Anti-Patterns

- ❌ Creating generic placeholder docs ("TODO: fill this in")
- ❌ Not reading actual code before writing docs
- ❌ Using English when the project convention is Spanish (or vice versa)
- ❌ Copying docs from another project without adapting
- ❌ Skipping Mermaid diagrams
- ❌ Creating .agents skills that don't match the project's actual stack
- ❌ Forgetting to make scripts executable
- ❌ Not running sync-skills.sh to generate AGENTS.md

---

## Checklist

Before finishing, verify:

- [ ] `.gitignore` exists and is comprehensive for the stack
- [ ] `.agents/agents/senior-architect.md` exists
- [ ] `.agents/skills/` has at least 3 relevant skills
- [ ] `scripts/sync-skills.sh` exists and is executable
- [ ] `scripts/update-docs.sh` exists and is executable
- [ ] `.husky/pre-commit` runs lint-staged + update-docs
- [ ] `.husky/pre-push` runs lint + type-check + tests
- [ ] `AGENTS.md` was generated by sync-skills.sh
- [ ] `docs/README.md` index exists with navigation map
- [ ] `docs/` has at least 8 documents across the folder structure
- [ ] All docs have Mermaid diagrams with custom theming
- [ ] `README.md` has architecture diagram, tech stack, quick start
- [ ] `.claude/settings.local.json` exists with basic permissions
- [ ] Everything is committed
