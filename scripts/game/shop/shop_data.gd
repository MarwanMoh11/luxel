extends RefCounted
## Pure data for the SETTINGS shop (design 9.2): tabs, rows, steps, rewards, quips, finale order, constants.
## Power keys: damage / fire / speed / range = +fraction (compounding, x (1 + v)); hearts / shots / pierce add.
## Text uses the 3x5 charset: A-Z 0-9 ! - : x / . + = space %. STORY.md owns the copy; these are its quips.

## In strip order. unlock = the level whose menu first shows the tab (menu n opens at level n+1); 0 = revealed.
## AUDIO is not in the 9.2 table: it shows (all NOT FOR SALE) from the second menu, design 2.
const TABS: Array = [
	{"name": "GENERAL", "unlock": 2, "rows": ["subtitles", "tips", "shake"]},
	{"name": "INTERFACE", "unlock": 4, "rows": ["timer", "gauge", "hearts", "warnings", "language"]},
	{"name": "GAMEPLAY", "unlock": 8, "rows": ["difficulty", "mercy", "knockback", "healing"]},
	{"name": "CONTROLS", "unlock": 12, "rows": ["movement", "input_delay", "aim", "up_key"]},
	{"name": "AUDIO", "unlock": 3, "rows": ["music", "sound", "audio_quality"]},
	{"name": "GRAPHICS", "unlock": 2, "rows": ["ray_tracing", "hit_flash", "particles", "animations", "frame_rate",
		"vsync", "colour", "resolution", "brightness"]},
	{"name": "ADVANCED", "unlock": 0, "rows": ["confirm", "pixels"]},
]
const ADVANCED_TAB := 6
const AUDIO_TAB := 4
const GRAPHICS_TAB := 5

## act: the act the row is first sold in (1-3), 4 = the finale (sold by the menu itself).
## beauty: NOT FOR SALE until CONFIRM SALES (design 9.1, beauty rule).
const ROWS := {
	# GENERAL (LV 2)
	"subtitles": {"name": "SUBTITLES", "start": "ON", "beauty": false, "act": 1, "steps": [
		{"value": "OFF", "power": {"fire": 0.08}, "quip": "THERE WERE NO SUBTITLES. FREE POWER."}]},
	"tips": {"name": "TIPS", "start": "ON", "beauty": false, "act": 1, "steps": [
		{"value": "OFF", "power": {"damage": 0.10}, "quip": "NO MORE HINTS. FIGURE IT OUT."}]},
	"shake": {"name": "SCREEN SHAKE", "start": "ON", "beauty": false, "act": 1, "steps": [
		{"value": "OFF", "power": {"range": 0.12}, "quip": "HITS STOP SHAKING THE SCREEN."}]},
	# INTERFACE (LV 4)
	"timer": {"name": "TIMER", "start": "SHOWN", "beauty": false, "act": 1, "steps": [
		{"value": "HIDDEN", "power": {"damage": 0.15}, "quip": "HOW LONG HAVE YOU BEEN OUT HERE."}]},
	"gauge": {"name": "LANTERN GAUGE", "start": "SHOWN", "beauty": false, "act": 1, "steps": [
		{"value": "HIDDEN", "power": {"fire": 0.15}, "quip": "LISTEN TO THE LANTERN INSTEAD."}]},
	"hearts": {"name": "HEARTS", "start": "SHOWN", "beauty": false, "act": 1, "steps": [
		{"value": "HIDDEN", "power": {"hearts": 2}, "quip": "MORE HEARTS. YOU JUST CANNOT SEE THEM."}]},
	"warnings": {"name": "WARNINGS", "start": "ON", "beauty": false, "act": 2, "steps": [
		{"value": "OFF", "power": {"pierce": 1}, "quip": "NO MORE ARROWS AT THE EDGES."}]},
	"language": {"name": "LANGUAGE", "start": "ENGLISH", "beauty": false, "act": 2, "steps": [
		{"value": "GIBBERISH", "power": {"shots": 1}, "quip": "ALL TEXT TURNS TO NONSENSE. FOR 2 MENUS."}]},
	# GAMEPLAY (LV 8)
	"difficulty": {"name": "DIFFICULTY", "start": "NORMAL", "beauty": false, "act": 2, "steps": [
		{"value": "HARD", "power": {"damage": 0.20}, "quip": "ENEMIES MOVE 15% FASTER."},
		{"value": "CRUEL", "power": {"fire": 0.25}, "quip": "AND NOW 30% FASTER."}]},
	"mercy": {"name": "MERCY TIME", "start": "1.5 S", "beauty": false, "act": 2, "steps": [
		{"value": "0.8 S", "power": {"hearts": 1, "damage": 0.10}, "quip": "HITS CAN COME BACK TO BACK."}]},
	"knockback": {"name": "KNOCKBACK", "start": "ON", "beauty": false, "act": 2, "steps": [
		{"value": "OFF", "power": {"range": 0.25}, "quip": "ENEMIES STOP FLINCHING."}]},
	"healing": {"name": "HEALING", "start": "ON", "beauty": false, "act": 2, "steps": [
		{"value": "OFF", "power": {"damage": 0.30}, "quip": "NO MORE HEALING. NOT EVEN BACK."}]},
	# CONTROLS (LV 12)
	"movement": {"name": "MOVEMENT", "start": "SNAPPY", "beauty": false, "act": 3, "steps": [
		{"value": "ICE", "power": {"damage": 0.35}, "quip": "THE ISLAND IS A FROZEN POND NOW."}]},
	"input_delay": {"name": "INPUT DELAY", "start": "0 MS", "beauty": false, "act": 3, "steps": [
		{"value": "200 MS", "power": {"pierce": 1, "damage": 0.20}, "quip": "YOU MOVE WHEN YOU REMEMBER TO."}]},
	"aim": {"name": "AIM ASSIST", "start": "NEAREST", "beauty": false, "act": 3, "steps": [
		{"value": "RANDOM", "power": {"shots": 2}, "quip": "YOU SHOOT AT WHATEVER."}]},
	"up_key": {"name": "UP KEY", "start": "ON", "beauty": false, "act": 3, "steps": [
		{"value": "FLAKY", "power": {"damage": 0.40, "fire": 0.25}, "quip": "THE UP KEY WORKS. MOSTLY."}]},
	# AUDIO (finale rows)
	"music": {"name": "MUSIC", "start": "ON", "beauty": true, "act": 4, "steps": [
		{"value": "OFF", "power": {"hearts": 1, "fire": 0.10}, "quip": "THE ORGANIST GOES HOME."}]},
	"sound": {"name": "SOUND", "start": "ON", "beauty": true, "act": 4, "steps": [
		{"value": "OFF", "power": {"damage": 0.30}, "quip": "SILENCE. WAS THAT A HIT."}]},
	"audio_quality": {"name": "AUDIO QUALITY", "start": "HIGH", "beauty": true, "act": 4, "steps": [
		{"value": "AWFUL", "power": {"damage": 0.20}, "quip": "A PHONE CALL FROM DOWN A WELL."}]},
	# GRAPHICS (LV 2): RAY TRACING is the only row for sale before the finale
	"ray_tracing": {"name": "RAY TRACING", "start": "OFF", "beauty": false, "act": 1, "steps": [
		{"value": "SOLD", "power": {"speed": 0.10}, "quip": "IT WAS NEVER ON. WE SOLD IT ANYWAY."}]},
	"hit_flash": {"name": "HIT FLASH", "start": "ON", "beauty": true, "act": 4, "steps": [
		{"value": "OFF", "power": {"fire": 0.15}, "quip": "DID THAT EVEN HIT."}]},
	"particles": {"name": "PARTICLES", "start": "ON", "beauty": true, "act": 4, "steps": [
		{"value": "OFF", "power": {"range": 0.15}, "quip": "THE FIREFLIES GO HOME."}]},
	"animations": {"name": "ANIMATIONS", "start": "ON", "beauty": true, "act": 4, "steps": [
		{"value": "OFF", "power": {"fire": 0.15}, "quip": "EVERYONE FREEZES IN ONE POSE."}]},
	"frame_rate": {"name": "FRAME RATE", "start": "60", "beauty": true, "act": 4, "steps": [
		{"value": "20", "power": {"speed": 0.15, "fire": 0.15}, "quip": "A SLIDESHOW. WITH TEETH."}]},
	"vsync": {"name": "VSYNC", "start": "ON", "beauty": true, "act": 4, "steps": [
		{"value": "OFF", "power": {"damage": 0.25}, "quip": "THE PICTURE TEARS IN HALF."}]},
	"colour": {"name": "COLOURS", "start": "20", "beauty": true, "act": 4, "steps": [
		{"value": "4", "power": {"damage": 0.20}, "quip": "FOUR COLOURS. LIKE AN OLD HANDHELD."},
		{"value": "2", "power": {"damage": 0.25}, "quip": "BLACK AND WHITE. MOSTLY BLACK."}]},
	"resolution": {"name": "RESOLUTION", "start": "FULL", "beauty": true, "act": 4, "steps": [
		{"value": "HALF", "power": {"shots": 1}, "quip": "EVERYTHING GETS CHUNKY."},
		{"value": "QUARTER", "power": {"shots": 1}, "quip": "WHICH BLOB IS WICK."}]},
	"brightness": {"name": "BRIGHTNESS", "start": "100%", "beauty": true, "act": 4, "steps": [
		{"value": "50%", "power": {"pierce": 1}, "quip": "ALL THE LANTERNS GO OUT. BUT ONE."}]},
	# ADVANCED (revealed): CONFIRM SALES starts the finale; PIXELS appears after the 13th self-sale
	"confirm": {"name": "CONFIRM SALES", "start": "ON", "beauty": false, "act": 4, "steps": [
		{"value": "OFF", "power": {"hearts": 2, "damage": 0.25}, "quip": "ALL THE PRETTY SETTINGS. ONE BIG BLAST."}]},
	"pixels": {"name": "PIXELS", "start": "100%", "beauty": true, "act": 4, "steps": []}, # generated: step()
}

## The self-sale order after CONFIRM SALES (design 10.2): 13 sales, COLOURS and RESOLUTION twice.
const FINALE_ORDER: Array[String] = ["hit_flash", "particles", "animations", "audio_quality", "frame_rate", "music",
	"vsync", "colour", "brightness", "resolution", "colour", "resolution", "sound"]
const PIXEL_STEPS := 100
const PIXEL_POWER := {"damage": 0.03, "fire": 0.02} ## one PIXELS step (design 10.3)
const PIXEL_QUIP := "-1% PIXELS."
const PIXEL_STEP_LEN: Array[float] = [0.6, 0.2] ## seconds per auto PIXELS step, first to last
const FINALE_GAP: Array[float] = [4.0, 2.6] ## seconds of play before self-sale k, first to last
const FINALE_DEADLINE := 330.0 ## run seconds: ADVANCED reveals at the first level-up after this
const CIPHER := "QZXJKVBPYGFWUMCLDHRSNIOATE" ## LANGUAGE: A-Z map through this
const LANGUAGE_MENUS := 2 ## LANGUAGE scrambles text until the 2nd menu opened after its sale ends (shop.gd)
const LANGUAGE_BACK := "ENGLISH!" ## LANGUAGE's value once it wore off (still SOLD OUT; the column fits 9)
const BUY_BACK_AFTER := 11 ## early steps sold before player menus offer BUY BACK (once per run, design 9.4)
## Rows BUY BACK can return (one step; the row closes for good). All are read live, so the lower level reverts them.
## Not SUBTITLES or RAY TRACING (nothing comes back), LANGUAGE (it wears off), CONFIRM SALES or the finale rows.
const BUY_BACK_ROWS: Array[String] = ["tips", "shake", "timer", "gauge", "hearts", "warnings", "difficulty", "mercy",
	"knockback", "healing", "movement", "input_delay", "aim", "up_key"]
const CONFIRM := "confirm"
const PIXELS := "pixels"
const PLAYER_SALES := 19 ## early steps + CONFIRM SALES: the "SOLD n OF 19" count

const POWER_NAMES := {"damage": "DAMAGE", "fire": "FIRE RATE", "speed": "SPEED", "range": "RANGE"}


## The reward text of a power dictionary, e.g. "+10% DAMAGE" (3x5 charset only).
static func label(power: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in power:
		var v: float = power[key]
		match key:
			"hearts":
				parts.append("+%d HEART%s" % [v, "" if v == 1 else "S"])
			"shots":
				parts.append("+%d SHOT%s" % [v, "" if v == 1 else "S"])
			"pierce":
				parts.append("+%d PIERCE" % v)
			_:
				parts.append("+%d%% %s" % [roundi(v * 100.0), POWER_NAMES[key]])
	return " ".join(parts)


## The number of early/mid steps the player sells before ADVANCED (18).
static func early_steps() -> int:
	var n := 0
	for id: String in early_rows():
		n += steps(id)
	return n


## Rows the player can sell before CONFIRM SALES, in strip order (17 rows, 18 steps).
static func early_rows() -> Array[String]:
	var out: Array[String] = []
	for tab: Dictionary in TABS:
		if tab["unlock"] == 0:
			continue
		for id: String in tab["rows"]:
			if not ROWS[id]["beauty"]:
				out.append(id)
	return out


## How many times row `id` can be sold.
static func steps(id: String) -> int:
	return PIXEL_STEPS if id == PIXELS else ROWS[id]["steps"].size()


## Sale number `i` (0-based) of row `id`: {value, power, quip}.
static func step(id: String, i: int) -> Dictionary:
	if id == PIXELS:
		var left := PIXEL_STEPS - 1 - i
		return {"value": "OFF" if left <= 0 else "%d%%" % left, "power": PIXEL_POWER, "quip": PIXEL_QUIP}
	return ROWS[id]["steps"][i]


## The value shown after `sold` sales of row `id`.
static func value(id: String, sold: int) -> String:
	return ROWS[id]["start"] if sold <= 0 else step(id, sold - 1)["value"]


## The tab index that holds row `id` (-1 if none).
static func tab_of(id: String) -> int:
	for t in TABS.size():
		if id in TABS[t]["rows"]:
			return t
	return -1
