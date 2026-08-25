# README skeleton — organization house style

Two archetypes share the same centered header; they differ in which badges go in Row 1
and which sections follow. Copy the matching block and fill the placeholders.

---

## Shared header skeleton

```html
<div align="center">

# <Project Display Name>

### <One-line subtitle in neutral Spanish>

<One/two-sentence description of what it is and who it's for.>

<br/>

<!-- Row 1 — see archetype below -->

<!-- Row 2 — category badges (green facts / indigo type) -->

<br/>

[Section A](#anchor-a) · [Section B](#anchor-b) · [Section C](#anchor-c)

</div>

---
```

After the `---`, write the sections in normal (left-aligned) Markdown. Close the file
with a centered "documento vivo" note only for docs/strategy repos.

---

## Archetype A — Product / service (app, monorepo, microservice)

Row 1 = stack badges with logos. Sections describe how to understand and run the code.

```html
<div align="center">

# InnoHelp

### Plataforma de análisis de viabilidad para cooperativas agroalimentarias

Herramienta B2B que reemplaza el flujo manual de Excel y correo con una plataforma web
estructurada, con trazabilidad completa y modelo financiero integrado.

<br/>

![Next.js](https://img.shields.io/badge/Next.js%2015-000000?logo=next.js&logoColor=white&style=flat)
![NestJS](https://img.shields.io/badge/NestJS-E0234E?logo=nestjs&logoColor=white&style=flat)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white&style=flat)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL%2016-4169E1?logo=postgresql&logoColor=white&style=flat)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white&style=flat)

![Sector](https://img.shields.io/badge/sector-agroalimentario-22c55e?style=flat)
![Modelo](https://img.shields.io/badge/modelo-viabilidad%20financiera-22c55e?style=flat)
![Tipo](https://img.shields.io/badge/tipo-B2B-3268B4?style=flat)

<br/>

[Estructura](#estructura-del-repositorio) · [Stack](#stack) · [Puesta en marcha](#puesta-en-marcha-local) · [Contribuir](#contribuir)

</div>

---
```

Typical sections, in order:

1. `## Estructura del repositorio` — a fenced tree of top-level dirs with one-line comments.
2. `## Stack` — a table: `| Capa | Tecnología |`.
3. `## Puesta en marcha local` — clone, env, `docker compose`, run commands.
4. `## Contribuir` — link to AGENTS.md / PR policy.

---

## Archetype B — Docs / strategy / knowledge-base

Row 1 = visibility + format + status. Sections orient the reader through documents.

```html
<div align="center">

# <Org> Ops

### Manual interno de operaciones de <Org>

Fuente de verdad sobre cómo opera la organización: comercial, delivery, soporte,
finanzas, onboarding y decisiones estructurales.

<br/>

![Visibilidad](https://img.shields.io/badge/visibility-private-red?logo=github&logoColor=white&style=flat)
![Formato](https://img.shields.io/badge/formato-Markdown%20%2B%20Mermaid-1f6feb?logo=markdown&logoColor=white&style=flat)
![Estado](https://img.shields.io/badge/estado-documento%20vivo-22c55e?style=flat)
![Tipo](https://img.shields.io/badge/tipo-knowledge%20base-6366f1?style=flat)

<br/>

[Propósito](#propósito) · [Estructura](#estructura-del-repositorio) · [Contribución](#contribución)

</div>

---
```

Typical sections, in order:

1. `## Propósito` — why the repo exists, what it standardizes (3–4 bullets).
2. `## Documentos` or `## Estructura del repositorio` — index table / tree.
3. `## Principios rectores` — numbered list of the operating principles.
4. `## Próximos pasos` — checkbox list of open decisions.
5. Centered closing blockquote: `> Documento vivo. Se actualiza a medida que se confirman decisiones.`

---

## Anchor slug rules (GitHub)

For nav links to resolve, derive the anchor from the heading:
lowercase → strip punctuation → spaces become `-`. GitHub **keeps** accents in the slug,
so `## Propósito` → `#propósito` (with the accent). Verify by clicking after pushing.
