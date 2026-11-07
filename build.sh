#!/usr/bin/env bash
# Optional: join every part into ONE self-contained file (dist/Hanami.lua).
# The loader does the same thing at runtime, so you usually do NOT need this.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p dist
out="dist/Hanami.lua"
: > "$out"

for f in src/*.lua; do
    cat "$f" >> "$out"
    printf '\n\n' >> "$out"
done

echo "built $out ($(wc -l < "$out") lines)"
