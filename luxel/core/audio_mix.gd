class_name LxAudioMix
extends RefCounted
## In-play mix policy for LxAudioService (AUD-1):
## ambience aliases & hub bed, per-SFX retrigger guards, polyphony caps,
## enemy-tell music ducking, and surface footstep overrides.

const ISLAND_AMBIENCE: Dictionary = {
	0: ["night_breeze", "kiln_embers"],
	1: ["night_breeze", "river_murmur"],
	2: ["harbor_tide", "harbor_rigging"],
	3: ["forest_wind", "thornwood_night"],
	4: ["marsh_rain", "marsh_reeds"],
	5: ["observatory_chime", "orrery_clockwork"],
	6: ["kiln_rumble", "kiln_embers"],
	7: ["shoals_echo", "shoals_chimes"],
	8: ["long_night_drone", "sanctum_bells"],
}

const AMBIENCE_ALIASES: Dictionary = {
	"clockwork_tick": "orrery_clockwork",
	"cave_drip": "river_murmur",
	"forge_rumble": "kiln_rumble",
	"ember_crackle": "kiln_embers",
	"wind_howl": "forest_wind",
	"void_hum": "long_night_drone",
}

const MIN_INTERVAL_BY_ID: Dictionary = {
	"lamp_lit": 0.28,
	"brazier_lit": 0.22,
	"denied": 0.30,
	"earth_burrow": 0.24,
	"dusk_clock_chime": 0.22,
	"silk_spark_run": 0.22,
	"slag_pour": 0.24,
	"slag_cool": 0.24,
	"train_chug": 0.26,
	"harbor_creak": 0.18,
	"shadow_whisper": 0.16,
	"warden_alert": 0.16,
	"owl_lock": 0.18,
	"footstep_stone": 0.15,
	"footstep_grass": 0.15,
	"footstep_wood": 0.15,
	"footstep_ash": 0.15,
	"footstep_crystal": 0.16,
	"footstep_water": 0.16,
	"heat_boots_step": 0.15,
	"mirror_avatar_step": 0.16,
	"beetle_hoof": 0.15,
	"heavy_hit": 0.10,
	"sunflare_burst": 0.18,
	"enemy_kill": 0.11,
	"magma_crack": 0.14,
	"shield_shatter": 0.12,
	"lantern_throw": 0.11,
	"lantern_catch": 0.11,
	"lantern_recall": 0.12,
	"lantern_land": 0.11,
	"dash_whoosh": 0.11,
	"zip_streak": 0.12,
	"shield_clang": 0.09,
	"crystal_clank": 0.09,
	"thorn_clank": 0.09,
	"bolt_fire": 0.065,
	"bolt_chip": 0.08,
	"bolt_wall": 0.085,
	"mirror_ping": 0.09,
	"prism_bounce": 0.09,
	"prop_chime": 0.12,
	"bell_toll_heavy": 0.20,
	"bell_dawn_ring": 0.16,
	"bell_dusk_ring": 0.16,
	"bell_war_ring": 0.16,
	"lens_reveal": 0.14,
	"moon_pool_silver": 0.16,
	"moon_pool_black": 0.16,
	"mask_steal": 0.20,
	"dawn_burst": 0.25,
	"great_lamp_bloom": 0.25,
}

const SINGLE_VOICE_IDS: Dictionary = {
	"denied": true,
	"lamp_lit": true,
	"beam_charge": true,
	"sunflare_burst": true,
	"dawn_burst": true,
	"great_lamp_bloom": true,
	"footstep_stone": true,
	"footstep_grass": true,
	"footstep_wood": true,
	"footstep_ash": true,
	"footstep_crystal": true,
	"footstep_water": true,
	"heat_boots_step": true,
	"mirror_avatar_step": true,
	"train_chug": true,
}

const BOSS_ROAR_SUBSTR: Array[String] = [
	"_roar", "phase_shift_crown", "boss_awaken", "boss_kill", "boss_victory", "stagger_break",
]
const TELL_SUBSTR: Array[String] = [
	"_tell", "_windup", "_inhale", "_swell", "_crouch", "_mark", "owl_lock",
	"warden_alert", "beam_charge", "shadow_whisper", "void_hum",
]


static func resolve_ambience_name(raw_name: String) -> String:
	var s: String = raw_name.strip_edges()
	return str(AMBIENCE_ALIASES.get(s, s))


static func island_ambience(island_id: int) -> Array:
	return ISLAND_AMBIENCE.get(island_id, ["night_breeze"]) as Array


static func surface_override(sfx_id: String, island_id: int, region_id: String) -> String:
	if sfx_id == "footstep_stone":
		if island_id == 0:
			return "footstep_wood"
		if island_id == 2 and region_id.begins_with("galleon_"):
			return "footstep_wood"
	return sfx_id


static func min_interval_for(sfx_id: String, base_id: String, default_s: float = 0.05) -> float:
	var iv: float = default_s
	if MIN_INTERVAL_BY_ID.has(sfx_id):
		iv = maxf(iv, float(MIN_INTERVAL_BY_ID[sfx_id]))
	if MIN_INTERVAL_BY_ID.has(base_id):
		iv = maxf(iv, float(MIN_INTERVAL_BY_ID[base_id]))
	return iv


static func max_polyphony_for(base_id: String) -> int:
	return 1 if SINGLE_VOICE_IDS.has(base_id) else 2


static func cue_trim_db(cue_name: String) -> float:
	if cue_name == "title" or cue_name == "hub":
		return 1.5
	if cue_name == "ending_dawn" or cue_name == "credits":
		return 0.5
	return 0.0


static func dynamic_music_duck(sfx_id: String, base_id: String) -> Vector2:
	# Returns Vector2(duck_db, hold_secs) to carve brief clarity in music for tells & roars.
	for tok: String in BOSS_ROAR_SUBSTR:
		if sfx_id.contains(tok) or base_id.contains(tok):
			return Vector2(2.6, 0.45)
	for tok: String in TELL_SUBSTR:
		if sfx_id.contains(tok) or base_id.contains(tok):
			return Vector2(1.8, 0.28)
	return Vector2.ZERO


static func ensure_limiter(bus_idx: int, ceiling_db: float, threshold_db: float, soft_clip_db: float) -> void:
	if bus_idx < 0: return
	for i: int in range(AudioServer.get_bus_effect_count(bus_idx)):
		var fx: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
		if fx is AudioEffectLimiter:
			var ex: AudioEffectLimiter = fx as AudioEffectLimiter
			ex.ceiling_db = ceiling_db; ex.threshold_db = threshold_db; ex.soft_clip_db = soft_clip_db
			return
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = ceiling_db; lim.threshold_db = threshold_db; lim.soft_clip_db = soft_clip_db
	AudioServer.add_bus_effect(bus_idx, lim)


static func resolve_ambience_arg(raw: Variant) -> Array:
	if raw is Array and not (raw as Array).is_empty(): return raw as Array
	if raw is String:
		var s: String = (raw as String).strip_edges()
		if s.begins_with("island"): return island_ambience(int(s.substr(6)))
		if not s.is_empty(): return [s]
	return []


static func pick_pool_slot(pool: Array, pool_ids: PackedStringArray, base_id: String, max_poly: int, cursor: int) -> Vector2i:
	var active_same: int = 0
	var steal_idx: int = -1
	for i: int in range(pool.size()):
		if (pool[i] as Node).get("playing") and pool_ids[i] == base_id:
			active_same += 1
			if steal_idx < 0: steal_idx = i
	if active_same >= max_poly and steal_idx >= 0:
		return Vector2i(steal_idx, cursor)
	for k: int in range(pool.size()):
		var idx: int = (cursor + k) % pool.size()
		if not (pool[idx] as Node).get("playing"):
			return Vector2i(idx, (idx + 1) % pool.size())
	return Vector2i(cursor, (cursor + 1) % pool.size())
