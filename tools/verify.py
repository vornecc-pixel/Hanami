#!/usr/bin/env python3
"""Sanity-check the split parts and the loader before you push.

  python3 tools/verify.py

Checks:
  * every src/*.lua file is listed in loader.lua, in the right order
  * no part ends mid-statement / without a newline
  * only the LAST part has a top-level `return` (it would end the chunk early)
  * build.sh output matches joining the parts with blank lines
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
LOADER = ROOT / "loader.lua"


def main() -> int:
    errors = []
    parts = sorted(p.name for p in SRC.glob("*.lua"))

    loader = LOADER.read_text(encoding="utf-8")
    listed = re.findall(r'"(\d\d_[a-z_]+\.lua)"', loader)
    if listed != parts:
        errors.append(f"loader.lua PARTS != src/*.lua\n  loader: {listed}\n  disk:   {parts}")

    for name in parts:
        text = (SRC / name).read_text(encoding="utf-8")
        if not text.endswith("\n"):
            errors.append(f"{name}: missing trailing newline (parts get concatenated)")
        if text.rstrip().endswith("--"):
            errors.append(f"{name}: ends with a bare line comment")
        if name != parts[-1] and re.search(r"^return\b", text, re.M):
            errors.append(f"{name}: top-level `return` would truncate the joined chunk")
        print(f"  {name:32s} {len(text.splitlines()):4d} lines")

    subprocess.run(["bash", str(ROOT / "build.sh")], check=True, capture_output=True)
    built = (ROOT / "dist" / "Hanami.lua").read_text(encoding="utf-8")
    joined = "\n\n".join((SRC / n).read_text(encoding="utf-8") for n in parts) + "\n\n"
    if built != joined:
        errors.append("build.sh output does not match the part concatenation")

    if errors:
        for e in errors:
            print("FAIL: " + e, file=sys.stderr)
        return 1
    print(f"\nOK: {len(parts)} parts, loader list matches, join is valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
