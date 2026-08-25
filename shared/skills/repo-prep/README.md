# Repo Prep — Skill

Skill de agente reutilizable que deja cualquier repositorio **acorde al resto de su
organización**: descripción de GitHub en inglés, topics en kebab-case y un README con
header centrado (badges shields.io + navegación).

Nace de un patrón repetido: cada repo nuevo entra sin descripción, sin topics y con un
README de una línea. Esta skill encapsula las convenciones para que el resultado sea
consistente en segundos, sin reinventar el estilo cada vez.

## Qué hace

Gobierna **tres artefactos a la vez**, siempre juntos:

1. **Descripción de GitHub** — una o dos frases en inglés (aunque el contenido esté en
   otro idioma), liderando con el QUÉ y el stack/diferenciador.
2. **Topics** — minúsculas, kebab-case, compuestos por dominio + tipo + stack +
   arquitectura, calibrados contra repos hermanos de la misma organización.
3. **README.md** — header centrado (`<div align="center">`), dos filas de badges, línea de
   navegación con anchors y secciones según el arquetipo (producto vs. documentación).

## La organización es un parámetro

La skill no conoce ninguna organización de antemano. Resuelve `<org>` desde el remote del
propio repositorio y **deriva las convenciones de los repos hermanos**:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
gh repo list <org> --limit 60 --json name,description,repositoryTopics
```

Si la organización tiene convenciones escritas (un `CONTRIBUTING.md`, un repo de docs, un
playbook interno), la skill las lee y prevalecen sobre los valores por defecto.

## Cómo se usa

Instalación global:

```bash
mkdir -p ~/.claude/skills
cp -R skills/repo-prep ~/.claude/skills/
```

Después el agente la auto-invoca en **cualquier repositorio** cuando detecta peticiones como:

- "Prepara este repo como los demás"
- "Mete descripción y topics y un README acorde al resto de repositorios"
- "Deja el README con el estilo de la organización"

La skill detecta el repo (`git remote`), lee su stack real, lo calibra contra los repos
hermanos, te enseña los tres borradores y, tras tu OK, aplica la descripción y los topics
con `gh repo edit` y abre una **PR** con el README si `main` está protegido.

## Convenciones que codifica

- **Descripción**: inglés, 1–2 frases, QUÉ + stack.
- **Topics**: kebab-case, tag de la organización (si los hermanos lo usan) + dominio +
  tipo + stack. Las familias de repos comparten un set base.
- **README**: dos arquetipos — *producto/servicio* (badges de stack + estructura + setup) y
  *documentación/estrategia* (visibilidad/formato/estado + índice + principios).
- **Copy en español**: español neutro (tuteo), nunca voseo/rioplatense.

## Estructura

```
repo-prep/
├── SKILL.md                       # instrucciones para el agente (reglas + workflow)
├── README.md                      # este archivo
└── references/
    ├── readme-template.md         # skeleton del header + ambos arquetipos
    └── badge-catalog.md           # colores, hex de marca, logos y encoding shields.io
```

## Requisitos

- **`gh` CLI** autenticado con acceso a la organización objetivo (para `gh repo edit` /
  `gh pr create`).
- Sin dependencias extra: solo Markdown y badges de shields.io (sin assets binarios).
