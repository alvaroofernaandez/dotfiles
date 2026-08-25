---
name: repo-prep
description: >
  Prepare a repository's public metadata so it matches its organization's house
  style: an English one-line GitHub description, kebab-case topics (including the
  org's own tag for internal repos), and a centered README with shields.io badges
  and anchored navigation. Inspects sibling repos in the same org to stay
  consistent, then applies the changes via `gh` and a PR.
  Trigger: When the user asks to "prepare a repo", "preparar repositorio",
  "deja el repo como los demás", set or fix a repo description/topics, or align a
  README with the rest of an organization's repositories.
license: Apache-2.0
version: "1.0"
---

## When to Use

- A repo has an empty/weak GitHub **description** or no **topics**.
- A `README.md` doesn't match the house style of its organization.
- The user says "prepara el repo", "ponlo como los demás", "mete descripción y topics",
  "README acorde al resto de repos", or onboards a brand-new repo into an org.

This skill governs THREE artifacts, always treated together:

1. **GitHub description** (the repo's one-liner).
2. **Topics** (the repo's tags).
3. **README.md** (house-style header + sections).

## The organization is a parameter

Nothing here is tied to a specific company. Resolve `<org>` from the repo's own
remote and derive the conventions from its siblings:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner   # -> <org>/<name>
gh repo list <org> --limit 60 --json name,description,repositoryTopics
```

The sibling listing is the source of truth for tone, topic sets and badge style. If
the org keeps a written convention (a `CONTRIBUTING.md`, a docs repo, an internal
playbook), read it and let it override the defaults below.

## House Style — the rules

### 1. GitHub description (English, 1–2 sentences)

- **Always English**, even when the repo content is in another language. This is the
  common convention across orgs; confirm against the siblings before assuming it.
- One or two sentences. Lead with WHAT it is, then the key stack or differentiator.
- Name the product/domain and, for code repos, the headline stack
  (e.g. "Monorepo (Next.js 15 + NestJS 11)").
- No trailing period is fine either way; match the density of sibling repos.
- Shape to imitate:
  - A product repo: "<What it does> — <two or three capabilities>. Monorepo (<stack>)."
  - A docs repo: "<Kind of document> for <scope>, covering <the main sections>…"

### 2. Topics (lowercase kebab-case)

- **Always lowercase, kebab-case** (`pnpm-workspaces`, not `pnpm workspaces`).
- **Include the org's own tag** for internal projects, when the siblings use one
  (many orgs tag every internal repo with their own name). Public forks and
  standalone tools often omit it — match the closest sibling.
- Compose topics from these buckets, ~6–13 total:
  - **Domain**: `crm`, `billing`, `invoicing`, `payments`, `time-tracking`, `rag`, `agent`…
  - **Type**: `microservice`, `monorepo`, `saas`, `frontend`, `backend`, `cli`,
    `boilerplate`, `documentation`, `knowledge-base`, `playbook`…
  - **Stack**: `nextjs`, `nestjs`, `typescript`, `python`, `go`, `postgresql`,
    `rabbitmq`, `docker`, `turborepo`, `pnpm-workspaces`, `prisma`, `clerk`…
  - **Architecture/pattern** (when defining): `hexagonal-architecture`,
    `clean-architecture`, `cqrs`, `outbox-pattern`, `event-driven`.
- Mirror what siblings in the same family already use. Families of microservices
  typically share a common base set plus one or two domain topics each.

### 3. README — centered house-style header

The house style opens with a centered block, then `---`, then sections. The header
skeleton (full version in [references/readme-template.md](references/readme-template.md)):

```html
<div align="center">

# <Project Display Name>

### <One-line subtitle>

<One/two-sentence description of what it is and who it's for.>

<br/>

<!-- Row 1 — tech / meta badges -->
![<Tech>](https://img.shields.io/badge/<Label>-<hex>?logo=<logo>&logoColor=white&style=flat)

<!-- Row 2 — category badges -->
![<Cat>](https://img.shields.io/badge/<key>-<value>-22c55e?style=flat)

<br/>

[Section A](#anchor-a) · [Section B](#anchor-b) · [Section C](#anchor-c)

</div>

---
```

**Badge color conventions** (full catalog in [references/badge-catalog.md](references/badge-catalog.md)):

| Use | Color | Example |
|---|---|---|
| Visibility (private) | `red` | `visibility-private-red` |
| Tech / framework | brand hex + `logo=` | `Next.js%2015-000000?logo=next.js` |
| Factual category (sector, estado, modelo) | green `22c55e` | `estado-documento%20vivo-22c55e` |
| Type / classification | indigo `6366f1` or blue `3268B4` | `tipo-B2B-3268B4` |
| Format / meta | blue `1f6feb` | `formato-Markdown%20%2B%20Mermaid-1f6feb` |

**Two archetypes** — pick by repo kind:

- **Product / service** (app, monorepo, microservice): Row 1 = stack badges with logos;
  sections = repo structure tree, stack table, local setup, contributing.
- **Docs / strategy / knowledge-base**: Row 1 = visibility + format + status badges;
  sections = purpose, document index table, principles, next steps.

**README hard rules**:
- shields.io labels URL-encode spaces as `%20`, `+` as `%2B`, `-` (literal) as `--`.
- Subtitle and body copy in Spanish: **neutral Spanish (tuteo)** — never voseo/Rioplatense.
- Section anchors must match GitHub's slug rules (lowercase, spaces→`-`, strip accents/punct).
- Keep the nav line to the 3–5 most important sections.

## Workflow

1. **Detect the repo.** `git remote -v` → resolve `<org>/<name>`. Get current
   metadata: `gh repo view <org>/<name> --json description,repositoryTopics`.
2. **Read the repo.** Skim README, top-level docs, `package.json`/manifests to learn the
   real stack and purpose. Don't invent — derive description/topics from what's there.
3. **Calibrate against siblings.** `gh repo list <org> --limit 60 --json name,description,repositoryTopics`
   and find the closest family (microservice, monorepo, docs…). Match its tone and topic set.
4. **Draft all three artifacts** and show them to the user before applying:
   description (English), topics (kebab-case list), README (house-style).
5. **Apply metadata**:
   ```bash
   gh repo edit <org>/<name> \
     --description "<english one-liner>" \
     --add-topic <t1> --add-topic <t2> ...
   ```
   Verify: `gh repo view <org>/<name> --json description,repositoryTopics`.
6. **Write README.md** in the target repo using the template + chosen archetype.
7. **Ship via PR** when `main` is protected (check first — many orgs protect it):
   branch → commit (`docs: …`) → push → `gh pr create` with why/what/how. Description
   and topics are applied directly on GitHub (they aren't files); say so in the PR body.

## Resources

- **README skeleton + both archetypes**: [references/readme-template.md](references/readme-template.md)
- **Badge catalog (colors, logos, encoding)**: [references/badge-catalog.md](references/badge-catalog.md)
