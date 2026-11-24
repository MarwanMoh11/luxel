"""Theme registry & public lookup API for Luxel Epic themes."""
from __future__ import annotations

from .base import ThemePainter, ThemeSpec
from .caves import build_cave_painters
from .island_1_2 import SPECS_1_2
from .island_3_4 import SPECS_3_4
from .island_5_6 import SPECS_5_6
from .island_7_8 import SPECS_7_8, build_archive_painters

_PAINTERS: dict[str, ThemePainter] = {}
_SPECS: dict[str, ThemeSpec] = {}

ALIASES: dict[str, str] = {
    "ember_express_interior": "ember_express",
    "inverted_palace": "inverted_palace_silver",
    "wick_house_hub": "wick_house",
}


def _init_registry() -> None:
    if _PAINTERS:
        return
    for spec, cls in SPECS_1_2 + SPECS_3_4 + SPECS_5_6 + SPECS_7_8:
        _SPECS[spec.id] = spec
        _PAINTERS[spec.id] = cls(spec)
    for spec, painter in build_archive_painters():
        _SPECS[spec.id] = spec
        _PAINTERS[spec.id] = painter
    for spec, painter in build_cave_painters():
        _SPECS[spec.id] = spec
        _PAINTERS[spec.id] = painter


def resolve_theme_id(theme_id: str) -> str:
    _init_registry()
    key = theme_id.strip().lower()
    return ALIASES.get(key, key)


def has_theme(theme_id: str) -> bool:
    _init_registry()
    return resolve_theme_id(theme_id) in _PAINTERS


def get_theme(theme_id: str) -> ThemePainter:
    _init_registry()
    key = resolve_theme_id(theme_id)
    if key not in _PAINTERS:
        known = ", ".join(sorted(_PAINTERS.keys()))
        raise KeyError(f"Unknown theme '{theme_id}'. Available: {known}")
    return _PAINTERS[key]


def get_spec(theme_id: str) -> ThemeSpec:
    _init_registry()
    return _SPECS[resolve_theme_id(theme_id)]


def list_themes() -> list[str]:
    _init_registry()
    return list(_PAINTERS.keys())
