class_name LxPackRegistry
extends RefCounted
## Data-driven content registry for Luxel Epic (Lx.packs).
## Discovers res://luxel/data/packs/*.json then res://luxel/islands/<n>/packs/*.json at boot.
## Built-ins stay authoritative; packs win on new IDs and never silently override existing IDs.

const DATA_PACKS_DIR: String = "res://luxel/data/packs"
const ISLANDS_DIR: String = "res://luxel/islands"
const HUB_PACKS_DIR: String = "res://luxel/hub/packs"

const VALID_TOP_KEYS: Array[String] = [
	"pack_id", "version", "owner", "comment", "notes", "strings", "enemies", "bosses",
	"interactables", "dungeons", "regions", "sfx", "quests", "panes", "moths", "state_vars",
]
const VALID_HEARTS: Array[String] = ["full", "half", "none", ""]

var _loaded: bool = false
var quiet_errors: bool = false
var _errors: PackedStringArray = PackedStringArray()
var _pack_files: PackedStringArray = PackedStringArray()

var _builtin_inter_kinds: Dictionary = {}
var _builtin_enemy_kinds: Dictionary = {}
var _builtin_boss_ids: Dictionary = {}
var _builtin_dungeon_ids: Dictionary = {}
var _builtin_sfx_ids: Dictionary = {}

var _interactables: Dictionary = {}      # kind -> script_path
var _enemies: Dictionary = {}            # kind -> {script, data}
var _enemy_aliases: Dictionary = {}      # alias -> canonical kind
var _bosses: Dictionary = {}             # id -> meta dict
var _boss_aliases: Dictionary = {}       # alias -> canonical id
var _strings: Dictionary = {}            # pack-only string_id -> text
var _dungeons: Dictionary = {}           # dungeon_id -> dict
var _dungeons_by_island: Dictionary = {} # int -> Array[String]
var _region_to_dungeon: Dictionary = {}  # "island:region" -> dungeon_id
var _region_meta: Dictionary = {}        # "island:region" -> dict
var _region_meta_source: Dictionary = {} # "island:region" -> source file
var _regions_by_island: Dictionary = {}  # int -> Array[String]
var _sfx: Dictionary = {}                # id -> {cue, pitch, db, variants, trim_db}
var _quests: Dictionary = {}             # id -> dict
var _panes: Dictionary = {}              # id -> dict
var _moths: Dictionary = {}              # id -> dict
var _state_vars: Dictionary = {}         # name -> {scope, values, default}


func load_all() -> void:
	_clear()
	_seed_builtins()
	_discover_disk_regions()
	_load_dir_packs(DATA_PACKS_DIR, -1)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(HUB_PACKS_DIR)):
		_load_dir_packs(HUB_PACKS_DIR, 0)
	for isl: int in range(0, island_count() + 1):
		_load_dir_packs("%s/%d/packs" % [ISLANDS_DIR, isl], isl)
		var pack_gd: String = "%s/%d/pack.gd" % [ISLANDS_DIR, isl]
		if ResourceLoader.exists(pack_gd):
			var sc: Variant = ResourceLoader.load(pack_gd)
			if sc is GDScript:
				var inst: Variant = (sc as GDScript).new()
				if inst is Object and (inst as Object).has_method("register"):
					(inst as Object).call("register", self)
	_loaded = true


func _clear() -> void:
	_loaded = false
	_errors = PackedStringArray()
	_pack_files = PackedStringArray()
	_builtin_inter_kinds.clear(); _builtin_enemy_kinds.clear(); _builtin_boss_ids.clear()
	_builtin_dungeon_ids.clear(); _builtin_sfx_ids.clear()
	_interactables.clear(); _enemies.clear(); _enemy_aliases.clear()
	_bosses.clear(); _boss_aliases.clear(); _strings.clear()
	_dungeons.clear(); _dungeons_by_island.clear(); _region_to_dungeon.clear()
	_region_meta.clear(); _region_meta_source.clear(); _regions_by_island.clear()
	_sfx.clear(); _quests.clear(); _panes.clear(); _moths.clear(); _state_vars.clear()


func _seed_builtins() -> void:
	LxPackBuiltins.seed_registry(self)


func _discover_disk_regions() -> void:
	for isl: int in range(0, island_count() + 1):
		var dir_path: String = "%s/%d" % [ISLANDS_DIR, isl]
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
			_regions_by_island[isl] = []
			continue
		var files: PackedStringArray = DirAccess.get_files_at(dir_path)
		var regs: Array[String] = []
		for fn: String in files:
			if fn.ends_with(".map"):
				var stem: String = fn.trim_suffix(".map")
				if not regs.has(stem):
					regs.append(stem)
		regs.sort()
		_regions_by_island[isl] = regs


func _load_dir_packs(dir_path: String, default_island: int) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		return
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	if files.is_empty():
		return
	var sorted_files: Array[String] = []
	for fn: String in files:
		if fn.ends_with(".json"):
			sorted_files.append(fn)
	sorted_files.sort()
	for fn: String in sorted_files:
		var full: String = dir_path.path_join(fn)
		_pack_files.append(full)
		var raw: String = FileAccess.get_file_as_string(full)
		var parser := JSON.new()
		if parser.parse(raw) != OK or not (parser.data is Dictionary):
			_record_error("%s: invalid JSON (%s)" % [full, parser.get_error_message()])
			continue
		register_fragment(parser.data as Dictionary, full, default_island)


func register_fragment(dict: Dictionary, source: String = "memory", default_island: int = 0) -> void:
	for k_v: Variant in dict.keys():
		var k: String = str(k_v)
		if not VALID_TOP_KEYS.has(k):
			_record_error("%s: unknown top-level key '%s'" % [source, k])
	if dict.has("strings"):
		_reg_strings(dict["strings"], source)
	if dict.has("interactables"):
		_reg_interactables(dict["interactables"], source)
	if dict.has("enemies"):
		_reg_enemies(dict["enemies"], source)
	if dict.has("bosses"):
		_reg_bosses(dict["bosses"], source, default_island)
	if dict.has("dungeons"):
		_reg_dungeons(dict["dungeons"], source, default_island)
	if dict.has("regions"):
		_reg_regions(dict["regions"], source, default_island)
	if dict.has("sfx"):
		_reg_sfx(dict["sfx"], source)
	if dict.has("quests"):
		_reg_named_collection(dict["quests"], _quests, "quest", source)
	if dict.has("panes"):
		_reg_named_collection(dict["panes"], _panes, "pane", source)
	if dict.has("moths"):
		_reg_named_collection(dict["moths"], _moths, "moth", source)
	if dict.has("state_vars"):
		_reg_state_vars(dict["state_vars"], source)


func _reg_strings(v: Variant, source: String) -> void:
	if not (v is Dictionary):
		_record_error("%s: 'strings' must be Dictionary" % source)
		return
	for id_v: Variant in (v as Dictionary).keys():
		var id: String = str(id_v).strip_edges()
		var val: Variant = (v as Dictionary)[id_v]
		if id.is_empty() or not (val is String):
			_record_error("%s: invalid string entry '%s'" % [source, id])
			continue
		if LxStrings.TABLE.has(id) or _strings.has(id):
			_record_error("%s: string collision '%s'" % [source, id])
			continue
		_strings[id] = val as String


func _reg_interactables(v: Variant, source: String) -> void:
	if not (v is Dictionary):
		_record_error("%s: 'interactables' must be Dictionary" % source)
		return
	for k_v: Variant in (v as Dictionary).keys():
		var kind: String = str(k_v).strip_edges().to_lower()
		var raw: Variant = (v as Dictionary)[k_v]
		var spath: String = raw as String if raw is String else (str((raw as Dictionary).get("script", "")) if raw is Dictionary else "")
		if kind.is_empty() or spath.is_empty():
			_record_error("%s: interactable '%s' missing script path" % [source, kind])
			continue
		if _builtin_inter_kinds.has(kind) or _interactables.has(kind):
			_record_error("%s: interactable collision '%s'" % [source, kind])
			continue
		_interactables[kind] = spath


func _reg_enemies(v: Variant, source: String) -> void:
	if not (v is Dictionary):
		_record_error("%s: 'enemies' must be Dictionary" % source)
		return
	for k_v: Variant in (v as Dictionary).keys():
		var kind: String = str(k_v).strip_edges().to_lower()
		var raw: Variant = (v as Dictionary)[k_v]
		if kind.is_empty() or not (raw is Dictionary):
			_record_error("%s: enemy '%s' must be Dictionary" % [source, kind])
			continue
		var ed: Dictionary = raw as Dictionary
		var spath: String = str(ed.get("script", "")).strip_edges()
		if spath.is_empty():
			_record_error("%s: enemy '%s' missing 'script'" % [source, kind])
			continue
		if _builtin_enemy_kinds.has(kind) or _enemies.has(kind):
			_record_error("%s: enemy collision '%s'" % [source, kind])
			continue
		var data_d: Dictionary = (ed["data"] as Dictionary).duplicate(true) if ed.get("data") is Dictionary else {}
		data_d["kind"] = kind
		_enemies[kind] = {"script": spath, "data": data_d}
		var aliases: Variant = ed.get("aliases", [])
		if aliases is Array:
			for al: Variant in (aliases as Array):
				var al_s: String = str(al).strip_edges().to_lower()
				if not al_s.is_empty():
					_enemy_aliases[al_s] = kind


func _reg_bosses(v: Variant, source: String, default_island: int) -> void:
	if not (v is Dictionary):
		_record_error("%s: 'bosses' must be Dictionary" % source)
		return
	for id_v: Variant in (v as Dictionary).keys():
		var bid: String = str(id_v).strip_edges().to_lower()
		var raw: Variant = (v as Dictionary)[id_v]
		if bid.is_empty() or not (raw is Dictionary):
			_record_error("%s: boss '%s' must be Dictionary" % [source, bid])
			continue
		if _builtin_boss_ids.has(bid) or _bosses.has(bid):
			_record_error("%s: boss collision '%s'" % [source, bid])
			continue
		var bd: Dictionary = (raw as Dictionary).duplicate(true)
		var nk: String = str(bd.get("name_key", "")).strip_edges()
		if nk.is_empty():
			_record_error("%s: boss '%s' missing 'name_key'" % [source, bid])
			continue
		var heart: String = str(bd.get("heart", "none")).strip_edges().to_lower()
		if not VALID_HEARTS.has(heart):
			_record_error("%s: boss '%s' invalid heart '%s'" % [source, bid, heart])
			continue
		var phases_v: Variant = bd.get("phases", [0.5])
		if not (phases_v is Array):
			_record_error("%s: boss '%s' phases must be Array" % [source, bid])
			continue
		bd["id"] = bid
		bd["heart"] = "none" if heart.is_empty() else heart
		bd["island"] = int(bd.get("island", maxi(0, default_island)))
		bd["mini"] = bool(bd.get("mini", false))
		bd["arena_lock"] = bool(bd.get("arena_lock", true))
		_bosses[bid] = bd
		if bd.get("aliases") is Array:
			for al: Variant in (bd["aliases"] as Array):
				var al_s: String = str(al).strip_edges().to_lower()
				if not al_s.is_empty():
					_boss_aliases[al_s] = bid


func _reg_dungeons(v: Variant, source: String, default_island: int) -> void:
	var items: Array = []
	if v is Array:
		items = v as Array
	elif v is Dictionary:
		for kv: Variant in (v as Dictionary).keys():
			var dv: Variant = (v as Dictionary)[kv]
			if dv is Dictionary:
				var copy_d: Dictionary = (dv as Dictionary).duplicate(true)
				if not copy_d.has("id"):
					copy_d["id"] = str(kv)
				items.append(copy_d)
	else:
		_record_error("%s: 'dungeons' must be Array or Dictionary" % source)
		return
	for raw: Variant in items:
		if not (raw is Dictionary):
			_record_error("%s: dungeon item must be Dictionary" % source)
			continue
		var d: Dictionary = (raw as Dictionary).duplicate(true)
		var did: String = str(d.get("id", "")).strip_edges()
		if did.is_empty():
			_record_error("%s: dungeon missing 'id'" % source)
			continue
		if _builtin_dungeon_ids.has(did) or _dungeons.has(did):
			_record_error("%s: dungeon collision '%s'" % [source, did])
			continue
		var isl: int = int(d.get("island", default_island))
		if isl < 0:
			_record_error("%s: dungeon '%s' missing valid island" % [source, did])
			continue
		d["island"] = isl
		if str(d.get("done_flag", "")).is_empty():
			d["done_flag"] = "dungeon_done:" + did
		var regs: Array[String] = []
		if d.get("regions") is Array:
			for r_v: Variant in (d["regions"] as Array):
				var rs: String = str(r_v).strip_edges()
				if not rs.is_empty() and not regs.has(rs):
					regs.append(rs)
		var entry_r: String = str(d.get("entry", regs[0] if not regs.is_empty() else "")).strip_edges()
		if not entry_r.is_empty() and not regs.has(entry_r):
			regs.insert(0, entry_r)
		d["entry"] = entry_r
		d["regions"] = regs
		_dungeons[did] = d
		_append_island_dungeon(isl, did)
		for r: String in regs:
			var rkey: String = "%d:%s" % [isl, r]
			if _region_to_dungeon.has(rkey) and str(_region_to_dungeon[rkey]) != did:
				_record_error("%s: region '%s' claimed by both '%s' and '%s'" % [source, rkey, str(_region_to_dungeon[rkey]), did])
			else:
				_region_to_dungeon[rkey] = did
			_ensure_island_region(isl, r)


func _reg_regions(v: Variant, source: String, default_island: int) -> void:
	if not (v is Dictionary):
		_record_error("%s: 'regions' must be Dictionary" % source)
		return
	for rid_v: Variant in (v as Dictionary).keys():
		var rid: String = str(rid_v).strip_edges()
		var raw: Variant = (v as Dictionary)[rid_v]
		if rid.is_empty() or not (raw is Dictionary):
			_record_error("%s: region '%s' must be Dictionary" % [source, rid])
			continue
		var rd: Dictionary = (raw as Dictionary).duplicate(true)
		var isl: int = int(rd.get("island", default_island))
		if isl < 0:
			_record_error("%s: region '%s' missing valid island" % [source, rid])
			continue
		var rkey: String = "%d:%s" % [isl, rid]
		if _region_meta.has(rkey):
			_record_error("%s: region meta collision '%s' (already in %s)" % [source, rkey, str(_region_meta_source.get(rkey, ""))])
			continue
		rd["id"] = rid
		rd["island"] = isl
		_region_meta[rkey] = rd
		_region_meta_source[rkey] = source
		_ensure_island_region(isl, rid)


func _reg_sfx(v: Variant, source: String) -> void:
	if not (v is Dictionary):
		_record_error("%s: 'sfx' must be Dictionary" % source)
		return
	for id_v: Variant in (v as Dictionary).keys():
		var sid: String = str(id_v).strip_edges()
		var raw: Variant = (v as Dictionary)[id_v]
		if sid.is_empty():
			continue
		if _builtin_sfx_ids.has(sid) or _sfx.has(sid):
			_record_error("%s: sfx collision '%s'" % [source, sid])
			continue
		if raw is String:
			_sfx[sid] = {"id": raw as String, "pitch": 1.0, "db": 0.0}
		elif raw is Dictionary:
			var sd: Dictionary = (raw as Dictionary).duplicate(true)
			if not sd.has("id"):
				if sd.get("variants") is Array and not (sd["variants"] as Array).is_empty():
					sd["id"] = str((sd["variants"] as Array)[0])
				elif sd.has("cue"):
					sd["id"] = str(sd["cue"])
			_sfx[sid] = sd
		else:
			_record_error("%s: sfx '%s' must be String or Dictionary" % [source, sid])


func _reg_named_collection(v: Variant, target: Dictionary, label: String, source: String) -> void:
	if v is Dictionary:
		for k_v: Variant in (v as Dictionary).keys():
			var cid: String = str(k_v).strip_edges()
			var item: Variant = (v as Dictionary)[k_v]
			if cid.is_empty() or not (item is Dictionary):
				_record_error("%s: invalid %s '%s'" % [source, label, cid])
				continue
			if target.has(cid):
				_record_error("%s: %s collision '%s'" % [source, label, cid])
				continue
			var copy_d: Dictionary = (item as Dictionary).duplicate(true)
			if not copy_d.has("id"):
				copy_d["id"] = cid
			target[cid] = copy_d
	elif v is Array:
		for raw: Variant in (v as Array):
			if not (raw is Dictionary):
				_record_error("%s: %s item must be Dictionary" % [source, label])
				continue
			var cid: String = str((raw as Dictionary).get("id", "")).strip_edges()
			if cid.is_empty():
				_record_error("%s: %s item missing 'id'" % [source, label])
				continue
			if target.has(cid):
				_record_error("%s: %s collision '%s'" % [source, label, cid])
				continue
			target[cid] = (raw as Dictionary).duplicate(true)
	else:
		_record_error("%s: '%ss' must be Array or Dictionary" % [source, label])


func _reg_state_vars(v: Variant, source: String) -> void:
	if not (v is Dictionary):
		_record_error("%s: 'state_vars' must be Dictionary" % source)
		return
	for k_v: Variant in (v as Dictionary).keys():
		var vname: String = str(k_v).strip_edges()
		var raw: Variant = (v as Dictionary)[k_v]
		if vname.is_empty() or not (raw is Dictionary):
			_record_error("%s: state_var '%s' must be Dictionary" % [source, vname])
			continue
		if _state_vars.has(vname):
			_record_error("%s: state_var collision '%s'" % [source, vname])
			continue
		_state_vars[vname] = (raw as Dictionary).duplicate(true)


func _append_island_dungeon(isl: int, did: String) -> void:
	var arr: Array = _dungeons_by_island.get(isl, []) as Array
	if not arr.has(did):
		arr.append(did)
	_dungeons_by_island[isl] = arr


func _ensure_island_region(isl: int, rid: String) -> void:
	var arr: Array = _regions_by_island.get(isl, []) as Array
	if not arr.has(rid):
		arr.append(rid)
		arr.sort()
	_regions_by_island[isl] = arr


func _record_error(msg: String) -> void:
	_errors.append(msg)
	if not quiet_errors:
		push_error("LxPackRegistry: " + msg)


static func _sort_room_names(a: String, b: String) -> bool:
	var ai: int = a.rfind("_r")
	var bi: int = b.rfind("_r")
	if ai >= 0 and bi >= 0 and a.left(ai) == b.left(bi):
		return int(a.substr(ai + 2)) < int(b.substr(bi + 2))
	return a < b


# ---- Frozen Public API (CONTRACTS.md) ----

func interactable_script(kind: String) -> String: return str(_interactables.get(kind.strip_edges().to_lower(), ""))

func enemy_script(kind: String) -> String:
	var entry: Variant = _enemies.get(canonical_enemy_kind(kind), null)
	return str((entry as Dictionary).get("script", "")) if entry is Dictionary else ""

func enemy_data(kind: String) -> Dictionary:
	var entry: Variant = _enemies.get(canonical_enemy_kind(kind), null)
	return ((entry as Dictionary)["data"] as Dictionary).duplicate(true) if (entry is Dictionary and (entry as Dictionary).get("data") is Dictionary) else {}

func canonical_enemy_kind(raw_kind: String) -> String:
	var k: String = raw_kind.strip_edges().to_lower()
	return str(_enemy_aliases.get(k, k))

func enemy_kinds() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in _enemies.keys(): out.append(str(k))
	out.sort(); return out

func all_interactable_kinds() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in _interactables.keys(): out.append(str(k))
	out.sort(); return out

func boss_meta(id: String) -> Dictionary:
	var key: String = id.strip_edges().to_lower()
	if _boss_aliases.has(key): key = str(_boss_aliases[key])
	var entry: Variant = _bosses.get(key, null)
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}

func all_boss_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in _bosses.keys(): out.append(str(k))
	out.sort(); return out

func is_boss_music_cue(cue: String) -> bool:
	if cue.contains("_boss_"): return true
	for meta_v: Variant in _bosses.values():
		if meta_v is Dictionary:
			var m: Dictionary = meta_v as Dictionary
			if str(m.get("music", "")) == cue or str(m.get("music_p2", "")) == cue: return true
	return false

func is_boss_phase_pair(prev_cue: String, next_cue: String) -> bool:
	if prev_cue.is_empty() or next_cue.is_empty() or prev_cue == next_cue: return false
	for meta_v: Variant in _bosses.values():
		if meta_v is Dictionary:
			var m: Dictionary = meta_v as Dictionary
			if str(m.get("music", "")) == prev_cue and str(m.get("music_p2", "")) == next_cue: return true
	return false

func string(id: String) -> String: return str(_strings.get(id, ""))
func all_strings() -> Dictionary: return _strings.duplicate()

func dungeon(id: String) -> Dictionary:
	var entry: Variant = _dungeons.get(id, null)
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}

func dungeons_for_island(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for did: Variant in (_dungeons_by_island.get(n, []) as Array):
		var d: Dictionary = dungeon(str(did))
		if not d.is_empty(): out.append(d)
	return out

func all_dungeons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: Variant in _dungeons.keys(): out.append((_dungeons[k] as Dictionary).duplicate(true))
	return out

func dungeon_of(island: int, region: String) -> String: return str(_region_to_dungeon.get("%d:%s" % [island, region], ""))

func region_meta(island: int, region: String) -> Dictionary:
	var entry: Variant = _region_meta.get("%d:%s" % [island, region], null)
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}

func is_debug_only_region(island: int, region: String) -> bool:
	if region.begins_with("_demo"): return true
	if bool(region_meta(island, region).get("debug_only", false)): return true
	var did: String = dungeon_of(island, region)
	return not did.is_empty() and bool(dungeon(did).get("debug_only", false))

func region_ids(island: int) -> PackedStringArray:
	var out := PackedStringArray()
	for r: Variant in (_regions_by_island.get(island, []) as Array): out.append(str(r))
	return out

func sfx_cue(id: String) -> String:
	var entry: Variant = _sfx.get(id, null)
	return str((entry as Dictionary).get("id", (entry as Dictionary).get("cue", ""))) if entry is Dictionary else ""

func sfx_entry(id: String) -> Dictionary:
	var entry: Variant = _sfx.get(id, null)
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}

func quests() -> Dictionary: return _quests.duplicate(true)
func panes() -> Dictionary: return _panes.duplicate(true)
func moths() -> Dictionary: return _moths.duplicate(true)
func state_vars() -> Dictionary: return _state_vars.duplicate(true)

func island_count() -> int:
	if Lx.data_islands.is_empty(): Lx.load_all_data()
	var arr: Variant = Lx.data_islands.get("islands", [])
	return maxi(8, (arr as Array).size()) if arr is Array else 8

func pack_files() -> PackedStringArray: return _pack_files.duplicate()
func errors() -> PackedStringArray: return _errors.duplicate()
