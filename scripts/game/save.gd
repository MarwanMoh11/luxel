extends RefCounted
## Static save file user://low_settings.cfg: the best record and whether the tutorial is done (design 11).
## Section `best`: done, time, sold, kills, level; section `game`: tutorial_done. Checks point `path` elsewhere.

const PATH := "user://low_settings.cfg"

static var path := PATH ## checks set their own file so they never touch the player's record


## Returns the best record (a stats dictionary: time, level, kills, light, sold, done) or {} when none.
static func load_best() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section("best"):
		return {}
	var out := {}
	for key in cfg.get_section_keys("best"):
		out[key] = cfg.get_value("best", key)
	return out


## Stores `stats` if it beats the best (ranking: design 11); returns true for a new best.
static func submit(stats: Dictionary) -> bool:
	if not beats(stats, load_best()):
		return false
	var cfg := ConfigFile.new()
	cfg.load(path)
	for key: String in ["done", "time", "sold", "kills", "level"]:
		if stats.has(key):
			cfg.set_value("best", key, stats[key])
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


## Marks the tutorial as done in the save file.
static func set_tutorial_done() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("game", "tutorial_done", true)
	cfg.save(path)
