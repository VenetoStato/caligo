"""Remove connected light preview backgrounds from generated prop artwork.

Usage:
    python tools/prepare_artist_asset.py path/to/prop.png [...]

The script preserves canvas dimensions and only removes neutral, bright pixels
connected to an image edge. Dark/light details enclosed by the prop are retained.
"""

from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

from PIL import Image


def is_preview_background(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = pixel
    return min(red, green, blue) >= 202 and max(red, green, blue) - min(red, green, blue) <= 24


def remove_connected_background(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    queue: deque[tuple[int, int]] = deque()
    visited = bytearray(width * height)

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if visited[index]:
            continue
        visited[index] = 1
        if not is_preview_background(pixels[x, y]):
            continue
        red, green, blue, _alpha = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))

    # Checker cells enclosed by nets, handles or ornamental cut-outs are not
    # connected to an outer edge. Remove only near-neutral preview whites here;
    # the stricter threshold preserves pale stone and painted highlights.
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha and min(red, green, blue) >= 225 and max(red, green, blue) - min(red, green, blue) <= 10:
                pixels[x, y] = (red, green, blue, 0)

    image.save(path, optimize=True)
    alpha = image.getchannel("A")
    print(f"{path}: alpha={alpha.getextrema()}")


def main() -> int:
    if len(sys.argv) < 2:
        print("Pass at least one PNG path.", file=sys.stderr)
        return 2
    for argument in sys.argv[1:]:
        remove_connected_background(Path(argument))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
