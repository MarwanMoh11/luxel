"""Luxel's icon and the web shell's pixel data (one source for both).

Draws the lantern icon (32x32, the 20 Last Light colours) and writes:
  res://icon.png        256x256 (8x nearest): config/icon, the web favicon and apple-touch icon
  web/icon.ico          Windows (16, 32, 48, 64, 128, 256)
  web/icon.icns         macOS (iconutil; padded so it sits like other Dock icons)
and rewrites the generated blocks in web/shell.html: the lantern grid and the 3x5 font (art/ui/font.png).

Run from the project folder (no Python here has Pillow):
  uv run --no-project --with pillow python web/make_icon.py
"""
import math
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PAL = {
    "void": "0d0b1e", "night": "211a3b", "dusk": "3d2c5c", "plum": "6a3d6f", "wine": "a0466a",
    "coral": "e2725b", "apricot": "f5a96a", "gold": "ffd98c", "cream": "fff4dc", "mauve": "8a6e91",
    "stone": "c2a7ae",
}
# Grid codes. Lowercase = the lantern's body (always drawn), digits = glass (lit or dark), uppercase = halo
# (lit only). The shell maps the same codes.
CODES = {
    "v": "void", "n": "night", "d": "dusk", "m": "mauve", "s": "stone",
    "1": "apricot", "2": "gold", "3": "cream",
    "W": "wine", "P": "plum", "D": "dusk", "N": "night",
}
FONT_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-:x/.+="
N = 32


def lantern() -> list[list[str]]:
    g = [["." for _ in range(N)] for _ in range(N)]

    def put(x: int, y: int, c: str) -> None:
        g[y][x] = c

    def row(x0: int, x1: int, y: int, c: str) -> None:
        for x in range(x0, x1 + 1):
            put(x, y, c)

    # The ring handle, lit from the west.
    row(14, 17, 4, "m"); put(14, 4, "s"); put(15, 4, "s")
    put(13, 5, "s"); put(18, 5, "d"); put(13, 6, "m"); put(18, 6, "n")
    # The cap: dusk metal, lit top and left, shaded right.
    row(13, 18, 7, "d"); put(13, 7, "m"); put(14, 7, "m"); put(18, 7, "n")
    row(11, 20, 8, "d"); put(11, 8, "m"); put(12, 8, "m"); row(13, 16, 8, "m"); put(20, 8, "n")
    row(10, 21, 9, "d"); put(10, 9, "m"); put(21, 9, "n")
    row(10, 21, 10, "n")
    # The posts and the glass.
    for y in range(11, 22):
        put(10, y, "m" if y < 15 else "d")
        put(21, y, "n")
        for x in range(11, 21):
            put(x, y, "1" if x in (11, 20) or y in (11, 21) else "2")
    for y, (x0, x1) in {13: (15, 16), 14: (15, 16), 15: (14, 17), 16: (14, 17), 17: (14, 17), 18: (15, 16)}.items():
        row(x0, x1, y, "3")
    # The base.
    row(10, 21, 22, "d"); put(10, 22, "m"); put(21, 22, "n")
    row(11, 20, 23, "d"); put(11, 23, "m"); put(20, 23, "n")
    row(12, 19, 24, "n")
    # A void outline, so the lantern stands out of its own glow.
    body = {(x, y) for y in range(N) for x in range(N) if g[y][x] != "."}
    for x, y in list(body):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < N and 0 <= ny < N and g[ny][nx] == ".":
                put(nx, ny, "v")
    # The halo: ordered (checker) dither in rings, never a smooth gradient.
    for y in range(N):
        for x in range(N):
            if g[y][x] != ".":
                continue
            r = math.hypot(x - 15.5, y - 16.0)
            chk = (x + y) % 2 == 0
            if r < 8.5:
                put(x, y, "W" if chk else "P")
            elif r < 11.0:
                put(x, y, "P" if chk else "D")
            elif r < 13.5:
                put(x, y, "D" if chk else "N")
            elif r < 15.5 and chk:
                put(x, y, "N")
    return g


def rgba(hex6: str) -> tuple[int, int, int, int]:
    return (int(hex6[0:2], 16), int(hex6[2:4], 16), int(hex6[4:6], 16), 255)


def tile(g: list[list[str]]) -> Image.Image:
    """The icon at 32x32: a void tile with rounded corners, the lit lantern on it."""
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    rad = 4
    for y in range(N):
        for x in range(N):
            cx = min(max(x, rad - 0.5), N - rad - 0.5)
            cy = min(max(y, rad - 0.5), N - rad - 0.5)
            if math.hypot(x - cx, y - cy) > rad - 0.25:
                continue
            c = g[y][x]
            img.putpixel((x, y), rgba(PAL[CODES[c]] if c != "." else PAL["void"]))
    return img


def scaled(img: Image.Image, size: int, pad: int = 0) -> Image.Image:
    """Whole-pixel scaling only: nearest up, box down (16 px)."""
    inner = size - 2 * pad
    if inner < N:
        small = img.resize((inner, inner), Image.Resampling.BOX)
    else:
        small = img.resize((inner, inner), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(small, (pad, pad))
    return out


def font_bits() -> list[int]:
    font = Image.open(ROOT / "art/ui/font.png").convert("RGBA")
    out = []
    for i in range(len(FONT_CHARS)):
        bits = 0
        for y in range(5):
            for x in range(3):
                if font.getpixel((i * 3 + x, y))[3] > 127:
                    bits |= 1 << (y * 3 + x)
        out.append(bits)
    return out


def patch_shell(g: list[list[str]]) -> None:
    shell = ROOT / "web/shell.html"
    text = shell.read_text()
    rows = ",\n".join(f"\t\t'{''.join(r)}'" for r in g)
    text = re.sub(r"(// LANTERN-BEGIN\n).*?(\t*// LANTERN-END)", lambda m: f"{m.group(1)}\t\tconst LANTERN = [\n{rows},\n\t\t];\n{m.group(2)}", text, flags=re.S)
    bits = ", ".join(str(b) for b in font_bits())
    text = re.sub(r"(// FONT-BEGIN\n).*?(\t*// FONT-END)", lambda m: f"{m.group(1)}\t\tconst FONT_CHARS = '{FONT_CHARS}';\n\t\tconst FONT_BITS = [{bits}];\n{m.group(2)}", text, flags=re.S)
    shell.write_text(text)


def main() -> None:
    g = lantern()
    icon = tile(g)
    scaled(icon, 256).save(ROOT / "icon.png")
    ico_sizes = [16, 32, 48, 64, 128, 256]
    big = scaled(icon, 256)
    big.save(ROOT / "web/icon.ico", sizes=[(s, s) for s in ico_sizes],
             append_images=[scaled(icon, s) for s in ico_sizes if s != 256])
    # macOS: art pixels stay whole; from 128 up the tile is padded (~10%) like other Dock icons.
    mac = {16: (16, 0), 32: (32, 0), 64: (64, 0), 128: (128, 16), 256: (256, 32), 512: (512, 48), 1024: (1024, 96)}
    names = {"icon_16x16": 16, "icon_16x16@2x": 32, "icon_32x32": 32, "icon_32x32@2x": 64, "icon_128x128": 128,
             "icon_128x128@2x": 256, "icon_256x256": 256, "icon_256x256@2x": 512, "icon_512x512": 512,
             "icon_512x512@2x": 1024}
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "luxel.iconset"
        iconset.mkdir()
        for name, s in names.items():
            scaled(icon, *mac[s]).save(iconset / f"{name}.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ROOT / "web/icon.icns")], check=True)
    patch_shell(g)
    print("icon.png, web/icon.ico, web/icon.icns written; shell.html data patched")


if __name__ == "__main__":
    main()
