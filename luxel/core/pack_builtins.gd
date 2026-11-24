class_name LxPackBuiltins
extends RefCounted
## Seeds built-in Luxel 1.0 bosses, grand dungeons, and factory/SFX registries into LxPackRegistry.

const BUILTIN_BOSS_ROWS: Array = [
	["bell_warden", 1, "MINIBOSS_1", [0.5], true, "belfry", "belfry_r5", "island1_boss_p1", "island1_boss_p2", "none", "bell_warden_defeated", []],
	["bellkeeper", 1, "BOSS_BELLKEEPER", [0.5, 0.2], false, "belfry", "belfry_r7", "island1_boss_p1", "island1_boss_p2", "full", "boss_bellkeeper_defeated", ["grand_bellkeeper", "boss_bellkeeper"]],
	["tide_captain", 2, "MINIBOSS_2", [0.5], true, "lighthouse", "lighthouse_r6", "island2_boss_p1", "island2_boss_p2", "none", "tide_captain_defeated", ["boss_tide_captain"]],
	["lighthouse_hermit", 2, "BOSS_HERMIT", [0.66, 0.33], false, "lighthouse", "lighthouse_r10", "island2_boss_p1", "island2_boss_p2", "full", "boss_lighthouse_hermit_defeated", ["boss_hermit", "hermit"]],
	["elder_sporecap", 3, "MINIBOSS_3", [0.5], true, "hollow_oak", "oak_r6", "island3_boss_p1", "island3_boss_p2", "none", "elder_sporecap_defeated", ["boss_elder_sporecap"]],
	["briar_matron", 3, "BOSS_MATRON", [0.66, 0.33], false, "hollow_oak", "oak_r10", "island3_boss_p1", "island3_boss_p2", "full", "boss_briar_matron_defeated", ["boss_matron", "matron"]],
	["great_lily_hopper", 4, "MINIBOSS_4", [0.5], true, "conservatory", "conservatory_r6", "island4_boss_p1", "island4_boss_p2", "none", "great_lily_hopper_defeated", ["boss_great_lily_hopper"]],
	["heron_abbess", 4, "BOSS_ABBESS", [0.66, 0.33], false, "conservatory", "conservatory_r10", "island4_boss_p1", "island4_boss_p2", "full", "boss_heron_abbess_defeated", ["boss_abbess", "abbess"]],
	["clockwork_warden", 5, "MINIBOSS_5", [0.5], true, "orrery", "orrery_r6", "island5_boss_p1", "island5_boss_p2", "none", "clockwork_warden_defeated", ["boss_clockwork_warden"]],
	["astronomer", 5, "BOSS_ASTRONOMER", [0.66, 0.33], false, "orrery", "orrery_r10", "island5_boss_p1", "island5_boss_p2", "full", "boss_astronomer_defeated", ["boss_astronomer", "the_astronomer"]],
	["forge_warden", 6, "MINIBOSS_6", [0.5], true, "great_kiln", "kiln_r6", "island6_boss_p1", "island6_boss_p2", "none", "forge_warden_defeated", ["boss_forge_warden"]],
	["kilnmother", 6, "BOSS_KILNMOTHER", [0.66, 0.33], false, "great_kiln", "kiln_r10", "island6_boss_p1", "island6_boss_p2", "full", "boss_kilnmother_defeated", ["boss_kilnmother", "the_kilnmother"]],
	["moonshade_warden", 7, "MINIBOSS_7", [0.5], true, "mirror_spire", "spire_r6", "island7_boss_p1", "island7_boss_p2", "none", "moonshade_warden_defeated", ["spire_warden", "boss_moonshade_warden"]],
	["hollow_wick_boss", 7, "BOSS_HOLLOW", [0.66, 0.33], false, "mirror_spire", "spire_r10", "island7_boss_p1", "island7_boss_p2", "full", "boss_hollow_wick_defeated", ["hollow_wick", "boss_hollow", "hollow"]],
	["night_harbinger", 8, "MINIBOSS_8", [0.5], true, "bell_sanctum", "sanctum_r4", "island8_boss_p1", "island8_boss_p2", "none", "night_harbinger_defeated", ["mini_night_harbinger", "boss_night_harbinger"]],
	["the_hush", 8, "BOSS_HUSH", [0.75, 0.5, 0.25], false, "bell_sanctum", "sanctum_r6", "island8_boss_p1", "island8_boss_p2", "full", "boss_the_hush_defeated", ["boss_hush", "hush"]],
]

const BUILTIN_DUNGEON_PREFIX: Dictionary = {
	1: "belfry", 2: "lighthouse", 3: "oak", 4: "conservatory",
	5: "orrery", 6: "kiln", 7: "spire", 8: "sanctum",
}
const BUILTIN_DUNGEON_NAME_KEYS: Dictionary = {
	1: "ZONE_BELFRY", 2: "DUNGEON_2_NAME", 3: "DUNGEON_3_NAME", 4: "DUNGEON_4_NAME",
	5: "DUNGEON_5_NAME", 6: "DUNGEON_6_NAME", 7: "DUNGEON_7_NAME", 8: "DUNGEON_8_NAME",
}


static func seed_registry(reg: LxPackRegistry) -> void:
	if Lx.data_islands.is_empty():
		Lx.load_all_data()
	for k: Variant in LxInteractableFactory.SCRIPTS.keys():
		reg._builtin_inter_kinds[str(k)] = true
	for k: Variant in LxEnemyFactory.KIND_SCRIPTS.keys():
		reg._builtin_enemy_kinds[str(k)] = true
	for k: Variant in LxSfxMap.EXACT.keys():
		reg._builtin_sfx_ids[str(k)] = true
	for k: Variant in LxSfxMap.SFX_VARIANTS.keys():
		reg._builtin_sfx_ids[str(k)] = true

	for row: Array in BUILTIN_BOSS_ROWS:
		var bid: String = str(row[0])
		reg._bosses[bid] = {
			"id": bid, "island": int(row[1]), "name_key": str(row[2]),
			"phases": (row[3] as Array).duplicate(), "mini": bool(row[4]),
			"dungeon": str(row[5]), "region": str(row[6]),
			"music": str(row[7]), "music_p2": str(row[8]),
			"heart": str(row[9]), "flag": str(row[10]), "arena_lock": true, "builtin": true,
		}
		reg._builtin_boss_ids[bid] = true
		for al: Variant in (row[11] as Array):
			reg._boss_aliases[str(al)] = bid

	var islands_arr: Array = Lx.data_islands.get("islands", []) as Array
	for item: Variant in islands_arr:
		if not (item is Dictionary):
			continue
		var idata: Dictionary = item as Dictionary
		var isl: int = int(idata.get("id", 0))
		var did: String = str(idata.get("dungeon_id", ""))
		if isl <= 0 or did.is_empty():
			continue
		var pref: String = str(BUILTIN_DUNGEON_PREFIX.get(isl, did)) + "_"
		var regs: Array[String] = []
		for reg_name: String in LxLegacy.legacy_regions_for_island(isl):
			if reg_name.begins_with(pref):
				regs.append(reg_name)
		regs.sort_custom(_sort_room_names)
		var entry_r: String = regs[0] if not regs.is_empty() else (pref + "r1")
		reg._dungeons[did] = {
			"id": did,
			"name_key": str(BUILTIN_DUNGEON_NAME_KEYS.get(isl, "")),
			"name": str(idata.get("dungeon_name", did)),
			"island": isl,
			"entry": entry_r,
			"regions": regs,
			"mini_boss": str(idata.get("mini_boss", "")),
			"boss": str(idata.get("boss", "")),
			"theme": str(idata.get("slug", "")),
			"music": "island%d_dungeon" % isl,
			"requires_flags": [],
			"done_flag": "dungeon_done:" + did,
			"grand": true,
			"builtin": true,
		}
		reg._builtin_dungeon_ids[did] = true
		reg._append_island_dungeon(isl, did)
		for r: String in regs:
			reg._region_to_dungeon["%d:%s" % [isl, r]] = did


static func _sort_room_names(a: String, b: String) -> bool:
	var ai: int = a.rfind("_r")
	var bi: int = b.rfind("_r")
	if ai >= 0 and bi >= 0 and a.left(ai) == b.left(bi):
		return int(a.substr(ai + 2)) < int(b.substr(bi + 2))
	return a < b
