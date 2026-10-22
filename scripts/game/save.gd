extends RefCounted
## Static save file user://low_settings.cfg: the best records and the title's choices (design 11).
## Sections `best` and `best_gamer` (GAMER MODE's): done, time, sold, kills, level; section `game`: tutorial_done,
## gamer. Checks point `path` elsewhere.

const PATH := "user://low_settings.cfg"

static var path := PATH ## checks set their own file so they never touch the player's record
static var gamer := true ## GAMER MODE (the title's toggle, on by default): its runs keep their own best record


## Returns the best record (a stats dictionary: time, level, kills, light, sold, done) or {} when none.
static func load_best() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section(_best_section()):
		return {}
	var out := {}
	for key in cfg.get_section_keys(_best_section()):
		out[key] = cfg.get_value(_best_section(), key)
	return out


## Stores `stats` if it beats the best (ranking: design 11); returns true for a new best.
static func submit(stats: Dictionary) -> bool:
	if not beats(stats, load_best()):
		return false
	var cfg := ConfigFile.new()
	cfg.load(path)
	for key: String in ["done", "time", "sold", "kills", "level"]:
		if stats.has(key):
			cfg.set_value(_best_section(), key, stats[key])
	cfg.save(path)
	return true


## True if run `a` beats record `b`: done beats not done; both done: lower time; neither: more sold, then longer.
static func beats(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty():
		return true
	var a_done := bool(a.get("done", false))
	var b_done := bool(b.get("done", false))
	if a_done != b_done:
		return a_done
	var a_time := float(a.get("time", 0.0))
	var b_time := float(b.get("time", 0.0))
	if a_done:
		return a_time < b_time
	var a_sold := int(a.get("sold", 0))
	var b_sold := int(b.get("sold", 0))
	if a_sold != b_sold:
		return a_sold > b_sold
	return a_time > b_time


## True once the first play finished the tutorial (then the title skips the intro and tutorial).
static func tutorial_done() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	return bool(cfg.get_value("game", "tutorial_done", false))


## Marks the tutorial as done in the save file (once: later calls leave the file alone, a save is an IndexedDB sync on the web).
static func set_tutorial_done() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	if bool(cfg.get_value("game", "tutorial_done", false)):
		return
	cfg.set_value("game", "tutorial_done", true)
	cfg.save(path)


## Reads GAMER MODE from the save file into `gamer` (on until the player turns it off).
static func load_gamer() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	gamer = bool(cfg.get_value("game", "gamer", true))


## Sets GAMER MODE and keeps it in the save file.
static func set_gamer(on: bool) -> void:
	gamer = on
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("game", "gamer", on)
	cfg.save(path)


static func _best_section() -> String:
	return "best_gamer" if gamer else "best"
