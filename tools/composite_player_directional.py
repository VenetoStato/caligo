"""Build up/down attack rows from the original player frames only."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(r"C:\Users\user\caligo")
SHEET = ROOT / "Player" / "Sprites" / "sprite_sheet.png"
BACKUP = ROOT / "tmp" / "sprite_sheet_before_directional.png"
CELL = 640
COLS = 5
SRC_ROWS = 8


def cell(sheet: Image.Image, idx: int) -> Image.Image:
    c, r = idx % COLS, idx // COLS
    return sheet.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL)).copy()


def main() -> None:
    source = BACKUP if BACKUP.exists() else SHEET
    base = Image.open(source).convert("RGBA")
    if base.size[0] != CELL * COLS:
        raise SystemExit(f"Unexpected width {base.size}")
    # Keep only the original 8 rows so AI frames disappear.
    base = base.crop((0, 0, CELL * COLS, CELL * SRC_ROWS))

    up = [cell(base, 0), cell(base, 1), cell(base, 2)]
    down = [cell(base, 31), cell(base, 32), cell(base, 35)]

    out = Image.new("RGBA", (CELL * COLS, CELL * 10), (0, 0, 0, 0))
    out.paste(base, (0, 0))
    for i, src in enumerate(up + [up[2], up[2]]):
        out.paste(src, (i * CELL, CELL * 8))
    for i, src in enumerate(down + [down[2], down[2]]):
        out.paste(src, (i * CELL, CELL * 9))
    out.save(SHEET)
    print("Wrote original-pixel directional rows", SHEET, out.size)


if __name__ == "__main__":
    main()
