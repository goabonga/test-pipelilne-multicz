#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>
#
# Regenerate every package icon + the docs favicon from the canonical
# SVG at `assets/shomer.svg`. Re-run after editing the master SVG.
#
# Per-package SVG copies use the binary name (shomer / shomer-api /
# shomer-job / shomer-ssr) so AppStream's `<icon type="stock">`
# resolves under each package's hicolor entry.
#
# Favicon generation delegates to `scripts/generate_favicon.py`
# (cairosvg + Pillow) — pinned in the workspace's doc dep group.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC="$ROOT/assets/shomer.svg"

if [[ ! -f "$SRC" ]]; then
  echo "regen-icons: missing $SRC" >&2
  exit 1
fi

mkdir -p "$ROOT/packages/cli/data" \
         "$ROOT/packages/api/data" \
         "$ROOT/packages/job/data" \
         "$ROOT/packages/ssr/data"

# Per-package copies — named to match the installed binary so each
# .deb's metainfo.xml can reference `<icon type="stock">shomer-X</icon>`
# without colliding with siblings under /usr/share/icons/hicolor/.
cp "$SRC" "$ROOT/packages/cli/data/shomer.svg"
cp "$SRC" "$ROOT/packages/api/data/shomer-api.svg"
cp "$SRC" "$ROOT/packages/job/data/shomer-job.svg"
cp "$SRC" "$ROOT/packages/ssr/data/shomer-ssr.svg"

# Docs site logo (zensical reads `docs/shomer.svg`).
cp "$SRC" "$ROOT/docs/shomer.svg"

# Docs favicon — Python-based cairosvg+Pillow conversion.
# `--with` pins the two libs ad-hoc so we don't pollute the `doc`
# dep group with a tool only the regen script needs.
uv run --with cairosvg --with Pillow python "$ROOT/scripts/generate_favicon.py" \
  -i "$ROOT/docs/shomer.svg" \
  -o "$ROOT/docs/favicon.ico"

echo "regen-icons: 5 SVG copies + docs/favicon.ico from $SRC"
