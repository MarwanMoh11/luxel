class_name LxFireflyState
extends RefCounted
## Persistent state, bond progression, 8 Pip Charms, Hub Flight Trial medals,
## and 7 wing tint unlocks for Pip the Firefly Companion.
## Backed by Lx.state.story_flags so atomic save/load and slot isolation work automatically.

const TOTAL_BLOOMS: int = 24
const TOTAL_RELAYS: int = 8
const TOTAL_PERCHES: int = 16
const TOTAL_SHRINES: int = 8
const RANK_THRESHOLDS: Array[int] = [0, 4, 10, 18]

const BLOOM_IDS_BY_ISLAND: Dictionary = {
	1: ["bloom_1_plaza", "bloom_1_obs", "bloom_1_river"],
	2: ["bloom_2_harbor", "bloom_2_quays", "bloom_2_reef"],
	3: ["bloom_3_trail", "bloom_3_spore", "bloom_3_canopy"],
	4: ["bloom_4_fen", "bloom_4_sunken", "bloom_4_pier"],
	5: ["bloom_5_landing", "bloom_5_brass", "bloom_5_zenith"],
	6: ["bloom_6_landing", "bloom_6_ash", "bloom_6_approach"],
	7: ["bloom_7_landing", "bloom_7_basin", "bloom_7_spire"],
	8: ["bloom_8_hub", "bloom_8_tide", "bloom_8_kiln"],
}
const RELAY_ID_BY_ISLAND: Dictionary = {
	1: "relay_1_glasshouse", 2: "relay_2_lighthouse", 3: "relay_3_briar", 4: "relay_4_glass",
	5: "relay_5_orrery", 6: "relay_6_cinder", 7: "relay_7_court", 8: "relay_8_mire",
}
const PERCH_IDS_BY_ISLAND: Dictionary = {
	1: ["perch_1_belfry_r2", "perch_1_belfry_r4"],
	2: ["perch_2_galleon_r3", "perch_2_galleon_r8"],
	3: ["perch_3_loom_r3", "perch_3_loom_r8"],
	4: ["perch_4_hourglass_r3", "perch_4_hourglass_r8"],
	5: ["perch_5_orrery_r3", "perch_5_orrery_r8"],
	6: ["perch_6_kiln_r3", "perch_6_kiln_r8"],
	7: ["perch_7_palace_r3", "perch_7_palace_r8"],
	8: ["perch_8_sanctum_r2", "perch_8_sanctum_r4"],
}
const SHRINE_CHARMS: Array[Dictionary] = [
	{"island": 1, "shrine_id": "shrine_1_echo", "charm_id": "chime_wing", "name_key": "PIP_CHARM_1_NAME", "desc_key": "PIP_CHARM_1_DESC"},
	{"island": 2, "shrine_id": "shrine_2_cistern", "charm_id": "sea_spark", "name_key": "PIP_CHARM_2_NAME", "desc_key": "PIP_CHARM_2_DESC"},
	{"island": 3, "shrine_id": "shrine_3_amber", "charm_id": "thorn_pollen", "name_key": "PIP_CHARM_3_NAME", "desc_key": "PIP_CHARM_3_DESC"},
	{"island": 4, "shrine_id": "shrine_4_heron", "charm_id": "dew_veil", "name_key": "PIP_CHARM_4_NAME", "desc_key": "PIP_CHARM_4_DESC"},
	{"island": 5, "shrine_id": "shrine_5_gravity", "charm_id": "comet_tail", "name_key": "PIP_CHARM_5_NAME", "desc_key": "PIP_CHARM_5_DESC"},
	{"island": 6, "shrine_id": "shrine_6_bellows", "charm_id": "ember_wisp", "name_key": "PIP_CHARM_6_NAME", "desc_key": "PIP_CHARM_6_DESC"},
	{"island": 7, "shrine_id": "shrine_7_crypt", "charm_id": "prism_wing", "name_key": "PIP_CHARM_7_NAME", "desc_key": "PIP_CHARM_7_DESC"},
	{"island": 8, "shrine_id": "shrine_8_grotto", "charm_id": "dawn_heart", "name_key": "PIP_CHARM_8_NAME", "desc_key": "PIP_CHARM_8_DESC"},
]

const SEND_RANGES: Array[float] = [128.0, 152.0, 174.0, 196.0]
const LIGHT_RADII: Array[float] = [58.0, 68.0, 76.0, 86.0]
const MARK_BONUSES: Array[float] = [0.25, 0.30, 0.35, 0.40]
const POP_DAMAGES: Array[float] = [1.25, 1.50, 1.75, 2.20]
const COOLDOWNS: Array[float] = [0.45, 0.38, 0.32, 0.26]

const TINT_KEYS: Dictionary = {
	"meadow": {"core": "cream", "glow": "lime", "wing": "ice", "rim": "jade"},
	"dawn": {"core": "cream", "glow": "gold", "wing": "apricot", "rim": "coral"},
	"tide": {"core": "cream", "glow": "sky", "wing": "ice", "rim": "blue"},
	"rose": {"core": "cream", "glow": "rose", "wing": "ice", "rim": "wine"},
	"star": {"core": "cream", "glow": "gold", "wing": "ice", "rim": "sky"},
	"aurora": {"core": "cream", "glow": "ice", "wing": "sky", "rim": "lime"},
	"solar": {"core": "cream", "glow": "gold", "wing": "coral", "rim": "apricot"},
}
const TINT_LABELS: Dictionary = {
	"meadow": "PIP_TINT_MEADOW",
	"dawn": "PIP_TINT_DAWN",
	"tide": "PIP_TINT_TIDE",
	"rose": "PIP_TINT_ROSE",
	"star": "PIP_TINT_STAR",
	"aurora": "PIP_TINT_AURORA",
	"solar": "PIP_TINT_SOLAR",
}


static func is_joined() -> bool:
	if Lx.state == null: return true
	if bool(Lx.state.story_flags.get("firefly_joined", false)) or Lx.state.has_lantern(): return true
	return Lx.state.island_id != 1 or Lx.state.region_id != "overworld"

static func mark_joined() -> void:
	if Lx.state != null: Lx.state.story_flags["firefly_joined"] = true

static func get_nectar_count() -> int:
	return maxi(0, int(Lx.state.story_flags.get("pip_nectar", 0))) if Lx.state != null else 0

static func get_bloom_count() -> int: return mini(_count_prefix("pip_bloom:"), TOTAL_BLOOMS)
static func get_total_blooms() -> int: return TOTAL_BLOOMS
static func get_relay_count() -> int: return mini(_count_prefix("pip_relay:"), TOTAL_RELAYS)
static func get_total_relays() -> int: return TOTAL_RELAYS
static func get_perch_count() -> int: return mini(_count_prefix("pip_perch:"), TOTAL_PERCHES)
static func get_total_perches() -> int: return TOTAL_PERCHES
static func get_shrine_count() -> int: return mini(_count_prefix("pip_shrine:"), TOTAL_SHRINES)
static func get_total_shrines() -> int: return TOTAL_SHRINES
static func get_charm_count() -> int: return mini(_count_prefix("pip_charm:"), TOTAL_SHRINES)


static func is_perch_lit(perch_id: String) -> bool:
	return Lx.state != null and not perch_id.is_empty() and bool(Lx.state.story_flags.get("pip_perch:" + perch_id, false))

static func light_perch(perch_id: String) -> Dictionary:
	if Lx.state == null or perch_id.is_empty() or is_perch_lit(perch_id):
		return {"lit": false, "nectar": get_nectar_count(), "rank": get_bond_rank(), "ranked_up": false}
	var old_rank: int = get_bond_rank()
	Lx.state.story_flags["pip_perch:" + perch_id] = true
	var next_n: int = get_nectar_count() + 1
	Lx.state.story_flags["pip_nectar"] = next_n
	var new_rank: int = get_bond_rank()
	if new_rank >= 4: Lx.state.story_flags["pip_quest_done"] = true
	return {"lit": true, "nectar": next_n, "rank": new_rank, "ranked_up": new_rank > old_rank}


static func is_shrine_cleared(shrine_id: String) -> bool:
	return Lx.state != null and not shrine_id.is_empty() and bool(Lx.state.story_flags.get("pip_shrine:" + shrine_id, false))

static func has_charm(charm_id: String) -> bool:
	return Lx.state != null and not charm_id.is_empty() and bool(Lx.state.story_flags.get("pip_charm:" + charm_id, false))

static func get_charm_spec(charm_id: String) -> Dictionary:
	for s: Dictionary in SHRINE_CHARMS:
		if str(s["charm_id"]) == charm_id: return s
	return {}

static func get_charm_spec_for_island(isl: int) -> Dictionary:
	for s: Dictionary in SHRINE_CHARMS:
		if int(s["island"]) == isl: return s
	return {}

static func is_island_shrine_cleared(isl: int) -> bool:
	var sp: Dictionary = get_charm_spec_for_island(isl)
	return not sp.is_empty() and is_shrine_cleared(str(sp["shrine_id"]))

static func complete_shrine(shrine_id: String, charm_id: String) -> Dictionary:
	if Lx.state == null or shrine_id.is_empty() or is_shrine_cleared(shrine_id):
		return {"completed": false, "charm_id": charm_id, "nectar": get_nectar_count(), "rank": get_bond_rank(), "ranked_up": false}
	var old_rank: int = get_bond_rank()
	Lx.state.story_flags["pip_shrine:" + shrine_id] = true
	if not charm_id.is_empty(): Lx.state.story_flags["pip_charm:" + charm_id] = true
	var next_n: int = get_nectar_count() + 2
	Lx.state.story_flags["pip_nectar"] = next_n
	var new_rank: int = get_bond_rank()
	if new_rank >= 4: Lx.state.story_flags["pip_quest_done"] = true
	return {"completed": true, "charm_id": charm_id, "nectar": next_n, "rank": new_rank, "ranked_up": new_rank > old_rank}


static func get_island_bloom_counts(isl: int) -> Vector2i:
	var found: int = 0
	for id_v: Variant in (BLOOM_IDS_BY_ISLAND.get(isl, []) as Array):
		if is_bloom_collected(str(id_v)): found += 1
	return Vector2i(found, 3)

static func is_island_relay_done(isl: int) -> bool:
	return is_relay_completed(str(RELAY_ID_BY_ISLAND.get(isl, "")))

static func get_island_perch_counts(isl: int) -> Vector2i:
	var lit_n: int = 0
	for id_v: Variant in (PERCH_IDS_BY_ISLAND.get(isl, []) as Array):
		if is_perch_lit(str(id_v)): lit_n += 1
	return Vector2i(lit_n, 2)


static func _count_prefix(prefix: String) -> int:
	if Lx.state == null: return 0
	var count: int = 0
	for k_v: Variant in Lx.state.story_flags.keys():
		if str(k_v).begins_with(prefix) and bool(Lx.state.story_flags[k_v]):
			count += 1
	return count


static func get_bond_rank() -> int:
	var n: int = get_nectar_count()
	var rank: int = 1
	for i: int in range(RANK_THRESHOLDS.size()):
		if n >= RANK_THRESHOLDS[i]: rank = i + 1
	return clampi(rank, 1, 4)


static func is_bloom_collected(bloom_id: String) -> bool:
	return Lx.state != null and not bloom_id.is_empty() and bool(Lx.state.story_flags.get("pip_bloom:" + bloom_id, false))


static func collect_bloom(bloom_id: String, nectar_gain: int = 1) -> Dictionary:
	if Lx.state == null or bloom_id.is_empty() or is_bloom_collected(bloom_id):
		return {"collected": false, "nectar": get_nectar_count(), "rank": get_bond_rank(), "ranked_up": false}
	var old_rank: int = get_bond_rank()
	Lx.state.story_flags["pip_bloom:" + bloom_id] = true
	var next_n: int = get_nectar_count() + maxi(1, nectar_gain)
	Lx.state.story_flags["pip_nectar"] = next_n
	var new_rank: int = get_bond_rank()
	if new_rank >= 4: Lx.state.story_flags["pip_quest_done"] = true
	return {"collected": true, "nectar": next_n, "rank": new_rank, "ranked_up": new_rank > old_rank}


static func is_relay_completed(relay_id: String) -> bool:
	return Lx.state != null and not relay_id.is_empty() and bool(Lx.state.story_flags.get("pip_relay:" + relay_id, false))


static func complete_relay(relay_id: String) -> Dictionary:
	if Lx.state == null or relay_id.is_empty() or is_relay_completed(relay_id):
		return {"completed": false, "nectar": get_nectar_count(), "rank": get_bond_rank(), "ranked_up": false}
	var old_rank: int = get_bond_rank()
	Lx.state.story_flags["pip_relay:" + relay_id] = true
	var next_n: int = get_nectar_count() + 2
	Lx.state.story_flags["pip_nectar"] = next_n
	var new_rank: int = get_bond_rank()
	if new_rank >= 4: Lx.state.story_flags["pip_quest_done"] = true
	return {"completed": true, "nectar": next_n, "rank": new_rank, "ranked_up": new_rank > old_rank}


static func get_send_range() -> float: return SEND_RANGES[get_bond_rank() - 1]
static func get_light_radius() -> float: return LIGHT_RADII[get_bond_rank() - 1]
static func get_mark_bonus() -> float: return MARK_BONUSES[get_bond_rank() - 1] + (0.15 if has_charm("prism_wing") else 0.0)
static func get_pop_damage() -> float: return POP_DAMAGES[get_bond_rank() - 1]
static func get_cooldown() -> float: return COOLDOWNS[get_bond_rank() - 1]

static func get_send_speed_mult() -> float: return 1.15 if has_charm("chime_wing") else 1.0
static func get_tether_bonus_mult() -> float: return 1.25 if has_charm("sea_spark") else 1.0
static func get_pop_radius_mult() -> float: return 1.24 if has_charm("thorn_pollen") else 1.0
static func get_dew_pop_interval() -> int: return 4 if has_charm("dew_veil") else 5
static func get_perch_duration() -> float: return 8.0 if has_charm("comet_tail") else 6.5
static func get_pop_ember_gain() -> float: return 18.0 if has_charm("ember_wisp") else 14.0
static func get_shield_block_cap() -> int: return 2 if has_charm("dawn_heart") else 1


static func record_pollen_pop() -> bool:
	if Lx.state == null: return false
	var pops: int = maxi(0, int(Lx.state.story_flags.get("pip_pops", 0))) + 1
	Lx.state.story_flags["pip_pops"] = pops
	return get_bond_rank() >= 2 and (pops % get_dew_pop_interval() == 0)


static func get_trial_best() -> int:
	return maxi(0, int(Lx.state.story_flags.get("pip_trial_best", 0))) if Lx.state != null else 0

static func get_trial_medal() -> int:
	return clampi(int(Lx.state.story_flags.get("pip_trial_medal", 0)), 0, 3) if Lx.state != null else 0

static func record_trial_result(score: int) -> Dictionary:
	var s: int = maxi(0, score)
	var medal: int = 3 if s >= 2000 else (2 if s >= 1200 else (1 if s >= 600 else 0))
	var prev_best: int = get_trial_best()
	var prev_medal: int = get_trial_medal()
	var best: int = maxi(prev_best, s)
	var unlocked: Array[String] = []
	if Lx.state != null:
		Lx.state.story_flags["pip_trial_best"] = best
		Lx.state.story_flags["pip_trial_medal"] = maxi(prev_medal, medal)
		if medal >= 2 and not bool(Lx.state.story_flags.get("pip_tint_aurora", false)):
			Lx.state.story_flags["pip_tint_aurora"] = true
			unlocked.append("aurora")
		if medal >= 3 and not bool(Lx.state.story_flags.get("pip_tint_solar", false)):
			Lx.state.story_flags["pip_tint_solar"] = true
			unlocked.append("solar")
	return {
		"completed": true, "score": s, "best": best, "is_new_best": s > prev_best,
		"medal": medal, "prev_medal": prev_medal, "unlocked_tints": unlocked,
	}


static func get_unlocked_tints() -> Array[String]:
	var rank: int = get_bond_rank()
	var out: Array[String] = ["meadow"]
	if rank >= 2: out.append_array(["dawn", "tide"])
	if rank >= 3: out.append("rose")
	if rank >= 4: out.append("star")
	if get_trial_medal() >= 2 or (Lx.state != null and bool(Lx.state.story_flags.get("pip_tint_aurora", false))):
		out.append("aurora")
	if get_trial_medal() >= 3 or (Lx.state != null and bool(Lx.state.story_flags.get("pip_tint_solar", false))):
		out.append("solar")
	return out


static func get_tint_id() -> String:
	var raw: String = str(Lx.state.story_flags.get("pip_tint", "meadow")).strip_edges().to_lower() if Lx.state != null else "meadow"
	return raw if get_unlocked_tints().has(raw) else "meadow"


static func cycle_tint() -> String:
	var unlocked: Array[String] = get_unlocked_tints()
	var idx: int = unlocked.find(get_tint_id())
	var next_id: String = unlocked[(idx + 1) % unlocked.size()] if idx >= 0 else unlocked[0]
	if Lx.state != null: Lx.state.story_flags["pip_tint"] = next_id
	return next_id


static func get_tint_colors() -> Dictionary:
	var spec: Dictionary = TINT_KEYS.get(get_tint_id(), TINT_KEYS["meadow"]) as Dictionary
	return {
		"core": LxPalette.color(str(spec["core"]), "cream"),
		"glow": LxPalette.color(str(spec["glow"]), "lime"),
		"wing": LxPalette.color(str(spec["wing"]), "ice"),
		"rim": LxPalette.color(str(spec["rim"]), "jade"),
	}


static func get_tint_label_key(tint_id: String) -> String:
	return str(TINT_LABELS.get(tint_id.strip_edges().to_lower(), "PIP_TINT_MEADOW"))


static func get_bond_desc_key(rank: int) -> String:
	match clampi(rank, 1, 4):
		2: return "PIP_BOND_2_DESC"
		3: return "PIP_BOND_3_DESC"
		4: return "PIP_BOND_4_DESC"
		_: return ""
