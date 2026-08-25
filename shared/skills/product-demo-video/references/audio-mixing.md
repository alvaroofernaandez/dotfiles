# Audio mixing — voice + music balance

Hyperframes renders multiple `<audio>` tracks into a single AAC stereo mix. There's no compressor or limiter in the chain — what you set on `data-volume` is what gets summed.

## Track inventory

```html
<audio id="vo"    class="clip" src="audio/voiceover.wav" data-track-index="3" data-volume="1"></audio>
<audio id="music" class="clip" src="audio/music.wav"     data-track-index="4" data-volume="0.38"></audio>
```

Voice always uses `data-volume="1"` (full source level). Music's `data-volume` is the lever for the mix balance.

## Target levels

| Metric | Target | Why |
|---|---|---|
| Mix peak | < -1.5 dB | Headroom for AAC encoding |
| Mix mean RMS | -22 to -28 dB | "Loudness war" sweet spot for product demos |
| Voice RMS during speech | -18 to -22 dB | Intelligible, not shouty |
| Music RMS during music-only gaps | 8-12 dB below voice | Present but not competing |

## Verify with ffmpeg

```bash
ffmpeg -i outputs/<file>.mp4 -af "volumedetect" -vn -sn -f null /dev/null 2>&1 | grep -E "mean|max"
```

If mean > -20: too hot. If mean < -32: too quiet (user perceives "low volume").

Per-segment check:

```bash
ffmpeg -i outputs/<file>.mp4 \
  -af "astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level" \
  -vn -f null /dev/null 2>&1 | grep RMS | awk 'NR%30==0' | head -10
```

Sampling at intervals shows the variation. Music-only gaps should NOT drop below -45 dB if music is intended to be heard.

## Voice tuning (edge-tts)

```python
VOICE = "es-ES-AlvaroNeural"   # default — male, calm, professional
RATE = "-4%"                    # default — slightly slower than natural for video
```

Alternatives by tone:
- `es-ES-ElviraNeural` — female, warm
- `es-ES-AlvaroNeural` rate `0%` — energetic
- `es-ES-XimenaNeural` (LATAM) — only if the audience is LATAM

Don't slow below `-8%` (sounds dazed). Don't speed past `+6%` (sounds rushed).

## Concatenation with silence padding

The narration is 8 separate WAVs (one per scene) but the video needs a single voiceover track aligned to scene voice-start times. Concatenate with silence padding:

```python
# scripts/build_audio.py
SCENE_START_VOICE = {
  "01_hook":      0.8,   # voice starts at scene 1 + 0.8s
  "02_product":   7.5,
  "03_dashboard": 15.0,
  "04_knowledge": 23.4,
  "05_agent":     33.4,
  "06_chat":      45.0,
  "07_channels":  54.4,
  "08_outro":     64.9,
}

import subprocess
# Build filter_complex that inserts silence then concats each scene WAV at its start
# (see templates/build_audio.py for the full implementation)
```

## Mid-render audio bugs

### Voice cuts off at scene boundaries
Cause: scene voice-end overflows into the next scene's start. The narration was too long for its budget.
Fix: either trim narration text, or extend the scene duration in both `index.html` and the timing table.

### Music starts after scene 1 because of fade-in
The synth `build_music_rock.py` has a 2.5s fade-in. That's intentional — it gives the hook scene a clean voice-first feel. If you need music from t=0, edit `intro_n = int(2.5 * SR)` in the build script.

### Music sounds different on re-render
Cause: non-deterministic seed somewhere. The build script uses `np.random.default_rng(seed=42)` for ALL noise generation. If you forked the script and missed a `RNG.standard_normal()` call, fix it.

### Voice + music sums to clipping
Cause: voice WAV is already near 0 dBFS at peaks; music adds 0.38 of another waveform on top.
Fix: drop `data-volume` on music. Don't raise voice above 1.0.

## Quick balance recipe

Starting from a working V8-style mix:

```html
<audio id="vo"    data-volume="1.0"></audio>
<audio id="music" data-volume="0.38"></audio>
```

If the user says "music too loud" → drop music to `0.28`.
If the user says "voice sounds weak" → check edge-tts rate (maybe slow it slightly) and verify the source WAV peaks aren't already compressed.
If the user says "quita la música" → remove the music `<audio>` tag entirely. Don't just set volume to 0; tags with `data-volume="0"` still cost render time.
