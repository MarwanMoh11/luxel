"""Bakes art/ui/font_outline.png from art/ui/font.png for PixelFont.draw.

Each 5x7 cell is the union of the 3x5 glyph shifted by every PixelFont.OUTLINE offset, so one draw call paints
what the five shifted passes painted. Cell i holds glyph i with the glyph at (1, 1) in it.
Run: uv run --no-project --with pillow --with numpy python art/ui/make_font_outline.py
"""
import re
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
gd = (HERE.parent.parent / "scripts/game/ui/pixel_font.gd").read_text()
offsets = [tuple(int(float(n)) for n in m) for m in re.findall(r"Vector2\((-?\d+), (-?\d+)\)", gd.split("OUTLINE")[1].split("\n")[0])]
W, H = 3, 5
CW, CH = W + 2, H + 2  # a cell: the glyph plus 1 px each side

glyphs = np.array(Image.open(HERE / "font.png").convert("RGBA"))[..., 3] > 0
n = glyphs.shape[1] // W
out = np.zeros((CH, CW * n), dtype=bool)
for i in range(n):
    g = glyphs[:, i * W:(i + 1) * W]
    for dx, dy in offsets:
        out[1 + dy:1 + dy + H, i * CW + 1 + dx:i * CW + 1 + dx + W] |= g
rgba = np.zeros((CH, CW * n, 4), dtype=np.uint8)
rgba[out] = 255
Image.fromarray(rgba, "RGBA").save(HERE / "font_outline.png")
print(f"{n} glyphs, {len(offsets)} offsets {offsets} -> font_outline.png {CW * n}x{CH}")
