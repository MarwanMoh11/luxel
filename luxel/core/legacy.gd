class_name LxLegacy
extends RefCounted
## Gatekeeper for the 81 original Luxel 1.0 regions so legacy FX keyed on
## !is_dungeon, _r1.._r10 suffixes, or hardcoded pixel coordinates only run on them.

const LEGACY_REGIONS: Dictionary = {
	1: {
		"overworld": true,
		"belfry_r1": true, "belfry_r2": true, "belfry_r3": true, "belfry_r4": true,
		"belfry_r5": true, "belfry_r6": true, "belfry_r7": true,
	},
	2: {
		"overworld": true,
		"lighthouse_r1": true, "lighthouse_r2": true, "lighthouse_r3": true, "lighthouse_r4": true,
		"lighthouse_r5": true, "lighthouse_r6": true, "lighthouse_r7": true, "lighthouse_r8": true,
		"lighthouse_r9": true, "lighthouse_r10": true,
	},
	3: {
		"overworld": true,
		"oak_r1": true, "oak_r2": true, "oak_r3": true, "oak_r4": true, "oak_r5": true,
		"oak_r6": true, "oak_r7": true, "oak_r8": true, "oak_r9": true, "oak_r10": true,
	},
	4: {
		"overworld": true,
		"conservatory_r1": true, "conservatory_r2": true, "conservatory_r3": true, "conservatory_r4": true,
		"conservatory_r5": true, "conservatory_r6": true, "conservatory_r7": true, "conservatory_r8": true,
		"conservatory_r9": true, "conservatory_r10": true,
	},
	5: {
		"overworld": true,
		"orrery_r1": true, "orrery_r2": true, "orrery_r3": true, "orrery_r4": true, "orrery_r5": true,
		"orrery_r6": true, "orrery_r7": true, "orrery_r8": true, "orrery_r9": true, "orrery_r10": true,
	},
	6: {
		"overworld": true,
		"kiln_r1": true, "kiln_r2": true, "kiln_r3": true, "kiln_r4": true, "kiln_r5": true,
		"kiln_r6": true, "kiln_r7": true, "kiln_r8": true, "kiln_r9": true, "kiln_r10": true,
	},
	7: {
		"overworld": true,
		"spire_r1": true, "spire_r2": true, "spire_r3": true, "spire_r4": true, "spire_r5": true,
		"spire_r6": true, "spire_r7": true, "spire_r8": true, "spire_r9": true, "spire_r10": true,
	},
	8: {
		"overworld": true,
		"sanctum_r1": true, "sanctum_r2": true, "sanctum_r3": true, "sanctum_r4": true,
		"sanctum_r5": true, "sanctum_r6": true,
	},
}


static func is_legacy_region(island: int, region: String) -> bool:
	var isl_v: Variant = LEGACY_REGIONS.get(island, null)
	if isl_v is Dictionary:
		return bool((isl_v as Dictionary).get(region, false))
	return false


static func is_legacy_node(region_node: Node) -> bool:
	if region_node == null or not is_instance_valid(region_node):
		return false
	var isl_v: Variant = region_node.get("current_island_id")
	var reg_v: Variant = region_node.get("current_region_id")
	if isl_v == null or reg_v == null:
		return false
	return is_legacy_region(int(isl_v), str(reg_v))


static func legacy_regions_for_island(island: int) -> PackedStringArray:
	var out := PackedStringArray()
	var isl_v: Variant = LEGACY_REGIONS.get(island, null)
	if isl_v is Dictionary:
		for k: Variant in (isl_v as Dictionary).keys():
			out.append(str(k))
		out.sort()
	return out
