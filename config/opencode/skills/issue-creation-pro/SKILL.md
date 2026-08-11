---
name: issue-creation-pro
description: >
  Creates extraordinary quality GitHub issues with rich Mermaid diagrams, contextual labels,
  emojis, deep technical analysis, and comprehensive documentation.
  Trigger: When user asks to create an issue, report a bug, file a feature request, or open a ticket.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "2.0"
  extends: issue-creation
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent
---

# Skill: issue-creation-pro

## When to Use

Activate this skill whenever the user mentions:
- Creating an issue / opening a ticket / reporting a bug / requesting a feature
- Filing an issue on any GitHub repository
- Any variation of "haz una issue", "abre un ticket", "reporta esto"

---

## Philosophy: Issues Are Documentation

An issue is NOT a todo item. It's a **living technical document** that:
- Tells the FULL story to someone who has zero context
- Explains WHY this matters, not just WHAT is broken
- Provides a clear mental model via diagrams
- Gives actionable next steps for debugging/implementation

---

## Non-Negotiable Rules

1. **ALWAYS search for duplicates first** — `gh issue list --repo OWNER/REPO --state all --search "keywords"`
2. **ALWAYS include labels** with proper colors (ensure they exist with `--force`)
3. **ALWAYS include emojis** in section headers and throughout the body
4. **ALWAYS include multiple Mermaid diagrams** — minimum 3, aim for 5+
5. **ALWAYS use colorful, themed Mermaid configs** with `%%{init}%%` blocks
6. **ALWAYS explain the WHY** — not just what's broken, but why it matters and what impact it has
7. **ALWAYS include a severity/priority assessment** at the end
8. **ALWAYS write the issue body via HEREDOC** to preserve formatting
9. **NEVER create a bare/minimal issue** — every issue should be a comprehensive technical document
10. **NEVER guess root cause without evidence** — present hypotheses, not conclusions

---

## Mermaid Diagram Requirements

### Every issue MUST include diagrams from these categories:

| Type | When to Use | Mermaid Type |
|------|-------------|--------------|
| **Flow Analysis** | Always for bugs | `sequenceDiagram` or `flowchart` |
| **State Machine** | When states/transitions involved | `stateDiagram-v2` |
| **Root Cause Tree** | Always for bugs | `flowchart TB` with subgraphs |
| **Timeline** | When timing matters | `gantt` |
| **Data Flow** | When data transformation involved | `flowchart LR` with subgraphs |
| **Decision Tree** | For debugging guidance | `flowchart TD` |
| **Architecture** | For feature requests | `flowchart` or `C4Context` |
| **Component Interaction** | For integration issues | `sequenceDiagram` |

### Mermaid Styling Rules

Every diagram MUST use custom theming via `%%{init}%%` for visual richness:

```
%%{init: {'theme': 'base', 'themeVariables': {
  'primaryColor': '#COLOR',
  'primaryTextColor': '#COLOR',
  'primaryBorderColor': '#COLOR',
  'lineColor': '#COLOR',
  'secondaryColor': '#COLOR',
  'tertiaryColor': '#COLOR'
}}}%%
```

Use DIFFERENT color palettes for each diagram — never repeat the same theme:

| Palette Name | Primary | Secondary | Line | Use For |
|-------------|---------|-----------|------|---------|
| Ocean | `#0ea5e9` | `#f43f5e` | `#a855f7` | Data flow, architecture |
| Sunset | `#f59e0b` | `#8b5cf6` | `#ec4899` | Root cause analysis |
| Forest | `#10b981` | `#3b82f6` | `#f97316` | Happy path flows |
| Royal | `#7c3aed` | `#06b6d4` | `#f59e0b` | Decision trees |
| Indigo | `#6366f1` | `#14b8a6` | `#f43f5e` | Timelines, sequences |
| Cherry | `#e11d48` | `#8b5cf6` | `#22c55e` | Error flows, alerts |

### Subgraph Styling

Always style subgraphs with fill colors, borders, and stroke width:

```
style SUBGRAPH_NAME fill:#color,stroke:#color,stroke-width:2px
```

### Diagram Size

Diagrams should be LARGE and detailed — include:
- Descriptive node labels with line breaks (`<br/>`)
- Emoji in node labels where appropriate
- Notes and annotations
- Color-coded paths (happy path vs error path)

---

## Issue Structure

### Bug Reports

```md
## 🚨 Descripción

[2-3 sentences explaining what's happening and why it's wrong]

---

## 🔁 Reproducción

1. Step by step
2. With exact commands/actions
3. Including environment details

---

## 📦 Evidencia

[Response payloads, logs, error messages — in code blocks]

---

## 🔍 Análisis de campos / datos

[Table comparing actual vs expected values — highlight anomalies]

| Campo | Valor Actual | Valor Esperado | ⚠️ Problema |
|-------|-------------|----------------|-------------|

---

## 🗺️ Flujo esperado vs flujo real

[sequenceDiagram showing BOTH happy path and actual bug path in the same diagram]

---

## 📊 State Machine / Estados

[stateDiagram-v2 showing state transitions with the bug highlighted]

---

## 🧠 Hipótesis de causa raíz

[flowchart TB with subgraphs — one per hypothesis, each with reasoning chain]

---

## ⏱️ Timeline

[gantt chart showing timing of events if relevant]

---

## 🔄 Flujo de datos

[flowchart LR showing data transformations with subgraphs per layer]

---

## 🧭 Árbol de decisión para debugging

[flowchart TD with decision nodes and fix recommendations]

---

## 📋 Contexto

[Table with all relevant metadata — IDs, environment, versions, timestamps]

---

## 🎯 Dato clave

[One paragraph highlighting THE most important observation — the smoking gun]

---

## 🔴 Severidad

**[Alta/Media/Baja]** — [Why this severity, what's the business impact]
```

### Feature Requests

```md
## 💡 Descripción

[What feature is needed and WHY it matters]

---

## 🎯 Problema que resuelve

[The pain point — with concrete examples]

---

## 🏗️ Propuesta de implementación

[High-level approach with architecture diagrams]

---

## 🗺️ Flujo de usuario propuesto

[sequenceDiagram showing the user interaction flow]

---

## 📊 Modelo de datos

[Entity relationship or data flow diagram]

---

## 🔄 Integración con sistema existente

[flowchart showing how this fits into the current architecture]

---

## ✅ Criterios de aceptación

- [ ] Criterion 1
- [ ] Criterion 2

---

## 🧭 Alternativas consideradas

[Table with alternatives, pros, cons]

---

## 🔴 Prioridad

**[Alta/Media/Baja]** — [Why this priority]
```

---

## Label Policy

### Always ensure labels exist before assigning:

```bash
gh label create "LABEL" --repo "OWNER/REPO" --color "COLOR" --description "DESC" --force
```

### Label Matrix

| Context | Label | Color | Emoji |
|---------|-------|-------|-------|
| Bug | `bug` | `d73a4a` | 🐛 |
| Security | `security` | `b60205` | 🔒 |
| Enhancement | `enhancement` | `a2eeef` | ✨ |
| Feature | `feature` | `1d76db` | 🚀 |
| Backend | `backend` | `0e8a16` | ⚙️ |
| Frontend | `frontend` | `5319e7` | 🖥️ |
| Performance | `performance` | `fbca04` | ⚡ |
| DevEx | `developer-experience` | `c2e0c6` | 🛠️ |
| Priority High | `priority:high` | `b60205` | 🔴 |
| Priority Medium | `priority:medium` | `fbca04` | 🟡 |
| Priority Low | `priority:low` | `0e8a16` | 🟢 |
| Needs Review | `status:needs-review` | `ededed` | 👀 |
| Documentation | `documentation` | `0075ca` | 📚 |
| Infrastructure | `infrastructure` | `d4c5f9` | 🏗️ |

### Minimum labels per issue type:

- **Bug**: `bug` + domain (`backend`/`frontend`) + priority
- **Feature**: `feature` + domain + priority
- **Enhancement**: `enhancement` + domain

---

## Complete Workflow

### 1. Search duplicates

```bash
gh issue list --repo "OWNER/REPO" --state all --search "keyword1 keyword2"
```

### 2. Determine repo

- Check engram memory for repo URLs
- Check git remote if in a related project
- Check GitHub org repos: `gh repo list ORG --limit 20`
- ASK the user if truly unknown

### 3. Ensure labels exist

```bash
gh label create "bug" --repo "OWNER/REPO" --color "d73a4a" --description "Something isn't working" --force
gh label create "backend" --repo "OWNER/REPO" --color "0e8a16" --description "Server/API scope" --force
gh label create "priority:high" --repo "OWNER/REPO" --color "b60205" --description "Urgent" --force
```

### 4. Create the issue

ALWAYS use HEREDOC for the body to preserve Mermaid formatting:

```bash
gh issue create --repo "OWNER/REPO" \
  --title "fix(scope): descriptive title" \
  --label "bug" \
  --label "backend" \
  --label "priority:high" \
  --body "$(cat <<'ISSUE_EOF'
[FULL ISSUE BODY HERE]
ISSUE_EOF
)"
```

### 5. Verify

```bash
gh issue view <number> --repo "OWNER/REPO" --json title,labels,url
```

---

## Quality Checklist

Before submitting any issue, verify:

- [ ] Title uses conventional format: `fix(scope):` / `feat(scope):` / `chore(scope):`
- [ ] At least 3 Mermaid diagrams with different color themes
- [ ] All diagrams use `%%{init}%%` custom theming
- [ ] Tables with field analysis (actual vs expected)
- [ ] Emojis in all section headers
- [ ] Labels created with correct colors
- [ ] Severity/priority assessment with business impact reasoning
- [ ] "Dato clave" section highlighting the smoking gun
- [ ] No root cause claimed without evidence — only hypotheses
- [ ] Issue is self-contained — reader needs ZERO prior context

---

## Anti-Patterns

- ❌ Bare issues with just a title and one sentence
- ❌ Mermaid diagrams without custom theming (default gray is unacceptable)
- ❌ All diagrams using the same color palette
- ❌ Missing labels or labels without proper colors
- ❌ Stating root cause as fact without evidence
- ❌ Missing severity assessment
- ❌ No diagrams at all
- ❌ Using `--body` inline for complex issues (use HEREDOC)
- ❌ Forgetting to search for duplicates first
- ❌ Skipping the Agent Instructions section at the end

---

## Agent Instructions Section (MANDATORY — always append at the end)

Every issue MUST end with a collapsible `<details>` block containing:
1. A machine-readable **SDD spec seed** — acceptance criteria extracted from the issue, ready to feed into `sdd-spec`
2. A **ready-to-run prompt** for Claude Code / OpenCode to kick off the full SDD cycle
3. A **quick-start command block** the developer can copy-paste immediately

### Template to append (adapt content to the actual issue)

````markdown
---

<details>
<summary>🤖 Agent Instructions — Claude Code / OpenCode</summary>

## 📋 SDD Spec Seed

> Pre-extracted acceptance criteria from this issue. Feed directly into `/issue-sdd <N>` or paste into `sdd-spec`.

### Acceptance Criteria

| ID | Criterio | Verificable con |
|----|----------|-----------------|
| AC-1 | [Extraído del comportamiento esperado #1] | [Test / inspección visual / curl] |
| AC-2 | [Extraído del comportamiento esperado #2] | [Test / inspección visual / curl] |
| AC-N | [...] | [...] |

### Escenarios de regresión

- El comportamiento actual que ya funciona MUST NOT break: [listar]
- Tests existentes que deben seguir en verde: [listar archivos si se conocen]

### Scope

**IN**: [qué entra exactamente en este issue]
**OUT**: [qué NO entra — refactors, otros módulos, mejoras futuras]

---

## 🚀 Claude Code / OpenCode — Quick Start

Para planificar e implementar este issue con SDD completo, ejecuta en Claude Code u OpenCode:

```
/issue-sdd <N>
```

Esto arranca el ciclo completo: **explore → propose → spec → design → tasks** con análisis exhaustivo del codebase antes de tocar una sola línea.

---

## 🧠 Prompt para implementación directa (sin SDD)

Si prefieres implementar sin el ciclo SDD completo, usa este prompt como punto de partida:

```
Implementa el fix del issue #<N>: <título del issue>

Contexto clave:
- Archivos afectados: [lista de archivos con rutas]
- Root cause: [causa raíz identificada en el issue]
- Fix propuesto: [descripción del fix]

Reglas obligatorias:
1. Lee cada archivo COMPLETO antes de editar.
2. Sigue los patrones existentes del proyecto.
3. Añade o actualiza tests para el path afectado.
4. No rompas comportamiento existente — ejecuta los tests al final.
5. No hagas git commit — solo implementa y reporta qué cambiaste.
```

---

## 🔗 Referencias útiles

- Issue: `gh issue view <N> --repo OWNER/REPO`
- SDD skill: `/issue-sdd <N>`
- Pre-PR gate: `tools/pre_pr_runtime_gate.sh`

</details>
````

### Rules for filling the template

1. **AC table**: extract one row per acceptance criterion from «Comportamiento esperado» or «Criterios de aceptación». Make each AC independently verifiable.
2. **Regresiones**: list the existing behaviour that must NOT break — pull from «Comportamiento actual» (the parts that work) and known related tests.
3. **Scope IN/OUT**: derive directly from the issue's explicit fix proposal. If the issue says "only change X", OUT must say "no refactor of Y".
4. **Quick-start command**: always `issue-sdd <N>` — this is non-negotiable. Replace `<N>` with the actual issue number after creating it.
5. **Direct implementation prompt**: summarise root cause + fix in 2-3 lines. Pull from «💡 Fix propuesto» and «🎯 Dato clave» sections.
6. **Never invent** file paths or root causes — use only what the issue body already states.
7. The `<details>` block must be **collapsed by default** — it's for agents, not humans skimming the issue.
