#!/usr/bin/env python3
"""Sanity-check the split parts and the loader before you push.

  python3 tools/verify.py

Checks:
  * every src/*.lua file is listed in loader.lua, in the right order
  * no part ends mid-statement / without a newline
  * only the LAST part has a top-level `return` (it would end the chunk early)
  * build.sh output matches the Luau-safe hoisted join
  * Luau's 200-local-register budget is respected (see below)

Why the register check matters
------------------------------
`luaparse` (Lua 5.1) happily parses a chunk with 300 locals, but Luau
refuses to compile it:

    [string "Hanami"]:3904: Out of local registers when trying to
    allocate playerSec: exceeded limit 200

That was a real executor error. Joining the parts used to put 225
column-1 locals in ONE function. loader.lua now hoists those into the
chunk environment, so the main chunk needs zero registers. We check that
here, plus a conservative bound on locals inside any single part, plus
that loader.lua actually performs the hoist.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hoist import joined  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
LOADER = ROOT / "loader.lua"

LUAU_MAX_LOCALS = 200
SAFE_BUDGET = 180  # leave headroom for loop vars / params / upvalues

TOP_LOCAL = re.compile(r"^local[ \t]+(.*)$")
ANY_LOCAL = re.compile(r"^[ \t]*local[ \t]+(.*)$")
TOP_LOOP = re.compile(r"^(?:for|while)\b")
ANY_LOOP = re.compile(r"^[ \t]*(?:for|while)\b")


def count_local_names(text: str, pattern: re.Pattern[str]) -> int:
    """Registers consumed by `local` declarations matching `pattern`."""
    total = 0
    for line in text.splitlines():
        m = pattern.match(line)
        if not m:
            continue
        rest = m.group(1)
        if re.match(r"^function\b", rest):  # `local function f` = 1 register
            total += 1
            continue
        names = re.findall(r"[A-Za-z_]\w*", rest.split("=", 1)[0])
        total += len(names) or 1
    return total


def main() -> int:
    errors: list[str] = []
    parts = sorted(p.name for p in SRC.glob("*.lua"))

    loader = LOADER.read_text(encoding="utf-8")
    listed = re.findall(r'"(\d\d_[a-z_]+\.lua)"', loader)
    if listed != parts:
        errors.append(f"loader.lua PARTS != src/*.lua\n  loader: {listed}\n  disk:   {parts}")

    # The loader MUST hoist column-1 locals, otherwise the register fix is gone.
    if "local function hoist(src)" not in loader or "hoist(fetch(name))" not in loader:
        errors.append("loader.lua no longer hoists top-level locals (register overflow returns)")

    raw_parts: list[str] = []
    for name in parts:
        text = (SRC / name).read_text(encoding="utf-8")
        raw_parts.append(text)
        if not text.endswith("\n"):
            errors.append(f"{name}: missing trailing newline (parts get concatenated)")
        if text.rstrip().endswith("--"):
            errors.append(f"{name}: ends with a bare line comment")
        if name != parts[-1] and re.search(r"^return\b", text, re.M):
            errors.append(f"{name}: top-level `return` would truncate the joined chunk")
        for i, ln in enumerate(text.splitlines(), 1):
            m = TOP_LOCAL.match(ln)
            if m and "=" not in m.group(1).partition("--")[0] and not m.group(1).startswith("function"):
                errors.append(
                    f"{name}:{i}: column-1 `local` without `=` — use `local a, b = nil, nil`"
                )

        # Conservative upper bound: no single function can have more locals
        # than its whole part file. Indented locals are still real registers.
        inner = count_local_names(text, ANY_LOCAL)
        loops = 3 * sum(1 for ln in text.splitlines() if ANY_LOOP.match(ln))
        if inner + loops >= SAFE_BUDGET:
            errors.append(
                f"{name}: ~{inner + loops} local registers in one part "
                f"(Luau limit {LUAU_MAX_LOCALS})"
            )
        print(f"  {name:32s} {len(text.splitlines()):4d} lines  ~{inner + loops:3d} regs")

    subprocess.run(["bash", str(ROOT / "build.sh")], check=True, capture_output=True)
    built = (ROOT / "dist" / "Hanami.lua").read_text(encoding="utf-8")
    if built != joined(hoisted=True):
        errors.append("build.sh output does not match the Luau-safe hoisted join")

    raw_join = "\n\n".join(raw_parts) + "\n\n"
    raw_top = count_local_names(raw_join, TOP_LOCAL)
    compiled_top = count_local_names(built, TOP_LOCAL)
    loops = 3 * sum(1 for ln in built.splitlines() if TOP_LOOP.match(ln))
    print(
        f"\nLuau register budget: raw main chunk {raw_top} top-level locals; "
        f"compiled main chunk {compiled_top} locals + ~{loops} loop regs "
        f"= {compiled_top + loops} / {LUAU_MAX_LOCALS}"
    )
    if compiled_top + loops >= SAFE_BUDGET:
        errors.append(
            f"compiled main chunk needs ~{compiled_top + loops} registers "
            f"(Luau limit {LUAU_MAX_LOCALS}) — hoisting is incomplete"
        )
    if compiled_top != 0:
        errors.append(f"{compiled_top} column-1 `local`s survived hoisting")

    # A hoisted `local x` with no `=` would become a bare expression and
    # fail to parse. Hoisting removes every column-1 local, so guard anyway.
    for i, line in enumerate(built.splitlines(), 1):
        if re.match(r"^local[ \t]+[A-Za-z_][\w, \t]*$", line):
            errors.append(f"compiled line {i}: bare `local` without `=`")

    if errors:
        for e in errors:
            print("FAIL: " + e, file=sys.stderr)
        return 1
    print(f"\nOK: {len(parts)} parts, loader list matches, Luau-safe join is valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
