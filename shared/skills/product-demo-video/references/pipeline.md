# Pipeline — E2E commands

## Project layout

```
<product-repo>/demo-video/                # or any subfolder of your choice
├── outputs/                              # final MP4s, one per version
└── v8/                                   # current iteration (bump number per iteration)
    ├── index.html                        # root composition
    ├── compositions/scene-{01..08}-*.html
    ├── assets/
    │   ├── captures/                     # PNG fallbacks
    │   ├── captures-live/                # Playwright live captures + cursor_targets.json
    │   ├── logos/                        # *_logo_*.webp from apps/web/public
    │   └── icons/                        # optional inline SVGs
    ├── audio/
    │   ├── 01_hook.wav ... 08_outro.wav  # per-scene narrations
    │   ├── manifest.json                 # durations
    │   ├── voiceover.wav                 # concatenated full narration
    │   └── music.wav                     # optional
    ├── scripts/
    │   ├── synth_voice.py
    │   ├── build_audio.py
    │   ├── build_music_rock.py
    │   └── capture_live.mjs
    ├── review/                           # frame extractions for QA
    ├── outputs/                          # local copy of final MP4
    ├── .venv/                            # python venv (edge-tts, numpy)
    ├── node_modules/                     # playwright + hyperframes
    ├── package.json
    └── meta.json
```

## Bootstrap a new iteration

```bash
# From an existing previous version
cd <project>/demo-video/
cp -R v7 v8
rm -rf v8/outputs/* v8/node_modules v8/.venv v8/review
```

Bootstrap a fresh project (first time):

```bash
mkdir -p demo-video/v1 && cd demo-video/v1
npx hyperframes init --yes
# init creates a my-video/ subfolder — flatten:
shopt -s dotglob && mv my-video/* . && rmdir my-video
mkdir -p assets/{captures,captures-live,logos,icons} audio scripts compositions review

# Install hyperframes skill (if not already)
cd .. && npx skills add heygen-com/hyperframes
```

## Generate narration

```bash
cd v8
python3 -m venv .venv && .venv/bin/pip install -q edge-tts
.venv/bin/python scripts/synth_voice.py
# Outputs: audio/01_hook.wav .. 08_outro.wav, audio/manifest.json
```

Then concat:

```bash
.venv/bin/python scripts/build_audio.py
# Outputs: audio/voiceover.wav (concatenated with silence padding to scene voice-start offsets)
```

## Generate music (optional)

```bash
.venv/bin/pip install -q numpy
.venv/bin/python scripts/build_music_rock.py
# Outputs: audio/music.wav (75s, 124 BPM, deterministic seed)
```

If no music, remove the `<audio id="music">` tag from `index.html`.

## Capture live app

```bash
npm init -y > /dev/null 2>&1
npm install --no-save playwright@latest
npx playwright install chromium

# Edit scripts/capture_live.mjs with the right URL and selectors per product
node scripts/capture_live.mjs
# Outputs: assets/captures-live/*.png + cursor_targets.json + MANIFEST.md
```

## Build / iterate

```bash
# Lint after every HTML edit
npx hyperframes lint

# Validate (smoke test in headless Chrome)
npx hyperframes validate --no-contrast

# Final render (30s for 75s @ 30fps)
npx hyperframes render --output outputs/<product>_demo_v8.mp4
cp outputs/<product>_demo_v8.mp4 ../outputs/
```

## Verify

```bash
# Audio levels
ffmpeg -i outputs/<product>_demo_v8.mp4 -af "volumedetect" -vn -sn -f null /dev/null 2>&1 | grep -E "mean|max"
# Healthy targets: mean -22 to -28 dB, max < -1.0 dB

# Frame extraction at key timestamps
for t in 3 11 17 21 28 35 40 50 60 72; do
  ffmpeg -y -ss $t -i outputs/<product>_demo_v8.mp4 -frames:v 1 -q:v 3 review/frame_${t}s.jpg 2>/dev/null
done

# Then Read each frame in your agent loop and verify visually
```

## Common pitfalls (from V2-V8)

- **Don't trust lint pass**: it reports zero errors while rendering blank scenes. Always extract frames and Read them.
- **`npx hyperframes preview` doesn't expose the composition cross-origin** — useless for Playwright-driven QA. Use rendered MP4 + ffmpeg frame extraction instead.
- **`npx hyperframes snapshot` renders everything stacked with no timeline** — also useless for visual QA.
- **Music volume `data-volume` is not absolute** — it scales the source WAV. If you change the source loudness, retune `data-volume`. Rough mapping:
  - Ambient pad (source RMS 0.05) → `data-volume="0.85"` → ~RMS -40 dB in mix
  - Rock track (source RMS 0.20) → `data-volume="0.38"` → ~RMS -22 dB in mix
- **Each render eats ~30s** at 1920x1080@30fps. Budget 2-3 renders per iteration max. Verify with frames first, render second.
