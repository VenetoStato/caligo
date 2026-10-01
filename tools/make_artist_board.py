"""Generate a simple local HTML board for ArtistDrop slots.

Usage:
    python tools/make_artist_board.py
Opens Landscape/Dogana/ArtistDrop/BOARD.html in the browser (optional --open).
"""

from __future__ import annotations

import argparse
import json
import sys
import webbrowser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DROP = ROOT / "Landscape" / "Dogana" / "ArtistDrop"
SLOTS = DROP / "SLOTS.json"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--open", action="store_true")
    args = parser.parse_args([] if argv is None else argv)
    data = json.loads(SLOTS.read_text(encoding="utf-8"))
    cards = []
    for slot in data["slots"]:
        drop_file = DROP / slot["file"]
        live = ROOT / slot["dest"]
        src = drop_file if drop_file.exists() else live
        rel = src.relative_to(DROP).as_posix() if src.exists() and DROP in src.parents else (
            Path("..") / Path(slot["dest"]).relative_to("Landscape/Dogana")
        ).as_posix() if live.exists() else ""
        # Prefer relative path from BOARD.html location (ArtistDrop/)
        if drop_file.exists():
            img = slot["file"]
        elif live.exists():
            img = f"../{Path(slot['dest']).relative_to('Landscape/Dogana').as_posix()}"
        else:
            img = ""
        size = slot.get("size") or ["?", "?"]
        cards.append(
            f"""
            <article class="card">
              <div class="preview">{'<img src="{img}" alt="{slot["file"]}"/>' if img else '<div class="missing">manca</div>'}</div>
              <h2>{slot["file"]}</h2>
              <p class="meta">{slot.get("kind","")} · {size[0]}×{size[1]} · <code>{slot.get("profile","")}</code></p>
              <p>{slot.get("notes","")}</p>
              <p class="dest"><code>{slot["dest"]}</code></p>
            </article>
            """
        )
    html = f"""<!doctype html>
<html lang="it"><head>
<meta charset="utf-8"/>
<title>Caligo ArtistDrop Board</title>
<style>
body{{margin:0;font:14px/1.4 Georgia,serif;background:#0d1214;color:#d9e2dc}}
header{{padding:24px 28px;border-bottom:1px solid #2a3532}}
h1{{margin:0 0 6px;font-weight:600;letter-spacing:.02em}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px;padding:20px}}
.card{{background:#141b1d;border:1px solid #2c3a36;border-radius:10px;padding:12px}}
.preview{{aspect-ratio:16/10;background:#0a0e10;display:flex;align-items:center;justify-content:center;overflow:hidden;border-radius:6px}}
.preview img{{max-width:100%;max-height:100%;object-fit:contain}}
.missing{{opacity:.45}}
h2{{font-size:15px;margin:10px 0 4px}}
.meta,.dest{{opacity:.7;font-size:12px}}
code{{font-family:Consolas,monospace}}
</style></head><body>
<header>
  <h1>Caligo — ArtistDrop</h1>
  <p>Sostituisci i PNG in questa cartella, poi esegui <code>python tools/sync_artist_drop.py</code></p>
</header>
<section class="grid">
{''.join(cards)}
</section>
</body></html>
"""
    out = DROP / "BOARD.html"
    out.write_text(html, encoding="utf-8")
    print(f"Wrote {out}")
    if args.open:
        webbrowser.open(out.as_uri())
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
