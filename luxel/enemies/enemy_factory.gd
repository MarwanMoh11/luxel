class_name LxEnemyFactory
extends RefCounted
## Factory instantiating Luxel 1.0 enemy & boss brains by kind ID.

const KNOWN_KINDS: PackedStringArray = [
	"warden",
	"snatcher",
	"owl",
	"bell_warden",
	"bellkeeper",
]


static func create(
	kind: String,
	spec: Dictionary,
	director: LxAttackDirector,
	world_ctx: Node
) -> LxEnemyBrain:
	var key: String = kind.strip_edges().to_lower()
	var brain: LxEnemyBrain = null
	match key:
		"warden", "parasol_toad", "toad_warden":
			brain = LxWardenBrain.new()
		"snatcher", "magpie", "magpie_snatcher":
			brain = LxSnatcherBrain.new()
		"owl", "hush_owl", "owl_sentinel":
			brain = LxOwlBrain.new()
		"bell_warden", "belfry_warden":
			brain = LxBellWardenBoss.new()
		"bellkeeper", "grand_bellkeeper":
			brain = LxBellkeeperBoss.new()
		_:
			push_warning("LxEnemyFactory: unknown kind '%s', defaulting to warden" % kind)
			brain = LxWardenBrain.new()

	var merged: Dictionary = spec.duplicate()
	if not merged.has("kind") or str(merged["kind"]).is_empty():
		merged["kind"] = brain.kind
	brain.setup(merged, director, world_ctx)
	return brain


static func known_kinds() -> PackedStringArray:
	return KNOWN_KINDS


static func default_data(kind: String) -> LxEnemyData:
	var key: String = kind.strip_edges().to_lower()
	var d := LxEnemyData.new()
	match key:
		"snatcher", "magpie", "magpie_snatcher":
			d.kind = "snatcher"
			d.max_hp = 1.25
			d.body_radius = 3.5
			d.routine_speed = 44.0
			d.leash_radius = 160.0
			d.notice_radius = 172.0
			d.tell_time = 0.50
			d.recover_time = 0.72
			d.shield_hp = 0.0
			d.shard_drop = 2
		"owl", "hush_owl", "owl_sentinel":
			d.kind = "owl"
			d.max_hp = 2.25
			d.body_radius = 7.0
			d.routine_speed = 76.0
			d.leash_radius = 180.0
			d.notice_radius = 122.0
			d.tell_time = 0.62
			d.recover_time = 1.30
			d.shield_hp = 0.0
			d.shard_drop = 3
		"bell_warden", "belfry_warden":
			d.kind = "bell_warden"
			d.max_hp = 7.5
			d.body_radius = 6.5
			d.routine_speed = 40.0
			d.leash_radius = 175.0
			d.notice_radius = 140.0
			d.tell_time = 0.48
			d.recover_time = 1.15
			d.shield_hp = 2.4
			d.shield_gone_time = 4.5
			d.shard_drop = 12
			d.is_boss = true
		"bellkeeper", "grand_bellkeeper":
			d.kind = "bellkeeper"
			d.max_hp = 10.0
			d.body_radius = 7.0
			d.routine_speed = 42.0
			d.leash_radius = 185.0
			d.notice_radius = 150.0
			d.tell_time = 0.48
			d.recover_time = 1.15
			d.shield_hp = 2.8
			d.shield_gone_time = 4.8
			d.shard_drop = 25
			d.is_boss = true
		_:
			d.kind = "warden"
			d.max_hp = 4.0
			d.body_radius = 5.0
			d.routine_speed = 36.0
			d.leash_radius = 158.0
			d.notice_radius = 120.0
			d.tell_time = 0.48
			d.recover_time = 1.15
			d.shield_hp = 1.75
			d.shield_gone_time = 4.8
			d.shard_drop = 3
	return d
