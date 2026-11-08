#!/usr/bin/env python3
"""Build the Luau-safe single chunk from the split parts.

Luau allows at most 200 live local registers in ONE compiled function. The
parts are written as one logical script with shared `local`s; naively
concatenating all of them puts hundreds of top-level locals in the main chunk, and
the executor refuses to compile it:

    [string "Hanami"]:3904: Out of local registers when trying to
    allocate playerSec: exceeded limit 200

`hoist()` rewrites every column-1 ``local X = ...`` into ``X = ...`` so the
shared names live in the chunk environment instead of consuming registers.
Indented `local`s (inside functions) are left alone. This is exactly what
loader.lua does at runtime, so `dist/Hanami.lua` is the same source.

    python3 tools/hoist.py > dist/Hanami.lua
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# ^ with MULTILINE == a column-1 declaration only. Mirrors loader.lua's
# "\nlocal[ \t]+([^\n]*)" gsub exactly, including the bare-local guard.
TOP_LOCAL_LINE = re.compile(r"^local[ \t]+([^\n]*)", re.M)


def hoist(src: str) -> str:
    """Strip `local ` from column-1 declarations only.

    Indented locals (inside functions) stay local. A bare `local x, y`
    would become a bare expression after stripping, so emit `= nil`.
    """
    def repl(m: re.Match[str]) -> str:
        rest = m.group(1)
        head, sep, tail = rest.partition("--")
        if not rest.startswith("function") and "=" not in head:
            return head + "= nil " + (sep + tail if sep else "")
        return rest

    return TOP_LOCAL_LINE.sub(repl, src)


def parts() -> list[Path]:
    return sorted(SRC.glob("*.lua"))


def joined(*, hoisted: bool = True) -> str:
    texts = [p.read_text(encoding="utf-8") for p in parts()]
    if hoisted:
        texts = [hoist(t) for t in texts]
    return "\n\n".join(texts) + "\n\n"


if __name__ == "__main__":
    sys.stdout.write(joined(hoisted=True))
