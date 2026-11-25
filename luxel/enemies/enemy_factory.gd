class_name LxEnemyFactory
extends RefCounted
## Factory instantiating all Luxel enemy kinds & bosses with data-driven per-island economy bands.

const ECONOMY_PATH: String = "res://luxel/data/economy.json"
static var _econ_loaded: bool = false
static var _econ_cache: Dictionary = {}

const KNOWN_KINDS: PackedStringArray = [
	"warden", "snatcher", "owl",
	"barnacle_sentry", "gull_thief", "crab_warden",
	"sporecap", "bramble_knight", "gloam",
	"lily_hopper", "heron_stalker", "mire_snuffer",
	"phantom_owl", "orrery_sentinel", "echo_moth",
	"cinder_golem", "ash_mole", "bellows_imp",
	"moonshade_warden", "moonshade_snatcher", "moonshade_owl", "hollow_wick",
	"bell_warden", "bellkeeper", "tide_captain", "lighthouse_hermit",
	"elder_sporecap", "briar_matron", "great_lily_hopper", "heron_abbess",
	"clockwork_warden", "astronomer", "forge_warden", "kilnmother",
	"spire_warden", "hollow_wick_boss", "night_harbinger", "the_hush",
]

const KIND_SCRIPTS: Dictionary = {
	"warden": "res://luxel/enemies/warden/brain.gd",
	"snatcher": "res://luxel/enemies/snatcher/brain.gd",
	"owl": "res://luxel/enemies/owl/brain.gd",
	"barnacle_sentry": "res://luxel/enemies/barnacle_sentry/brain.gd",
	"gull_thief": "res://luxel/enemies/gull_thief/brain.gd",
	"crab_warden": "res://luxel/enemies/crab_warden/brain.gd",
	"sporecap": "res://luxel/enemies/sporecap/brain.gd",
	"bramble_knight": "res://luxel/enemies/bramble_knight/brain.gd",
	"gloam": "res://luxel/enemies/gloam/brain.gd",
	"lily_hopper": "res://luxel/enemies/lily_hopper/brain.gd",
	"heron_stalker": "res://luxel/enemies/heron_stalker/brain.gd",
	"mire_snuffer": "res://luxel/enemies/mire_snuffer/brain.gd",
	"phantom_owl": "res://luxel/enemies/phantom_owl/brain.gd",
	"orrery_sentinel": "res://luxel/enemies/orrery_sentinel/brain.gd",
	"echo_moth": "res://luxel/enemies/echo_moth/brain.gd",
	"cinder_golem": "res://luxel/enemies/cinder_golem/brain.gd",
	"ash_mole": "res://luxel/enemies/ash_mole/brain.gd",
	"bellows_imp": "res://luxel/enemies/bellows_imp/brain.gd",
	"moonshade_warden": "res://luxel/enemies/moonshade/brain.gd",
	"moonshade_snatcher": "res://luxel/enemies/moonshade/brain.gd",
	"moonshade_owl": "res://luxel/enemies/moonshade/brain.gd",
	"hollow_wick": "res://luxel/enemies/hollow_wick/brain.gd",
	"bell_warden": "res://luxel/bosses/bell_warden/brain.gd",
	"bellkeeper": "res://luxel/bosses/bellkeeper/brain.gd",
	"tide_captain": "res://luxel/bosses/tide_captain/brain.gd",
	"lighthouse_hermit": "res://luxel/bosses/lighthouse_hermit/brain.gd",
	"elder_sporecap": "res://luxel/bosses/elder_sporecap/brain.gd",
	"briar_matron": "res://luxel/bosses/briar_matron/brain.gd",
	"great_lily_hopper": "res://luxel/bosses/great_lily_hopper/brain.gd",
	"heron_abbess": "res://luxel/bosses/heron_abbess/brain.gd",
	"clockwork_warden": "res://luxel/bosses/clockwork_warden/brain.gd",
	"astronomer": "res://luxel/bosses/astronomer/brain.gd",
	"forge_warden": "res://luxel/bosses/forge_warden/brain.gd",
	"kilnmother": "res://luxel/bosses/kilnmother/brain.gd",
	"spire_warden": "res://luxel/bosses/spire_warden/brain.gd",
	"hollow_wick_boss": "res://luxel/bosses/hollow_wick_boss/brain.gd",
	"night_harbinger": "res://luxel/bosses/night_harbinger/brain.gd",
	"the_hush": "res://luxel/bosses/the_hush/brain.gd",
}


static func _economy_cfg() -> Dictionary:
	if not _econ_loaded:
		_econ_loaded = true
		if FileAccess.file_exists(ECONOMY_PATH):
			_econ_cache = Lx.load_json(ECONOMY_PATH)
	return _econ_cache


static func _resolve_island(key: String, spec: Dictionary, world_ctx: Node) -> int:
	if spec.has("island_id") and int(spec["island_id"]) > 0:
		return clampi(int(spec["island_id"]), 1, 8)
	if world_ctx != null:
		var cid: Variant = world_ctx.get("current_island_id")
		if cid is int and int(cid) > 0:
			return clampi(int(cid), 1, 8)
		var wid: Variant = world_ctx.get("island_id")
		if wid is int and int(wid) > 0:
			return clampi(int(wid), 1, 8)
	var hi: Dictionary = _economy_cfg().get("home_islands", {}) as Dictionary
	if hi.has(key):
		return clampi(int(hi[key]), 1, 8)
	if Lx.packs != null:
		var bm: Dictionary = Lx.packs.boss_meta(key)
		if bm.has("island") and int(bm["island"]) > 0:
			return clampi(int(bm["island"]), 1, 8)
		var pd: Dictionary = Lx.packs.enemy_data(key)
		if pd.has("island") and int(pd["island"]) > 0:
			return clampi(int(pd["island"]), 1, 8)
	if Lx.state != null and Lx.state.island_id > 0:
		return clampi(Lx.state.island_id, 1, 8)
	return 1


static func band_multipliers(key: String, isl: int, is_boss: bool) -> Vector2:
	## Returns Vector2(hp_mult, shard_mult) from luxel/data/economy.json.
	var cfg: Dictionary = _economy_cfg()
	if cfg.is_empty():
		return Vector2.ONE
	var bands: Dictionary = cfg.get("boss_bands" if is_boss else "enemy_bands", {}) as Dictionary
	var b: Dictionary = bands.get(str(isl), bands.get("default", {})) as Dictionary
	var hp_m: float = float(b.get("hp_mult", 1.0))
	var sh_m: float = float(b.get("shard_mult", 1.0))
	var exempt_v: Variant = b.get("exempt_hp_kinds", [])
	var hp_exempt: bool = exempt_v is Array and (exempt_v as Array).has(key)
	if hp_exempt:
		hp_m = 1.0
	var ovs: Dictionary = cfg.get("kind_overrides", {}) as Dictionary
	if ovs.has(key) and ovs[key] is Dictionary:
		var ov: Dictionary = ovs[key] as Dictionary
		if not hp_exempt:
			hp_m *= float(ov.get("hp_mult", 1.0))
		sh_m *= float(ov.get("shard_mult", 1.0))
	if Lx.state != null and Lx.state.is_hard_mode():
		var hm: Dictionary = cfg.get("hard_mode", {}) as Dictionary
		hp_m *= float(hm.get("boss_hp_mult" if is_boss else "enemy_hp_mult", 1.0))
	return Vector2(maxf(0.1, hp_m), maxf(0.1, sh_m))


static func _canonical_kind(raw_kind: String) -> String:
	var key: String = raw_kind.strip_edges().to_lower()
	match key:
		"parasol_toad", "toad_warden":
			return "warden"
		"magpie", "magpie_snatcher":
			return "snatcher"
		"hush_owl", "owl_sentinel":
			return "owl"
		"moonshade":
			return "moonshade_warden"
		"belfry_warden":
			return "bell_warden"
		"grand_bellkeeper":
			return "bellkeeper"
		_:
			if Lx.packs != null:
				return Lx.packs.canonical_enemy_kind(key)
			return key


static func _instantiate_from_path(path: String) -> LxEnemyBrain:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	if res is GDScript:
		var inst: Variant = (res as GDScript).new()
		if inst is LxEnemyBrain:
			return inst as LxEnemyBrain
	return null


static func _world_has_live_boss(world_ctx: Node) -> bool:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_enemies"):
		return false
	var arr: Variant = world_ctx.call("get_enemies")
	if not (arr is Array):
		return false
	for e_v: Variant in (arr as Array):
		if e_v is LxEnemyBrain and is_instance_valid(e_v):
			var eb: LxEnemyBrain = e_v as LxEnemyBrain
			if (eb.is_boss or eb is LxBossBase) and eb.is_alive():
				return true
	return false


static func create(
	kind: String,
	spec: Dictionary,
	director: LxAttackDirector,
	world_ctx: Node
) -> LxEnemyBrain:
	var key: String = _canonical_kind(kind)
	var brain: LxEnemyBrain = null
	var pack_script: String = ""
	if KIND_SCRIPTS.has(key):
		brain = _instantiate_from_path(str(KIND_SCRIPTS[key]))
	else:
		var packs: LxPackRegistry = Lx.packs if Lx.packs != null else Lx.ensure_packs()
		key = packs.canonical_enemy_kind(key)
		pack_script = packs.enemy_script(key)
		if not pack_script.is_empty():
			brain = _instantiate_from_path(pack_script)
	if brain == null:
		push_warning("LxEnemyFactory: unknown or missing kind '%s', defaulting to warden" % kind)
		brain = LxWardenBrain.new()

	var merged: Dictionary = spec.duplicate()
	if key.begins_with("moonshade_") and (not merged.has("variant") or str(merged["variant"]).is_empty()):
		merged["variant"] = key
	if not merged.has("kind") or str(merged["kind"]).is_empty():
		merged["kind"] = key if (KIND_SCRIPTS.has(key) or not pack_script.is_empty()) else brain.kind
	var bmeta: Dictionary = Lx.packs.boss_meta(key) if Lx.packs != null else {}
	if not bmeta.is_empty() and (not merged.has("boss_id") or str(merged["boss_id"]).is_empty()):
		merged["boss_id"] = str(bmeta.get("id", key))

	var isl: int = _resolve_island(key, merged, world_ctx)
	merged["island_id"] = isl
	var is_b: bool = brain.is_boss or (not bmeta.is_empty()) or (brain is LxBossBase)
	var is_boss_add: bool = (not is_b) and _world_has_live_boss(world_ctx)
	var mults: Vector2 = Vector2.ONE if is_boss_add else band_multipliers(key, isl, is_b)
	if not is_equal_approx(mults.x, 1.0):
		merged["hp_scale"] = float(merged.get("hp_scale", 1.0)) * mults.x

	brain.setup(merged, director, world_ctx)

	if is_boss_add:
		brain.shard_drop = 0
	elif brain.shard_drop > 0 and not is_equal_approx(mults.y, 1.0):
		brain.shard_drop = maxi(1, roundi(float(brain.shard_drop) * mults.y))
	if Lx.state != null and Lx.state.is_hard_mode():
		var hm: Dictionary = _economy_cfg().get("hard_mode", {}) as Dictionary
		brain.attack_damage = snappedf(brain.attack_damage * float(hm.get("damage_mult", 1.0)), 0.5)
	# Prevent double heart grant when pack boss metadata already awards heart via LxBossHud
	if brain is LxBossBase and not bmeta.is_empty():
		var ph: String = str(bmeta.get("heart", "")).strip_edges().to_lower()
		if not ph.is_empty() and ph != "none":
			(brain as LxBossBase).reward_heart = "none"
	return brain


static func known_kinds() -> PackedStringArray:
	var out: PackedStringArray = KNOWN_KINDS.duplicate()
	if Lx.packs != null:
		for pk: String in Lx.packs.enemy_kinds():
			if not out.has(pk):
				out.append(pk)
	return out


static func _make_data(
	p_kind: String, p_hp: float, p_rad: float, p_spd: float,
	p_leash: float, p_notice: float, p_tell: float, p_rec: float,
	p_shield: float = 0.0, p_shards: int = 3, p_dmg: float = 1.0, p_boss: bool = false
) -> LxEnemyData:
	var d := LxEnemyData.new()
	d.kind = p_kind; d.max_hp = p_hp; d.body_radius = p_rad; d.routine_speed = p_spd
	d.leash_radius = p_leash; d.notice_radius = p_notice; d.tell_time = p_tell
	d.recover_time = p_rec; d.shield_hp = p_shield; d.shard_drop = p_shards
	d.attack_damage = p_dmg; d.is_boss = p_boss
	return d


static func _apply_band_to_data(d: LxEnemyData, key: String) -> LxEnemyData:
	var isl: int = _resolve_island(key, {}, null)
	d.home_island = isl
	var mults: Vector2 = band_multipliers(key, isl, d.is_boss)
	d.max_hp = snappedf(d.max_hp * mults.x, 0.05)
	if d.shard_drop > 0:
		d.shard_drop = maxi(1, roundi(float(d.shard_drop) * mults.y))
	return d


static func default_data(kind: String) -> LxEnemyData:
	var key: String = _canonical_kind(kind)
	var d: LxEnemyData = _base_default_data(key)
	return _apply_band_to_data(d, key)


static func _base_default_data(key: String) -> LxEnemyData:
	match key:
		"snatcher": return _make_data("snatcher", 1.25, 3.5, 44.0, 160.0, 172.0, 0.50, 0.72, 0.0, 2)
		"owl": return _make_data("owl", 2.25, 7.0, 76.0, 180.0, 122.0, 0.62, 1.30, 0.0, 3)
		"barnacle_sentry": return _make_data("barnacle_sentry", 2.0, 5.5, 24.0, 132.0, 130.0, 0.60, 1.00, 1.5, 3)
		"gull_thief": return _make_data("gull_thief", 1.5, 4.0, 50.0, 168.0, 170.0, 0.50, 0.80, 0.0, 3)
		"crab_warden": return _make_data("crab_warden", 4.0, 5.5, 34.0, 152.0, 120.0, 0.48, 1.15, 2.0, 4)
		"sporecap": return _make_data("sporecap", 2.25, 5.5, 28.0, 140.0, 118.0, 0.55, 1.10, 0.0, 3)
		"bramble_knight": return _make_data("bramble_knight", 5.0, 6.5, 32.0, 150.0, 122.0, 0.52, 1.25, 2.5, 5)
		"gloam": return _make_data("gloam", 2.0, 4.5, 48.0, 156.0, 124.0, 0.48, 0.95, 0.0, 3)
		"lily_hopper": return _make_data("lily_hopper", 2.5, 5.5, 46.0, 158.0, 124.0, 0.50, 1.05, 0.0, 3)
		"heron_stalker": return _make_data("heron_stalker", 3.0, 5.5, 42.0, 162.0, 136.0, 0.58, 1.25, 0.0, 4)
		"mire_snuffer": return _make_data("mire_snuffer", 1.75, 4.0, 46.0, 160.0, 168.0, 0.50, 0.85, 0.0, 3)
		"phantom_owl": return _make_data("phantom_owl", 2.5, 7.0, 76.0, 180.0, 126.0, 0.62, 1.30, 0.0, 4)
		"orrery_sentinel": return _make_data("orrery_sentinel", 3.0, 6.5, 34.0, 150.0, 134.0, 0.55, 1.15, 0.0, 4)
		"echo_moth": return _make_data("echo_moth", 2.0, 4.5, 58.0, 158.0, 128.0, 0.45, 1.00, 0.0, 3)
		"cinder_golem": return _make_data("cinder_golem", 6.0, 8.0, 24.0, 128.0, 118.0, 0.65, 1.55, 0.0, 6, 1.5)
		"ash_mole": return _make_data("ash_mole", 1.75, 4.5, 42.0, 156.0, 160.0, 0.50, 0.85, 0.0, 3)
		"bellows_imp": return _make_data("bellows_imp", 1.75, 4.5, 38.0, 148.0, 128.0, 0.50, 1.10, 0.0, 3)
		"moonshade_warden": return _make_data("moonshade_warden", 4.0, 5.5, 38.0, 158.0, 128.0, 0.48, 1.05, 1.75, 5)
		"moonshade_snatcher": return _make_data("moonshade_snatcher", 4.0, 4.5, 48.0, 158.0, 128.0, 0.50, 0.90, 0.0, 5)
		"moonshade_owl": return _make_data("moonshade_owl", 4.0, 6.5, 74.0, 158.0, 128.0, 0.62, 1.15, 0.0, 5)
		"hollow_wick": return _make_data("hollow_wick", 6.5, 4.5, 54.0, 164.0, 136.0, 0.45, 1.05, 0.0, 8)
		"bell_warden":
			var bw: LxEnemyData = _make_data("bell_warden", 7.5, 6.5, 40.0, 175.0, 140.0, 0.48, 1.15, 2.4, 12, 1.0, true)
			bw.shield_gone_time = 4.5; return bw
		"bellkeeper":
			var bk: LxEnemyData = _make_data("bellkeeper", 10.0, 7.0, 42.0, 185.0, 150.0, 0.48, 1.15, 2.8, 25, 1.0, true)
			bk.shield_gone_time = 4.8; return bk
		"tide_captain":
			var tc: LxEnemyData = _make_data("tide_captain", 8.0, 7.0, 38.0, 175.0, 140.0, 0.48, 1.15, 2.6, 12, 1.0, true)
			tc.shield_gone_time = 4.5; return tc
		"lighthouse_hermit":
			var lh: LxEnemyData = _make_data("lighthouse_hermit", 12.0, 8.5, 34.0, 185.0, 152.0, 0.50, 1.20, 3.0, 28, 1.0, true)
			lh.shield_gone_time = 4.8; return lh
		"elder_sporecap": return _make_data("elder_sporecap", 9.0, 7.5, 30.0, 165.0, 136.0, 0.56, 1.25, 0.0, 14, 1.0, true)
		"briar_matron":
			var bm: LxEnemyData = _make_data("briar_matron", 12.5, 8.5, 34.0, 185.0, 152.0, 0.50, 1.20, 3.5, 30, 1.0, true)
			bm.shield_gone_time = 5.2; return bm
		"great_lily_hopper": return _make_data("great_lily_hopper", 10.5, 7.5, 44.0, 172.0, 140.0, 0.52, 1.20, 0.0, 15, 1.0, true)
		"heron_abbess": return _make_data("heron_abbess", 17.0, 7.5, 42.0, 185.0, 152.0, 0.56, 1.30, 0.0, 32, 1.0, true)
		"clockwork_warden": return _make_data("clockwork_warden", 11.5, 8.0, 36.0, 168.0, 144.0, 0.56, 1.15, 0.0, 16, 1.0, true)
		"astronomer": return _make_data("astronomer", 18.0, 8.5, 76.0, 185.0, 152.0, 0.62, 1.35, 0.0, 34, 1.0, true)
		"forge_warden": return _make_data("forge_warden", 12.5, 8.5, 26.0, 150.0, 132.0, 0.64, 1.45, 0.0, 18, 1.5, true)
		"kilnmother": return _make_data("kilnmother", 20.0, 9.5, 26.0, 160.0, 140.0, 0.66, 1.45, 0.0, 36, 1.5, true)
		"spire_warden":
			var sw: LxEnemyData = _make_data("spire_warden", 13.0, 6.5, 40.0, 175.0, 142.0, 0.48, 1.12, 2.2, 14, 1.0, true)
			sw.shield_gone_time = 4.6; return sw
		"hollow_wick_boss": return _make_data("hollow_wick_boss", 22.0, 5.5, 56.0, 185.0, 152.0, 0.45, 1.05, 0.0, 40, 1.0, true)
		"night_harbinger":
			var nh: LxEnemyData = _make_data("night_harbinger", 14.5, 7.0, 42.0, 175.0, 144.0, 0.48, 1.10, 2.4, 22, 1.0, true)
			nh.shield_gone_time = 4.6; return nh
		"the_hush": return _make_data("the_hush", 28.0, 10.0, 42.0, 190.0, 160.0, 0.56, 1.05, 0.0, 60, 1.0, true)
		_:
			if Lx.packs != null:
				var pd: Dictionary = Lx.packs.enemy_data(key)
				var bm2: Dictionary = Lx.packs.boss_meta(key)
				if not pd.is_empty() or not bm2.is_empty():
					var is_b: bool = bool(pd.get("is_boss", not bm2.is_empty()))
					var ed: LxEnemyData = _make_data(
						key,
						float(pd.get("max_hp", pd.get("hp", 12.0 if is_b else 3.0))),
						float(pd.get("body_radius", pd.get("radius", 7.0 if is_b else 5.0))),
						float(pd.get("routine_speed", pd.get("speed", 40.0))),
						float(pd.get("leash_radius", 180.0 if is_b else 156.0)),
						float(pd.get("notice_radius", 148.0 if is_b else 124.0)),
						float(pd.get("tell_time", 0.52)),
						float(pd.get("recover_time", 1.15)),
						float(pd.get("shield_hp", 0.0)),
						int(pd.get("shard_drop", pd.get("shards", 18 if is_b else 3))),
						float(pd.get("attack_damage", pd.get("damage", 1.0))),
						is_b
					)
					if pd.has("shield_gone_time"):
						ed.shield_gone_time = float(pd["shield_gone_time"])
					return ed
			var wd: LxEnemyData = _make_data("warden", 4.0, 5.0, 36.0, 158.0, 120.0, 0.48, 1.15, 1.75, 3)
			wd.shield_gone_time = 4.8; return wd
