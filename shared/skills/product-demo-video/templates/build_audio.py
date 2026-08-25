#!/usr/bin/env python3
"""Concatenate 8 narration wavs into audio/voiceover.wav with per-scene offsets.

Total composition duration: 75s.
Each scene narration starts at its scene's `voice_start` offset (absolute timeline seconds).
Between scenes we insert silence to align timing. Voiceover output is mono 22050 Hz wav
suitable for inline playback inside hyperframes preview.

Run: python scripts/build_audio.py
"""
from __future__ import annotations
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "audio"
OUT = AUDIO / "voiceover.wav"

# voice start times in absolute composition seconds
SCENES = [
    ("01_hook.wav",      0.8),
    ("02_product.wav",   7.5),
    ("03_dashboard.wav", 15.0),
    ("04_knowledge.wav", 23.4),
    ("05_agent.wav",     33.4),
    ("06_chat.wav",      45.0),
    ("07_channels.wav",  54.4),
    ("08_outro.wav",     64.9),
]

TOTAL = 75.0
SAMPLE_RATE = 22050


def probe_duration(p: Path) -> float:
    out = subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=nokey=1:noprint_wrappers=1", str(p),
    ])
    return float(out.strip())


def main() -> int:
    if not AUDIO.exists():
        print(f"missing audio dir: {AUDIO}", file=sys.stderr)
        return 1

    # Build a filter_complex graph: each input padded with leading silence to its offset,
    # then amix into a single mono output, then trim to TOTAL.
    inputs: list[str] = []
    filters: list[str] = []
    labels: list[str] = []

    for idx, (fname, start) in enumerate(SCENES):
        p = AUDIO / fname
        if not p.exists():
            print(f"missing wav: {p}", file=sys.stderr)
            return 1
        inputs += ["-i", str(p)]
        # adelay expects milliseconds per channel
        delay_ms = int(round(start * 1000))
        filters.append(
            f"[{idx}:a]aformat=channel_layouts=mono,aresample={SAMPLE_RATE},"
            f"adelay={delay_ms}|{delay_ms}[a{idx}]"
        )
        labels.append(f"[a{idx}]")

    mix = "".join(labels) + f"amix=inputs={len(SCENES)}:normalize=0:dropout_transition=0[mix]"
    trim = f"[mix]atrim=0:{TOTAL},apad=whole_dur={TOTAL}[out]"
    filter_complex = ";".join(filters + [mix, trim])

    cmd = [
        "ffmpeg", "-y",
        *inputs,
        "-filter_complex", filter_complex,
        "-map", "[out]",
        "-ac", "1", "-ar", str(SAMPLE_RATE),
        "-c:a", "pcm_s16le",
        str(OUT),
    ]
    print("→", " ".join(cmd))
    subprocess.check_call(cmd)
    dur = probe_duration(OUT)
    print(f"voiceover.wav written ({dur:.2f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
