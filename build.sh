#!/usr/bin/env bash
# Build a flashable Magisk module zip.
set -euo pipefail
cd "$(dirname "$0")"

VER="$(sed -n 's/^version=//p' module.prop | head -n1)"
OUT="audioheal-${VER:-dev}.zip"
rm -f "$OUT"

FILES=(
  module.prop
  service.sh
)

zip -q -r9 "$OUT" "${FILES[@]}"
echo "built $OUT"
unzip -l "$OUT"
