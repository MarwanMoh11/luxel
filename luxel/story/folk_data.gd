class_name LxFolkData
extends RefCounted
## Shared pack loader & string lookup for E0-5 (panes, folk, quests, moths, hub).
## Uses Lx.packs automatically once E0-1 registers it, and falls back directly to
## res://luxel/data/packs/folk.json and res://luxel/islands/0/packs/hub.json.

const FOLK_PACK_PATH: String = "res://luxel/data/packs/folk.json"
const FOLK_CATALOG_PATH: String = "res://luxel/world/folk/folk_catalog.json"
const HUB_PACK_PATH: String = "res://luxel/islands/0/packs/hub.json"

static var _loaded: bool = false
static var _strings: Dictionary = {}
static var _panes: Dictionary = {}
static var _quests: Dictionary = {}
static var _moths: Array[Dictionary] = []
static var _moths_by_id: Dictionary = {}
static var _folk: Dictionary = {}
static var _moth_tiers: Array[Dictionary] = []
static var _bestiary_weak: Dictionary = {}
static var _toys_catalog: Array[Dictionary] = []


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_strings.clear()
	_panes.clear()
	_quests.clear()
	_moths.clear()
	_moths_by_id.clear()
	_folk.clear()
	_moth_tiers.clear()
	_bestiary_weak.clear()
	_toys_catalog.clear()
	_merge_pack(FOLK_PACK_PATH)
	_merge_pack(FOLK_CATALOG_PATH)
	_merge_pack(HUB_PACK_PATH)
	_scan_extra_packs("res://luxel/data/packs")
	for isl: int in range(0, 9):
		_scan_extra_packs("res://luxel/islands/%d/packs" % isl)


static func reload() -> void:
	_loaded = false
	ensure_loaded()


static func _scan_extra_packs(dir_path: String) -> void:
	var da: DirAccess = DirAccess.open(dir_path)
	if da == null:
		return
	for fname: String in da.get_files():
		if not fname.ends_with(".json"):
			continue
		var full: String = dir_path.path_join(fname)
		if full == FOLK_PACK_PATH or full == HUB_PACK_PATH:
			continue
		_merge_pack(full)


static func _merge_pack(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed as Dictionary
	var strs_v: Variant = d.get("strings", {})
	if strs_v is Dictionary:
		for k: Variant in (strs_v as Dictionary).keys():
			_strings[str(k)] = str((strs_v as Dictionary)[k])
	var panes_v: Variant = d.get("panes", {})
	if panes_v is Dictionary:
		for k: Variant in (panes_v as Dictionary).keys():
			if (panes_v as Dictionary)[k] is Dictionary:
				_panes[str(k)] = ((panes_v as Dictionary)[k] as Dictionary).duplicate(true)
	var quests_v: Variant = d.get("quests", [])
	if quests_v is Array:
		for qv: Variant in (quests_v as Array):
			if qv is Dictionary:
				var qd: Dictionary = (qv as Dictionary).duplicate(true)
				var qid: String = str(qd.get("id", ""))
				if not qid.is_empty():
					_quests[qid] = qd
	elif quests_v is Dictionary:
		for k: Variant in (quests_v as Dictionary).keys():
			if (quests_v as Dictionary)[k] is Dictionary:
				_quests[str(k)] = ((quests_v as Dictionary)[k] as Dictionary).duplicate(true)
	var moths_v: Variant = d.get("moths", [])
	if moths_v is Array:
		for mv: Variant in (moths_v as Array):
			if mv is Dictionary:
				var md: Dictionary = (mv as Dictionary).duplicate(true)
				var mid: String = str(md.get("id", ""))
				if not mid.is_empty() and not _moths_by_id.has(mid):
					_moths_by_id[mid] = md
					_moths.append(md)
	var folk_v: Variant = d.get("folk", {})
	if folk_v is Dictionary:
		for k: Variant in (folk_v as Dictionary).keys():
			if (folk_v as Dictionary)[k] is Dictionary:
				_folk[str(k)] = ((folk_v as Dictionary)[k] as Dictionary).duplicate(true)
	var tiers_v: Variant = d.get("moth_tiers", [])
	if tiers_v is Array and _moth_tiers.is_empty():
		for tv: Variant in (tiers_v as Array):
			if tv is Dictionary:
				_moth_tiers.append((tv as Dictionary).duplicate(true))
	var bw_v: Variant = d.get("bestiary_weakness", {})
	if bw_v is Dictionary:
		for k: Variant in (bw_v as Dictionary).keys():
			_bestiary_weak[str(k)] = str((bw_v as Dictionary)[k])
	var tc_v: Variant = d.get("toys_catalog", [])
	if tc_v is Array and _toys_catalog.is_empty():
		for tcv: Variant in (tc_v as Array):
			if tcv is Dictionary:
				_toys_catalog.append((tcv as Dictionary).duplicate(true))


static func tr_id(id: String) -> String:
	ensure_loaded()
	if LxStrings.has_id(id):
		return LxStrings.text(id)
	var packs_obj: Variant = (Lx as Object).get("packs")
	if packs_obj is Object and (packs_obj as Object).has_method("string"):
		var ps: String = str((packs_obj as Object).call("string", id))
		if not ps.is_empty():
			return ps
	if _strings.has(id):
		return str(_strings[id])
	return LxStrings.text(id)


static func fmt_id(id: String, args: Array) -> String:
	var tmpl: String = tr_id(id)
	return LxStrings._apply_fmt(tmpl, args)


static func has_str(id: String) -> bool:
	ensure_loaded()
	if LxStrings.has_id(id):
		return true
	return _strings.has(id)


static func all_strings() -> Dictionary:
	ensure_loaded()
	return _strings


static func panes() -> Dictionary:
	ensure_loaded()
	return _panes


static func quests() -> Dictionary:
	ensure_loaded()
	return _quests


static func moths() -> Array[Dictionary]:
	ensure_loaded()
	return _moths


static func moth_tiers() -> Array[Dictionary]:
	ensure_loaded()
	return _moth_tiers


static func folk_map() -> Dictionary:
	ensure_loaded()
	return _folk


static func folk_spec(folk_id: String) -> Dictionary:
	ensure_loaded()
	return (_folk.get(folk_id, {}) as Dictionary)


static func weakness_icon(enemy_kind: String) -> String:
	ensure_loaded()
	return str(_bestiary_weak.get(enemy_kind, "weak_bolt"))


static func toys_catalog() -> Array[Dictionary]:
	ensure_loaded()
	return _toys_catalog
