# Storyboard template — 8-scene arc

Total duration: ~75s. Tight enough to hold attention, long enough to tell a real story.

Arc: **Problem → Product → 5 flow scenes → Outcome → CTA**.

## Scene structure

| # | Name | Start | Dur | Purpose | Voice |
|---|---|---|---|---|---|
| 1 | Hook | 0.0 | 7.0 | State the customer pain | One bold statistic ("+200 preguntas repetidas") |
| 2 | Product | 7.0 | 7.5 | Brand reveal + 1-line value prop | Logo + tagline |
| 3 | Dashboard | 14.5 | 8.5 | First touch with product | "From here you see X, Y, Z" |
| 4 | Knowledge/Setup | 23.0 | 10.0 | Core setup flow (upload, configure) | Real flow shown via zoom-to-click |
| 5 | Intelligence/Configuration | 33.0 | 11.5 | The "smart" part (agents, AI, automation) | Show fields, options, guardrails |
| 6 | Real Use | 44.5 | 9.5 | A real moment of use (conversation, alert, etc) | Show actual output |
| 7 | Channels/Reach/Control | 54.0 | 10.5 | Where the value gets delivered + control panel | Multiple channels or admin views |
| 8 | Outro | 64.5 | 10.5 | Tagline + CTA + URL | Logo + "Siguiente paso → ..." + URL typewriter |

Voice durations from edge-tts at rate `-4%`:
- Scene 1: ~5.6s
- Scene 2: ~6.6s
- Scene 3: ~7.0s
- Scene 4: ~8.4s
- Scene 5: ~10.0s
- Scene 6: ~8.2s
- Scene 7: ~9.3s
- Scene 8: ~9.3s
- **Total narration: ~64.5s** (rest is breathing room + transitions)

## Per-scene checklist

### Scene 1 — Hook
- [ ] Particles background (deterministic, mulberry32 seed)
- [ ] Overline: small caps, accent color, with an icon (e.g. `users` for "RETO MUNICIPAL")
- [ ] Hero stat: 130-160px, accent color, with green glow
- [ ] Chips below: 3 chips with icons hinting the product domain
- [ ] Headline uses `clip-path` left-to-right reveal

### Scene 2 — Product
- [ ] Real product logo (icon-only, transparent background)
- [ ] Logo entrance: envelope-flap (`rotationX: -60 → 0`) + scale 0.8 → 1 + glow pulse (single, finite)
- [ ] Wordmark text below, per-letter stagger
- [ ] One-line value prop in muted color
- [ ] 2-3 trust chips (`24/7 · Sin código · Multi-canal`) — KEEP IT MINIMAL
- [ ] No fabricated stats ("+12 ayuntamientos", "+50 clientes") unless verified — the V8 lesson was to remove these

### Scene 3 — Dashboard
- [ ] Top bar with logo + product wordmark left, "01 · <Scene name>" right with animated underline
- [ ] 2px progress bar under top bar filling 0%→100% over scene duration
- [ ] Real captured screenshot wrapped in `.shot-wrap` with `overflow: hidden`
- [ ] Glass callout BOTTOM-RIGHT (NOT vertical right) so zoomed image has space: `bottom: 60px; right: 60px; max-width: 480px`
- [ ] Synthetic cursor enters from offscreen, bezier path to click target, single click ripple
- [ ] Ken Burns zoom-to-click at 2.5s: scale 1.6, translate to click center

### Scene 4 — Setup flow (whatever the user configures first: sources, documents, forms…)
- [ ] 3-4 sub-shots stitched with crossfade (each at scale 1.4 → 1 entry, settling)
- [ ] Cursor moves between sub-shots with click ripples
- [ ] Typewriter effect for any text input (e.g. folder name, doc title)
- [ ] Success toast slides in top-right at end ("Carpeta creada", "Documento subido")
- [ ] Lucide `folder-tree` or domain-specific icon in callout

### Scene 5 — Intelligence/Config
- [ ] Modal showing fields the user can configure
- [ ] Highlight the single most important field of the flow via zoom
- [ ] 3 stat-card chips at the bottom: "Tono: Cercano", "Idiomas: 4", "Fuentes: 3" — showing the configured state
- [ ] Lucide `sparkles` icon (AI hint) in callout
- [ ] Success toast at end: "Asistente desplegado · 1 fuente vinculada"

### Scene 6 — Real use
- [ ] A real interaction: chat, alert, report, etc
- [ ] Typewriter for user input AND for AI/system response (gives "live" feel)
- [ ] Metric strip at end (3 stat chips): "🕐 0.4s respuesta · 📚 3 fuentes citadas · ✅ Validado"
- [ ] Bot avatar / status icon inside the response bubble
- [ ] Soft green glow behind the AI response

### Scene 7 — Channels/Reach/Control
- [ ] Split layout (50/50) showing two views simultaneously
- [ ] Channel chips at top (whatever the product integrates: Web · WhatsApp · Telegram, or RSS · Slack · Email) with Lucide icons
- [ ] No zoom-to-click here — both panels need to be visible
- [ ] Bottom-center callout summarizing the reach/control message

### Scene 8 — Outro
- [ ] Particles background (matches scene 1 for symmetry)
- [ ] Real logo BIG with continuous gentle bob (y: ±6px, finite)
- [ ] Tagline 44px muted
- [ ] CTA glass card: "Siguiente paso → <action>"
- [ ] URL typewriter beneath CTA: the product's public URL
- [ ] Final 0.5s fade-to-black on all content — this is the ONE scene that may use exit animations

## Narration tone

- Cercano, técnico cuando hace falta, sin marketing-speak.
- Habla "tú" o impersonal ("se", "puedes"), nunca "vosotros".
- Frases cortas. Cada escena cabe en una idea.
- Cierra con acción concreta: "Siguiente paso es un piloto con X".

## The three lines, by product archetype

Every demo needs the same three lines. These are shapes to fill, not copy to reuse — and
every number in them must be one the product can actually substantiate.

| Archetype | Hook (the pain) | Product line (what it is) | Outcome (the proof) |
|---|---|---|---|
| Document assistant / RAG | "<N> horas al mes respondiendo lo mismo" | "Convierte tu documentación en respuestas" | "<latencia> · fuentes citadas" |
| Document processing | "<N> horas procesando <documento>" | "Procesamiento automático con <técnica>" | "Listo para auditoría en <tiempo>" |
| Monitoring / alerting | "<Activo> sin supervisión" | "Detección continua de <evento>" | "Aviso antes de que ocurra" |
| Internal tooling | "<Proceso> repartido entre <N> herramientas" | "Un único flujo para <proceso>" | "<métrica> medible desde el primer día" |

Fill the placeholders from the discovery answers. If a number cannot be substantiated,
drop it: an unverifiable stat on screen costs more credibility than it buys.

## Final word

Don't try to cram more. 8 scenes / 75s is the right size. If the user asks for "más cosas", push back: the next iteration drops what doesn't earn its place.
