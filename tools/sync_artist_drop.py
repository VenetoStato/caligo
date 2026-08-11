"""Sync illustrator drop-folder into Caligo Dogana art slots.

Usage:
    python tools/sync_artist_drop.py              # sync all present slots
    python tools/sync_artist_drop.py 12_tide_altar.png
    python tools/sync_artist_drop.py --status     # list missing / present
    python tools/sync_artist_drop.py --seed       # copy current live art into drop as templates
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DROP = ROOT / "Landscape" / "Dogana" / "ArtistDrop"
SLOTS_PATH = DROP / "SLOTS.json"

# Reuse background stripper from prepare_artist_asset.
sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    from prepare_artist_asset import remove_connected_background
except ImportError:  # pragma: no cover
    remove_connected_background = None  # type: ignore


def load_slots() -> list[dict]:
    data = json.loads(SLOTS_PATH.read_text(encoding="utf-8"))
    return list(data["slots"])


def status(slots: list[dict]) -> int:
    print(f"ArtistDrop: {DROP}")
    present = 0
    for slot in slots:
        src = DROP / slot["file"]
        dest = ROOT / slot["dest"]
        mark = "READY" if src.exists() else ("LIVE" if dest.exists() else "MISSING")
        if src.exists():
            present += 1
        print(f"  [{mark:7}] {slot['file']:24} -> {slot['dest']}")
    print(f"{present}/{len(slots)} drop files ready to sync.")
    return 0


def seed(slots: list[dict]) -> int:
    DROP.mkdir(parents=True, exist_ok=True)
    copied = 0
    for slot in slots:
        dest = ROOT / slot["dest"]
        target = DROP / slot["file"]
        if not dest.exists():
            print(f"  skip (no live art): {slot['file']}")
            continue
        if target.exists():
            print(f"  keep existing drop: {slot['file']}")
            continue
        shutil.copy2(dest, target)
        copied += 1
        print(f"  seeded {slot['file']}")
    print(f"Seeded {copied} template files into ArtistDrop.")
    return 0


def sync_one(slot: dict, *, strip_bg: bool) -> bool:
    src = DROP / slot["file"]
    if not src.exists():
        return False
    dest = ROOT / slot["dest"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    if strip_bg and slot.get("kind") in {"prop", "character", "architecture"} and remove_connected_background:
        try:
            remove_connected_background(dest)
        except Exception as exc:  # noqa: BLE001
            print(f"  warn: could not strip background on {dest.name}: {exc}")
    try:
        from PIL import Image

        image = Image.open(dest)
        expected = tuple(slot.get("size") or [])
        if expected and image.size != tuple(expected):
            print(
                f"  warn size {slot['file']}: got {image.size[0]}x{image.size[1]}, "
                f"recommended {expected[0]}x{expected[1]}"
            )
        else:
            print(f"  ok {slot['file']} -> {slot['dest']} ({image.size[0]}x{image.size[1]})")
    except Exception:
        print(f"  ok {slot['file']} -> {slot['dest']}")
    return True


def sync(slots: list[dict], only: list[str] | None, *, strip_bg: bool) -> int:
    names = {Path(name).name for name in (only or [])}
    synced = 0
    for slot in slots:
        if names and slot["file"] not in names:
            continue
        if sync_one(slot, strip_bg=strip_bg):
            synced += 1
        elif names:
            print(f"  missing drop file: {slot['file']}", file=sys.stderr)
            return 1
    if not names and synced == 0:
        print("Nessun file in ArtistDrop da sincronizzare. Usa --seed per i template.")
        return 2
    print(f"Sincronizzati {synced} asset. Riapri/riavvia la scena in Godot.")
    # Aggiorna la board HTML se possibile.
    try:
        from make_artist_board import main as make_board

        make_board()
    except Exception:
        pass
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync Caligo ArtistDrop art slots")
    parser.add_argument("files", nargs="*", help="Optional specific drop filenames")
    parser.add_argument("--status", action="store_true", help="Show drop/live status")
    parser.add_argument("--seed", action="store_true", help="Copy live art into ArtistDrop as templates")
    parser.add_argument("--no-strip", action="store_true", help="Do not remove preview backgrounds")
    args = parser.parse_args()
    if not SLOTS_PATH.exists():
        print(f"Missing {SLOTS_PATH}", file=sys.stderr)
        return 2
    slots = load_slots()
    DROP.mkdir(parents=True, exist_ok=True)
    if args.status:
        return status(slots)
    if args.seed:
        return seed(slots)
    return sync(slots, args.files or None, strip_bg=not args.no_strip)


if __name__ == "__main__":
    raise SystemExit(main())
