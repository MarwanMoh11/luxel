class_name LxBiomePalette
extends RefCounted
## Per-island architectural, flame, barrier, bridge, and HUD accents across Islands 1..8.
## Uses strictly the 20 opaque Last Light palette keys (LxPalette.PAL).

const ACCENTS: Dictionary = {
	1: {"dark": "wine", "mid": "coral", "hi": "apricot", "glow": "gold", "core": "cream", "ward_a": "blue", "ward_b": "sky", "ward_hi": "ice", "border": "gold"},
	2: {"dark": "deep", "mid": "blue", "hi": "sky", "glow": "ice", "core": "cream", "ward_a": "teal", "ward_b": "sky", "ward_hi": "ice", "border": "sky"},
	3: {"dark": "pine", "mid": "teal", "hi": "jade", "glow": "lime", "core": "cream", "ward_a": "pine", "ward_b": "jade", "ward_hi": "lime", "border": "lime"},
	4: {"dark": "teal", "mid": "jade", "hi": "sky", "glow": "ice", "core": "rose", "ward_a": "teal", "ward_b": "ice", "ward_hi": "rose", "border": "ice"},
	5: {"dark": "deep", "mid": "blue", "hi": "sky", "glow": "gold", "core": "cream", "ward_a": "deep", "ward_b": "gold", "ward_hi": "cream", "border": "gold"},
	6: {"dark": "wine", "mid": "coral", "hi": "apricot", "glow": "gold", "core": "cream", "ward_a": "wine", "ward_b": "coral", "ward_hi": "apricot", "border": "coral"},
	7: {"dark": "deep", "mid": "sky", "hi": "ice", "glow": "ice", "core": "cream", "ward_a": "dusk", "ward_b": "sky", "ward_hi": "ice", "border": "ice"},
	8: {"dark": "plum", "mid": "wine", "hi": "rose", "glow": "gold", "core": "cream", "ward_a": "plum", "ward_b": "rose", "ward_hi": "gold", "border": "rose"},
}


static func get_accent(island_id: int) -> Dictionary:
	return ACCENTS.get(clampi(island_id, 1, 8), ACCENTS[1]) as Dictionary


static func key(island_id: int, slot: String) -> String:
	return str(get_accent(island_id).get(slot, "gold"))


static func col(island_id: int, slot: String) -> Color:
	return LxPalette.color(key(island_id, slot), "gold")
