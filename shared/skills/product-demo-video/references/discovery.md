# Discovery — the 4 questions to ask before starting

Always ask these BEFORE writing any storyboard or code. They map directly to decisions that cost hours of rework if assumed wrong.

## Q1 — Visual material

> ¿Reutilizo capturas existentes (de PRs anteriores, screenshots manuales) o grabaciones nuevas del app en vivo vía Playwright?

Options:
1. **Reutilizar PNGs/capturas existentes** — fastest. Use when the user has a `captures/` folder ready.
2. **Capturas LIVE vía Playwright** — most authentic. Requires credentials and a Playwright-friendly login flow.
3. **Mixto** — PNGs para flujo general, live para el "wow moment".

If LIVE: also ask for credentials, environment URL, and confirm the tenant has enough data to capture (an empty tenant = empty screenshots).

## Q2 — Narration

> ¿Voz para la narración?

Options:
1. **TTS edge-tts es-ES-AlvaroNeural** (default) — free, reproducible, fast. Rate `-4%` for natural pacing.
2. **TTS premium** (ElevenLabs, OpenAI) — better quality, needs API keys.
3. **Sin voz, solo música + texto en pantalla** — Apple/Linear style. More visual, less explainer.

## Q3 — Duración y aspecto

> ¿Duración y aspecto objetivo?

Options:
1. **60-90s, 1920x1080** (default) — commercial demo standard.
2. **45-60s + versión vertical 1080x1920** — for social. Requires re-layout effort.
3. **2-3 min onboarding** — extended sales/training cut.

## Q4 — Workflow

> ¿Storyboard primero o directo al código?

Options:
1. **Storyboard primero** (default, recommended) — markdown with scenes/timings/narration. User validates. Then code.
2. **Directo al código** — only when iterating on an existing video, not from zero.

## Optional Q5 — Music

If asked or if the product is one where music adds value:

> ¿Música?

Options:
1. **Sin música, solo voz** (default for serious B2B or compliance-oriented demos).
2. **Música ambient suave** — pad behind voice, -22dB.
3. **Música rock onboarding cañera** — 124 BPM kick+snare+power chords, synthesized with numpy.

## Pitfall to avoid

Don't ask all 5 in one go and overwhelm the user. Ask Q1-Q4 together. Q5 only after the storyboard is validated, because music decisions often shift after the user sees the arc.

After Q1-Q4 are answered, ALWAYS draft the storyboard in markdown and present it for approval BEFORE building. Storyboards are cheap; renders are expensive.
