#!/usr/bin/env bash

set -euo pipefail

top_output="$(top -l 1 -n 0 2>/dev/null)"
total_mem_bytes="$(sysctl -n hw.memsize 2>/dev/null || printf '0')"

TOP_OUTPUT="$top_output" python3 - "$total_mem_bytes" <<'PY'
import os
import re
import sys

text = os.environ.get("TOP_OUTPUT", "")
try:
    total_mem = int(sys.argv[1])
except Exception:
    total_mem = 0

cpu_match = re.search(r"CPU usage:\s*([0-9.]+)%\s*user,\s*([0-9.]+)%\s*sys,\s*([0-9.]+)%\s*idle", text)
phys_match = re.search(r"PhysMem:\s*([^\n]+)", text)

cpu_used = 0.0
if cpu_match:
    cpu_used = float(cpu_match.group(1)) + float(cpu_match.group(2))

def parse_size(token: str) -> float:
    token = token.strip()
    m = re.match(r"([0-9.]+)\s*([KMGTP])", token)
    if not m:
        return 0.0
    value = float(m.group(1))
    unit = m.group(2)
    scale = {
        "K": 1024,
        "M": 1024 ** 2,
        "G": 1024 ** 3,
        "T": 1024 ** 4,
        "P": 1024 ** 5,
    }[unit]
    return value * scale

used_mem = 0.0
if phys_match:
    line = phys_match.group(1)
    used = re.search(r"([0-9.]+\s*[KMGTP])\s*used", line)
    if used:
        used_mem = parse_size(used.group(1))

if total_mem <= 0 and used_mem > 0:
    total_mem = int(used_mem)

mem_pct = (used_mem / total_mem * 100.0) if total_mem > 0 else 0.0

def bar(pct: float, width: int = 12) -> str:
    pct = max(0.0, min(100.0, pct))
    filled = int(round((pct / 100.0) * width))
    return "#" * filled + "-" * (width - filled)

def color_for_pct(pct: float) -> str:
    if pct >= 85:
        return "colour196"  # red
    if pct >= 60:
        return "colour220"  # yellow
    return "colour46"       # green

cpu_color = color_for_pct(cpu_used)
mem_color = color_for_pct(mem_pct)

used_gb = used_mem / (1024 ** 3) if used_mem else 0.0
total_gb = total_mem / (1024 ** 3) if total_mem else 0.0

cpu_part = f"#[fg=colour45,bold]CPU #[fg={cpu_color}]{bar(cpu_used)} {cpu_used:4.1f}%"
mem_part = f"#[fg=colour45,bold] RAM #[fg={mem_color}]{bar(mem_pct)} {used_gb:4.1f}/{total_gb:4.1f}G"
print(cpu_part + mem_part + " #[default]")
PY
