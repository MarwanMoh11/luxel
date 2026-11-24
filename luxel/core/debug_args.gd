class_name LxDebugArgs
extends RefCounted
## Parses command-line args after `--` (SWARM_SPEC 5.6).

var island: int = 0
var has_island: bool = false
var region: String = ""
var room: String = ""
var moves_override: String = ""
var hearts: int = 0
var god: bool = false
var boss: String = ""
var seed_val: int = 0
var has_seed: bool = false
var lab: String = ""
var ending: String = ""
var slot: String = ""
var quick_play: bool = false
var smoke: bool = false
var any_debug_flag: bool = false


func parse(args: PackedStringArray = PackedStringArray()) -> void:
	var src: PackedStringArray = args if not args.is_empty() else OS.get_cmdline_user_args()
	for raw: String in src:
		var tok: String = raw.strip_edges()
		if tok.is_empty():
			continue
		if tok == "god":
			god = true
			any_debug_flag = true
		elif tok == "play":
			quick_play = true
			any_debug_flag = true
		elif tok == "smoke":
			smoke = true
			any_debug_flag = true
		elif tok.begins_with("island="):
			island = maxi(0, int(tok.get_slice("=", 1)))
			has_island = true
			any_debug_flag = true
		elif tok.begins_with("region="):
			region = tok.get_slice("=", 1)
			any_debug_flag = true
		elif tok.begins_with("room="):
			room = tok.get_slice("=", 1)
			any_debug_flag = true
		elif tok.begins_with("moves="):
			moves_override = tok.get_slice("=", 1)
			any_debug_flag = true
		elif tok.begins_with("hearts="):
			hearts = clampi(int(tok.get_slice("=", 1)), 1, 12)
			any_debug_flag = true
		elif tok.begins_with("boss="):
			boss = tok.get_slice("=", 1)
			any_debug_flag = true
		elif tok.begins_with("seed="):
			seed_val = int(tok.get_slice("=", 1))
			has_seed = true
			any_debug_flag = true
		elif tok.begins_with("lab="):
			lab = tok.get_slice("=", 1)
			any_debug_flag = true
		elif tok.begins_with("ending="):
			ending = tok.get_slice("=", 1)
			any_debug_flag = true
		elif tok.begins_with("slot="):
			slot = tok.get_slice("=", 1)
			any_debug_flag = true


func is_debug_run() -> bool:
	return any_debug_flag or slot == "debug"


func get_override_moves() -> PackedStringArray:
	if moves_override.is_empty():
		return PackedStringArray()
	if moves_override == "all":
		return PackedStringArray(["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"])
	return moves_override.split(",", false)
