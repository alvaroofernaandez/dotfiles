"""Build a self-contained CSS file with every brand asset embedded as base64.

Emits `<project>/assets/brand.css` carrying the webfonts (all unicode subsets),
the brand logo in three colourways, the banner, circular team portraits and the
Lucide icon set as CSS masks. The report HTML then renders identically offline and
inside headless Chrome, with no network at print time.

Usage:
    python3 build-assets.py [project_dir] --brand-dir <dir> [--people ana,luis]

Defaults to the current directory and no portraits. The brand directory holds the
logo, the banner and one <name>.jpg per portrait requested via --people; it is
supplied by the caller and never hardcoded here.
"""

import argparse
import base64
import io
import pathlib
import re
import sys
import urllib.request

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow required. Run with: uvx --from pillow python build-assets.py")

# No default under $HOME: a brand directory is specific to whoever is producing the
# document, and baking one in makes the skill carry an organization with it.
parser = argparse.ArgumentParser()
parser.add_argument("project", nargs="?", default=".", help="project directory")
parser.add_argument("--people", default="", help="comma-separated portrait names")
parser.add_argument("--brand-dir", default="brand", help="directory holding the brand images")
parser.add_argument("--logo-file", default="logo.png", help="logo filename inside --brand-dir")
parser.add_argument("--ink", default="23,20,31", help="ink RGB for the dark logo colourway")
parser.add_argument("--accent", default="110,59,106", help="accent RGB for the branded colourway")
args = parser.parse_args()

def _rgb(value: str) -> tuple[int, int, int]:
    parts = tuple(int(n) for n in value.split(","))
    if len(parts) != 3 or not all(0 <= n <= 255 for n in parts):
        sys.exit(f"Expected three 0-255 components, got: {value}")
    return parts

SRC = pathlib.Path(args.brand_dir)
OUT = pathlib.Path(args.project).resolve() / "assets"
OUT.mkdir(parents=True, exist_ok=True)
PEOPLE = [n.strip() for n in args.people.split(",") if n.strip()]

if not SRC.is_dir():
    sys.exit(f"Brand image directory not found: {SRC}")

INK = _rgb(args.ink)
ACCENT = _rgb(args.accent)


def data_uri(raw: bytes, mime: str) -> str:
    return f"data:{mime};base64,{base64.b64encode(raw).decode()}"


def png_uri(im: Image.Image) -> str:
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return data_uri(buf.getvalue(), "image/png")


def jpg_uri(im: Image.Image, quality: int = 86) -> str:
    buf = io.BytesIO()
    im.convert("RGB").save(buf, format="JPEG", quality=quality, optimize=True)
    return data_uri(buf.getvalue(), "image/jpeg")


def recolour_mark(mark: Image.Image, rgb: tuple[int, int, int]) -> Image.Image:
    """Keep the mark's alpha silhouette, replace its colour."""
    alpha = mark.getchannel("A")
    solid = Image.new("RGBA", mark.size, rgb + (255,))
    solid.putalpha(alpha)
    return solid


mark = Image.open(SRC / args.logo_file).convert("RGBA")
mark_small = mark.resize((256, 256), Image.LANCZOS)

assets = {
    "logo-white": png_uri(mark_small),
    "logo-ink": png_uri(recolour_mark(mark_small, INK)),
    "logo-accent": png_uri(recolour_mark(mark_small, ACCENT)),
    "banner": jpg_uri(Image.open(SRC / "banner.png").resize((1200, 300), Image.LANCZOS), 88),
}

def circular_portrait(path: pathlib.Path, size: int = 340) -> Image.Image:
    """Crop to the face, mask to a circle and bake in the ring.

    Relying on CSS `border-radius` + `background-size: cover` puts the crop in the
    hands of whatever renders the PDF, and some viewers get the clip wrong and show
    the sitter's chest. Baking the circle into the asset removes the variable.
    """
    im = Image.open(path).convert("RGB")
    w, h = im.size

    # Head-and-shoulders portraits sit above the geometric centre: crop a square
    # around 44% of the height so the face lands in the middle of the circle.
    side = int(min(w, h) * 0.86)
    cx, cy = w // 2, int(h * 0.44)
    left = max(0, min(w - side, cx - side // 2))
    top = max(0, min(h - side, cy - side // 2))
    im = im.crop((left, top, left + side, top + side)).resize((size, size), Image.LANCZOS)

    # Build the mask at 4x and downsample: gives clean antialiased edges.
    ss = 4
    mask = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * ss - 1, size * ss - 1), fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(im, (0, 0))
    out.putalpha(mask)

    ring = ImageDraw.Draw(out)
    ring.ellipse((1, 1, size - 2, size - 2), outline=(255, 255, 255, 110), width=3)
    return out


for person in PEOPLE:
    matches = sorted(SRC.glob(f"{person}.*"))
    if not matches:
        print(f"  ! portrait not found, skipping: {person}")
        continue
    assets[f"photo-{person}"] = png_uri(circular_portrait(matches[0]))

# Google Fonts serves one @font-face per unicode subset. Taking only the first
# one silently drops accents, ñ and € onto a fallback font, which is invisible in
# thumbnails and obvious in print. Embed every subset with its unicode-range.
FONT_QUERIES = {
    "Fraunces": "Fraunces:opsz,wght@9..144,400;9..144,600;9..144,700;9..144,900",
    "Archivo": "Archivo:wght@400;500;600;700",
    "JetBrains Mono": "JetBrains+Mono:wght@400;500;700",
}
UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)
# Subsets we actually need for a Spanish-language document.
WANTED = ("latin", "latin-ext")

FACE_RE = re.compile(r"/\*\s*(?P<subset>[\w-]+)\s*\*/\s*@font-face\s*\{(?P<body>[^}]+)\}")


def field(body: str, name: str) -> str:
    m = re.search(rf"{name}:\s*([^;]+);", body)
    return m.group(1).strip() if m else ""


lines = ["/* Generated by build-assets.py. Do not edit by hand. */", ""]
face_count = 0

for family, query in FONT_QUERIES.items():
    url = f"https://fonts.googleapis.com/css2?family={query}&display=block"
    css = urllib.request.urlopen(
        urllib.request.Request(url, headers={"User-Agent": UA})
    ).read().decode()

    for face in FACE_RE.finditer(css):
        subset = face.group("subset")
        if subset not in WANTED:
            continue
        body = face.group("body")
        src = re.search(r"url\((https://[^)]+\.woff2)\)", body)
        if not src:
            continue
        raw = urllib.request.urlopen(src.group(1)).read()
        lines += [
            f"/* {family} · {subset} */",
            "@font-face {",
            f"  font-family: '{family}';",
            f"  src: url({data_uri(raw, 'font/woff2')}) format('woff2');",
            f"  font-weight: {field(body, 'font-weight') or '400'};",
            f"  font-style: {field(body, 'font-style') or 'normal'};",
            f"  unicode-range: {field(body, 'unicode-range')};",
            "  font-display: block;",
            "}",
            "",
        ]
        face_count += 1

# Lucide icons ship as stroked SVG. Embedding them as CSS mask-images (rather than
# <img> or inline <svg>) lets a single rule inherit currentColor and font-size, so an
# icon always matches the text it sits next to.
ICONS = [
    "triangle-alert", "circle-check", "circle-x", "clock", "euro", "users", "layers",
    "database", "shopping-cart", "smartphone", "file-pen-line", "search", "shield-check",
    "trending-up", "git-branch", "zap", "target", "lightbulb", "lock", "handshake",
    "wrench", "gauge", "map", "arrow-right", "scan-barcode", "store", "credit-card",
    "ban", "calendar-clock", "hourglass", "signature", "circle-help", "flag", "route",
    "chart-column", "package", "banknote", "milestone", "square-check-big", "minus",
]
LUCIDE = "https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/{}.svg"

icon_vars = []
missing_icons = []
for name in ICONS:
    try:
        svg = urllib.request.urlopen(LUCIDE.format(name)).read().decode()
    except Exception:
        missing_icons.append(name)
        continue
    # A mask uses the alpha channel, so the stroke needs a solid colour, not currentColor.
    svg = svg.replace("currentColor", "#000")
    svg = re.sub(r"<!--.*?-->", "", svg, flags=re.S).strip()
    icon_vars.append(f"  --ic-{name}: url({data_uri(svg.encode(), 'image/svg+xml')});")

lines.append(":root {")
for key, uri in assets.items():
    lines.append(f"  --img-{key}: url({uri});")
lines += icon_vars
lines.append("}")

# One class per icon, all sharing the mask mechanics.
lines += [
    "",
    ".ico {",
    "  display: inline-block;",
    "  width: 1em; height: 1em;",
    "  background-color: currentColor;",
    "  -webkit-mask-size: contain; mask-size: contain;",
    "  -webkit-mask-repeat: no-repeat; mask-repeat: no-repeat;",
    "  -webkit-mask-position: center; mask-position: center;",
    "  vertical-align: -0.135em;",
    "  flex: 0 0 auto;",
    "}",
    "",
]
for name in ICONS:
    if name in missing_icons:
        continue
    lines.append(
        f".ico-{name} {{ -webkit-mask-image: var(--ic-{name}); mask-image: var(--ic-{name}); }}"
    )

(OUT / "brand.css").write_text("\n".join(lines), encoding="utf-8")
size = (OUT / "brand.css").stat().st_size
print(f"{OUT/'brand.css'}: {size/1024:.0f} KB · {len(assets)} images · {face_count} font faces · {len(ICONS)-len(missing_icons)}/{len(ICONS)} icons")
if missing_icons:
    print("MISSING ICONS:", ", ".join(missing_icons))
