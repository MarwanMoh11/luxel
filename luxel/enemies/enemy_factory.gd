class_name LxEnemyFactory
extends RefCounted
## Factory instantiating all 20 Luxel 1.0 enemy kinds + M0 bosses by kind ID.

const KNOWN_KINDS: PackedStringArray = [
	"warden",
	"snatcher",
	"owl",
	"barnacle_sentry",
	"gull_thief",
	"crab_warden",
	"sporecap",
	"bramble_knight",
	"gloam",
	"lily_hopper",
	"heron_stalker",
	"mire_snuffer",
	"phantom_owl",
	"orrery_sentinel",
	"echo_moth",
	"cinder_golem",
	"ash_mole",
	"bellows_imp",
	"moonshade_warden",
	"moonshade_snatcher",
	"moonshade_owl",
	"hollow_wick",
	"bell_warden",
	"bellkeeper",
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
}


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


static func create(
	kind: String,
	spec: Dictionary,
	director: LxAttackDirector,
	world_ctx: Node
) -> LxEnemyBrain:
	var key: String = _canonical_kind(kind)
	var brain: LxEnemyBrain = null
	if KIND_SCRIPTS.has(key):
		brain = _instantiate_from_path(str(KIND_SCRIPTS[key]))
	if brain == null:
		push_warning("LxEnemyFactory: unknown or missing kind '%s', defaulting to warden" % kind)
		brain = LxWardenBrain.new()

	var merged: Dictionary = spec.duplicate()
	if key.begins_with("moonshade_") and (not merged.has("variant") or str(merged["variant"]).is_empty()):
		merged["variant"] = key
	if not merged.has("kind") or str(merged["kind"]).is_empty():
		merged["kind"] = key if KIND_SCRIPTS.has(key) else brain.kind
	brain.setup(merged, director, world_ctx)
	return brain


static func known_kinds() -> PackedStringArray:
	return KNOWN_KINDS


static func _make_data(
	p_kind: String,
	p_hp: float,
	p_rad: float,
	p_spd: float,
	p_leash: float,
	p_notice: float,
	p_tell: float,
	p_rec: float,
	p_shield: float = 0.0,
	p_shards: int = 3,
	p_dmg: float = 1.0,
	p_boss: bool = false
) -> LxEnemyData:
	var d := LxEnemyData.new()
	d.kind = p_kind
	d.max_hp = p_hp
	d.body_radius = p_rad
	d.routine_speed = p_spd
	d.leash_radius = p_leash
	d.notice_radius = p_notice
	d.tell_time = p_tell
	d.recover_time = p_rec
	d.shield_hp = p_shield
	d.shard_drop = p_shards
	d.attack_damage = p_dmg
	d.is_boss = p_boss
	return d


static func default_data(kind: String) -> LxEnemyData:
	var key: String = _canonical_kind(kind)
	match key:
		"snatcher":
			return _make_data("snatcher", 1.25, 3.5, 44.0, 160.0, 172.0, 0.50, 0.72, 0.0, 2)
		"owl":
			return _make_data("owl", 2.25, 7.0, 76.0, 180.0, 122.0, 0.62, 1.30, 0.0, 3)
		"barnacle_sentry":
			return _make_data("barnacle_sentry", 2.0, 5.5, 24.0, 132.0, 130.0, 0.60, 1.00, 1.5, 3)
		"gull_thief":
			return _make_data("gull_thief", 1.5, 4.0, 50.0, 168.0, 170.0, 0.50, 0.80, 0.0, 3)
		"crab_warden":
			return _make_data("crab_warden", 4.0, 5.5, 34.0, 152.0, 120.0, 0.48, 1.15, 2.0, 4)
		"sporecap":
			return _make_data("sporecap", 2.25, 5.5, 28.0, 140.0, 118.0, 0.55, 1.10, 0.0, 3)
		"bramble_knight":
			return _make_data("bramble_knight", 5.0, 6.5, 32.0, 150.0, 122.0, 0.52, 1.25, 2.5, 5)
		"gloam":
			return _make_data("gloam", 2.0, 4.5, 48.0, 156.0, 124.0, 0.48, 0.95, 0.0, 3)
		"lily_hopper":
			return _make_data("lily_hopper", 2.5, 5.5, 46.0, 158.0, 124.0, 0.50, 1.05, 0.0, 3)
		"heron_stalker":
			return _make_data("heron_stalker", 3.0, 5.5, 42.0, 162.0, 136.0, 0.58, 1.25, 0.0, 4)
		"mire_snuffer":
			return _make_data("mire_snuffer", 1.75, 4.0, 46.0, 160.0, 168.0, 0.50, 0.85, 0.0, 3)
		"phantom_owl":
			return _make_data("phantom_owl", 2.5, 7.0, 76.0, 180.0, 126.0, 0.62, 1.30, 0.0, 4)
		"orrery_sentinel":
			return _make_data("orrery_sentinel", 3.0, 6.5, 34.0, 150.0, 134.0, 0.55, 1.15, 0.0, 4)
		"echo_moth":
			return _make_data("echo_moth", 2.0, 4.5, 58.0, 158.0, 128.0, 0.45, 1.00, 0.0, 3)
		"cinder_golem":
			return _make_data("cinder_golem", 6.0, 8.0, 24.0, 128.0, 118.0, 0.65, 1.55, 0.0, 6, 1.5)
		"ash_mole":
			return _make_data("ash_mole", 1.75, 4.5, 42.0, 156.0, 160.0, 0.50, 0.85, 0.0, 3)
		"bellows_imp":
			return _make_data("bellows_imp", 1.75, 4.5, 38.0, 148.0, 128.0, 0.50, 1.10, 0.0, 3)
		"moonshade_warden":
			return _make_data("moonshade_warden", 4.0, 5.5, 38.0, 158.0, 128.0, 0.48, 1.05, 1.75, 5)
		"moonshade_snatcher":
			return _make_data("moonshade_snatcher", 4.0, 4.5, 48.0, 158.0, 128.0, 0.50, 0.90, 0.0, 5)
		"moonshade_owl":
			return _make_data("moonshade_owl", 4.0, 6.5, 74.0, 158.0, 128.0, 0.62, 1.15, 0.0, 5)
		"hollow_wick":
			return _make_data("hollow_wick", 6.5, 4.5, 54.0, 164.0, 136.0, 0.45, 1.05, 0.0, 8)
		"bell_warden":
			var bw: LxEnemyData = _make_data("bell_warden", 7.5, 6.5, 40.0, 175.0, 140.0, 0.48, 1.15, 2.4, 12, 1.0, true)
			bw.shield_gone_time = 4.5
			return bw
		"bellkeeper":
			var bk: LxEnemyData = _make_data("bellkeeper", 10.0, 7.0, 42.0, 185.0, 150.0, 0.48, 1.15, 2.8, 25, 1.0, true)
			bk.shield_gone_time = 4.8
			return bk
		_:
			var wd: LxEnemyData = _make_data("warden", 4.0, 5.0, 36.0, 158.0, 120.0, 0.48, 1.15, 1.75, 3)
			wd.shield_gone_time = 4.8
			return wd
