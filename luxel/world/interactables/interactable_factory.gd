class_name LxInteractableFactory
extends RefCounted
## Maps placement JSON interactable `kind` strings to concrete LxInteractable scripts.

const SCRIPTS: Dictionary = {
	"beacon": preload("res://luxel/world/interactables/beacon.gd"),
	"waystone": preload("res://luxel/world/interactables/waystone.gd"),
	"shrine": preload("res://luxel/world/interactables/shrine.gd"),
	"door": preload("res://luxel/world/interactables/door.gd"),
	"ward_barrier": preload("res://luxel/world/interactables/door.gd"),
	"locked_door": preload("res://luxel/world/interactables/door.gd"),
	"boss_door": preload("res://luxel/world/interactables/door.gd"),
	"boss_key": preload("res://luxel/world/interactables/door.gd"),
	"combat_gate": preload("res://luxel/world/interactables/door.gd"),
	"switch_door": preload("res://luxel/world/interactables/door.gd"),
	"bridge_platform": preload("res://luxel/world/interactables/door.gd"),
	"wick_key": preload("res://luxel/world/interactables/wick_key.gd"),
	"keepers_flame": preload("res://luxel/world/interactables/wick_key.gd"),
	"key": preload("res://luxel/world/interactables/wick_key.gd"),
	"switch_eye": preload("res://luxel/world/interactables/switch_eye.gd"),
	"switch": preload("res://luxel/world/interactables/switch_eye.gd"),
	"brazier": preload("res://luxel/world/interactables/brazier.gd"),
	"road_lamp": preload("res://luxel/world/interactables/road_lamp.gd"),
	"lamp": preload("res://luxel/world/interactables/road_lamp.gd"),
	"chest": preload("res://luxel/world/interactables/chest.gd"),
	"rest_shrine": preload("res://luxel/world/interactables/rest_shrine.gd"),
	"great_lamp": preload("res://luxel/world/interactables/great_lamp.gd"),
	"great_belfry_brazier": preload("res://luxel/world/interactables/great_lamp.gd"),
	"mirror": preload("res://luxel/world/interactables/mirror.gd"),
	"blue_transformer": preload("res://luxel/world/interactables/mirror.gd"),
	"transformer": preload("res://luxel/world/interactables/mirror.gd"),
	"blue_portal": preload("res://luxel/world/interactables/blue_portal.gd"),
	"portal": preload("res://luxel/world/interactables/blue_portal.gd"),
	"cracked_wall": preload("res://luxel/world/interactables/cracked_wall.gd"),
	"cracked": preload("res://luxel/world/interactables/cracked_wall.gd"),
	"bramble": preload("res://luxel/world/interactables/bramble.gd"),
	"web": preload("res://luxel/world/interactables/web.gd"),
	"tide_gate": preload("res://luxel/world/interactables/tide_gate.gd"),
	"tide": preload("res://luxel/world/interactables/tide_gate.gd"),
	"phantom_platform": preload("res://luxel/world/interactables/phantom_platform.gd"),
	"phantom": preload("res://luxel/world/interactables/phantom_platform.gd"),
	"obsidian_seal": preload("res://luxel/world/interactables/obsidian_seal.gd"),
	"seal": preload("res://luxel/world/interactables/obsidian_seal.gd"),
	"lantern_pickup": preload("res://luxel/world/interactables/lantern_pickup.gd"),
}


static var _pack_script_cache: Dictionary = {}


static func create(spec: Dictionary) -> LxInteractable:
	var kind: String = str(spec.get("kind", "")).strip_edges().to_lower()
	var scr: Variant = SCRIPTS.get(kind, null)
	if scr == null:
		scr = _load_pack_script(kind)
	if scr is GDScript:
		var inst: Variant = (scr as GDScript).new()
		if inst is LxInteractable:
			return inst as LxInteractable
	push_warning("LxInteractableFactory: unknown kind '%s', using base LxInteractable" % kind)
	return LxInteractable.new()


static func _load_pack_script(kind: String) -> GDScript:
	var packs: LxPackRegistry = Lx.packs if Lx.packs != null else Lx.ensure_packs()
	var spath: String = packs.interactable_script(kind)
	if spath.is_empty():
		return null
	if _pack_script_cache.has(spath):
		return _pack_script_cache[spath] as GDScript
	if ResourceLoader.exists(spath):
		var res: Resource = ResourceLoader.load(spath)
		if res is GDScript:
			_pack_script_cache[spath] = res
			return res as GDScript
	return null


static func known_kinds() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in SCRIPTS.keys():
		out.append(str(k))
	if Lx.packs != null:
		for pk: String in Lx.packs.all_interactable_kinds():
			if not SCRIPTS.has(pk):
				out.append(pk)
	return out
