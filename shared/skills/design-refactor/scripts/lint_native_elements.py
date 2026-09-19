#!/usr/bin/env python3
"""Fail on native interactive elements that must be custom shadcn/Radix components.

Standing rule for this setup: a native date picker, a raw <select>, a browser
<dialog> or a confirm() is never acceptable in a product surface. They cannot be
styled consistently, they look different on every OS, and they break the single
shared primitive layer the design system depends on.

This is the enforcement point for that rule. Written only as prose it would be a
reminder, and reminders are what the rest of this pipeline exists to replace.

Usage:
  python3 lint_native_elements.py <file-or-dir> [more...]

Exit 0 when clean, 1 when any native element is found.
"""
import re
import sys
from pathlib import Path

EXTS = {".tsx", ".jsx", ".vue", ".svelte", ".astro", ".html", ".htm"}

# (pattern, what it is, what to use instead)
RULES = [
    (r"<select\b", "native <select>", "shadcn Select (Radix Select) or Combobox for search"),
    (r"<option\b", "native <option>", "SelectItem inside a shadcn Select"),
    (r"<datalist\b", "native <datalist>", "shadcn Combobox (Command + Popover)"),
    (r"""<input\b[^>]*type=["']date["']""", "native date input", "shadcn Calendar in a Popover (DatePicker)"),
    (r"""<input\b[^>]*type=["']datetime-local["']""", "native datetime input", "shadcn Calendar + time field"),
    (r"""<input\b[^>]*type=["']time["']""", "native time input", "a custom time field built on Radix"),
    (r"""<input\b[^>]*type=["']color["']""", "native colour input", "a custom colour picker"),
    (r"""<input\b[^>]*type=["']range["']""", "native range input", "shadcn Slider (Radix Slider)"),
    (r"""<input\b[^>]*type=["']checkbox["']""", "native checkbox", "shadcn Checkbox (Radix Checkbox)"),
    (r"""<input\b[^>]*type=["']radio["']""", "native radio", "shadcn RadioGroup (Radix RadioGroup)"),
    (r"""<input\b[^>]*type=["']file["']""", "native file input", "a styled trigger delegating to a hidden input"),
    (r"<dialog\b", "native <dialog>", "shadcn Dialog / AlertDialog (Radix Dialog)"),
    (r"<details\b", "native <details>", "shadcn Accordion or Collapsible (Radix)"),
    (r"<summary\b", "native <summary>", "AccordionTrigger"),
    (r"<progress\b", "native <progress>", "shadcn Progress (Radix Progress)"),
    (r"<meter\b", "native <meter>", "a token-driven meter component"),
    (r"\bwindow\.alert\s*\(|(?<![.\w])alert\s*\(", "window.alert()", "shadcn AlertDialog or a toast"),
    (r"\bwindow\.confirm\s*\(|(?<![.\w])confirm\s*\(", "window.confirm()", "shadcn AlertDialog"),
    (r"\bwindow\.prompt\s*\(|(?<![.\w])prompt\s*\(", "window.prompt()", "a shadcn Dialog with a real field"),
]

COMPILED = [(re.compile(p), what, fix) for p, what, fix in RULES]

# A shadcn component file legitimately wraps the native element it replaces:
# ui/select.tsx IS the Radix wrapper, ui/checkbox.tsx renders a real input.
# Linting those would make the rule unsatisfiable.
EXEMPT = re.compile(r"(^|/)(components/ui|ui)/", re.I)


def iter_files(target: Path):
    if target.is_file():
        if target.suffix.lower() in EXTS:
            yield target
        return
    for p in target.rglob("*"):
        if p.suffix.lower() not in EXTS:
            continue
        parts = set(p.parts)
        if parts & {"node_modules", "dist", "build", ".next", ".git"}:
            continue
        yield p


def main(argv):
    targets = [Path(a) for a in argv[1:]]
    if not targets:
        print(__doc__)
        return 2

    findings = []
    for t in targets:
        if not t.exists():
            print(f"lint_native_elements: no such path: {t}", file=sys.stderr)
            return 2
        for f in iter_files(t):
            if EXEMPT.search(str(f)):
                continue
            try:
                text = f.read_text(errors="replace")
            except OSError:
                continue
            for i, line in enumerate(text.splitlines(), 1):
                if line.lstrip().startswith(("//", "*", "#")):
                    continue
                for rx, what, fix in COMPILED:
                    if rx.search(line):
                        findings.append((f, i, what, fix, line.strip()[:90]))

    if not findings:
        n = sum(1 for t in targets for _ in iter_files(t))
        print(f"lint_native_elements: clean ({n} file(s) checked)")
        return 0

    print(f"lint_native_elements: {len(findings)} native element(s) found\n")
    for f, i, what, fix, snippet in findings:
        print(f"  {f}:{i}")
        print(f"    {what}  ->  use {fix}")
        print(f"    | {snippet}")
    print("\nNative interactive elements are not permitted in this setup.")
    print("See reference/native-to-shadcn.md for the replacement for each one.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
