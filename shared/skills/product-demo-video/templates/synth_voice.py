"""Synthesize Spanish TTS narration for a product demo video.

Outputs one wav per scene plus a manifest with durations,
which drives the GSAP timeline timings in index.html.
"""
from __future__ import annotations

import asyncio
import json
import subprocess
import wave
from pathlib import Path

import edge_tts

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "audio"
OUT.mkdir(parents=True, exist_ok=True)

VOICE = "es-ES-AlvaroNeural"
RATE = "-4%"

# Example narration. Replace every line with copy for the product you are demoing;
# these exist to show the shape (one idea per scene, short sentences, a concrete
# closing action) and the slug naming the audio mixer expects.
SCENES = [
    ("01_hook", "Tu equipo responde las mismas preguntas cada semana."),
    ("02_product", "<Producto> convierte tu documentación en respuestas, controladas por tu equipo."),
    ("03_dashboard", "En el panel ves de un vistazo tus fuentes, tus asistentes activos y los canales abiertos."),
    ("04_knowledge", "Subes la documentación de referencia: manuales, procedimientos y preguntas frecuentes ya validadas."),
    ("05_agent", "Defines tono, instrucciones y qué fuentes puede consultar. No improvisa: responde solo con información validada."),
    ("06_chat", "Quien pregunta lo hace en lenguaje natural y obtiene respuesta inmediata, con la fuente citada."),
    ("07_channels", "Publicas el mismo asistente en varios canales. Y mantienes el control sobre proveedor, modelo y credenciales."),
    ("08_outro", "<Producto>. El siguiente paso es un piloto con un caso real."),
]


async def synth_one(slug: str, text: str) -> Path:
    mp3 = OUT / f"{slug}.mp3"
    tts = edge_tts.Communicate(text=text, voice=VOICE, rate=RATE)
    await tts.save(str(mp3))
    return mp3


def mp3_to_wav(mp3: Path) -> Path:
    wav = mp3.with_suffix(".wav")
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(mp3), "-ar", "44100", "-ac", "2", str(wav)],
        check=True,
        capture_output=True,
    )
    return wav


def wav_duration(wav: Path) -> float:
    with wave.open(str(wav), "rb") as f:
        return f.getnframes() / f.getframerate()


async def main() -> None:
    manifest = []
    for slug, text in SCENES:
        print(f"  · {slug}")
        mp3 = await synth_one(slug, text)
        wav = mp3_to_wav(mp3)
        dur = wav_duration(wav)
        manifest.append({
            "slug": slug,
            "text": text,
            "mp3": mp3.name,
            "wav": wav.name,
            "duration": round(dur, 3),
        })
        mp3.unlink()
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    total = sum(item["duration"] for item in manifest)
    print(f"\nTotal narration: {total:.2f}s")


if __name__ == "__main__":
    asyncio.run(main())
