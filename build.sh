#!/usr/bin/env bash
# Optional: join every part into ONE self-contained file (dist/Hanami.lua).
# Uses the SAME hoisting as loader.lua so the result compiles in Luau's
# 200-local-register limit. The loader does this at runtime, so you
# normally do NOT need this file.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p dist
out="dist/Hanami.lua"
python3 tools/hoist.py > "$out"

echo "built $out ($(wc -l < "$out") lines)"
