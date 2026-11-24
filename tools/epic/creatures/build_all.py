#!/usr/bin/env python3
"""Build all 8 E0-6 showcase creatures, timing each sheet, and render a side-by-side comparison PNG."""
from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from creature import ART_BOSSES, ART_ENEMIES, CACHE_DIR, export_creature, save_comparison_sheet  # noqa: E402
import sexton  # noqa: E402
import figurehead  # noqa: E402
import hundred_lamps  # noqa: E402
import topiary_knight  # noqa: E402
import comet_hound  # noqa: E402
import slag_slime  # noqa: E402
import glass_knight  # noqa: E402
import toll_moth  # noqa: E402

ALL_SPECS = [
    sexton.SPEC,
    figurehead.SPEC,
    hundred_lamps.SPEC,
    topiary_knight.SPEC,
    comet_hound.SPEC,
    slag_slime.SPEC,
    glass_knight.SPEC,
    toll_moth.SPEC,
]

COMPARISON_PAIRS = [
    ("sexton", ART_BOSSES / "sexton.json", "bellkeeper", ART_BOSSES / "bellkeeper.json"),
    ("figurehead", ART_BOSSES / "figurehead.json", "lighthouse_hermit", ART_BOSSES / "lighthouse_hermit.json"),
    ("hundred_lamps", ART_BOSSES / "hundred_lamps.json", "briar_matron", ART_BOSSES / "briar_matron.json"),
    ("topiary_knight", ART_ENEMIES / "topiary_knight.json", "bramble_knight", ART_ENEMIES / "bramble_knight.json"),
    ("comet_hound", ART_ENEMIES / "comet_hound.json", "astronomer", ART_BOSSES / "astronomer.json"),
    ("slag_slime", ART_ENEMIES / "slag_slime.json", "cinder_golem", ART_ENEMIES / "cinder_golem.json"),
    ("glass_knight", ART_ENEMIES / "glass_knight.json", "spire_warden", ART_BOSSES / "spire_warden.json"),
    ("toll_moth", ART_ENEMIES / "toll_moth.json", "warden", ART_ENEMIES / "warden.json"),
]


def main() -> None:
    preview_dir = CACHE_DIR / "creatures_preview"
    t_total = time.perf_counter()
    slow = []
    for spec in ALL_SPECS:
        t0 = time.perf_counter()
        export_creature(spec, preview_dir=preview_dir, make_gif=True)
        dt = time.perf_counter() - t0
        if dt >= 20.0:
            slow.append((spec.id, dt))
    # Split into two readable comparison plates (bosses + enemies) AND full 8-row sheet!
    save_comparison_sheet(COMPARISON_PAIRS[:4], preview_dir / "comparison_top4.png", scale=2)
    save_comparison_sheet(COMPARISON_PAIRS[4:], preview_dir / "comparison_bot4.png", scale=2)
    save_comparison_sheet(COMPARISON_PAIRS, preview_dir / "comparison_all.png", scale=2)
    print(f"[build_all] built {len(ALL_SPECS)} creatures in {time.perf_counter() - t_total:.2f}s")
    if slow:
        raise RuntimeError(f"Exceeded 20s boss budget: {slow}")


if __name__ == "__main__":
    main()
