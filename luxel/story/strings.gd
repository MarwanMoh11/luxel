class_name LxStrings
extends RefCounted
## Single source of truth for every player-facing string in Luxel 1.0.
## Allowed 3x5 charset: A-Z 0-9 ! - : x / . + = space and %. All caps. Max 45 chars per line.

const ALLOWED: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-:x/.+= %"
const MAX_LEN: int = 45

const TABLE: Dictionary = {
	# ---- Formatting helpers ----
	"FMT_CLOCK": "%s:%s",
	"FMT_PCT": "%d%",
	"FMT_PAIR": "%s: %s",
	"FMT_DASH_PAIR": "%s - %s",

	# ---- Title & Slot Select ----
	"TITLE_WORDMARK": "LUXEL",
	"TITLE_SUBTITLE": "THE LAST LANTERN",
	"TITLE_PLAY": "PLAY",
	"TITLE_OPTIONS": "OPTIONS",
	"TITLE_QUIT": "QUIT",
	"TITLE_PROMPT": "ENTER OR CLICK TO BEGIN",
	"SLOT_SELECT_TITLE": "CHOOSE A LANTERN",
	"SLOT_LABEL": "SLOT %d",
	"SLOT_EMPTY": "EMPTY SLOT",
	"SLOT_CONTINUE": "CONTINUE",
	"SLOT_NEW": "NEW GAME",
	"SLOT_DELETE": "DELETE",
	"SLOT_CONFIRM_DEL": "DELETE SLOT %d!",
	"SLOT_YES": "YES DELETE",
	"SLOT_NO": "CANCEL",
	"SLOT_META": "%s  %d/8  %s",
	"SLOT_HINT": "UP/DOWN: PICK   DEL: ERASE   ESC: BACK",

	# ---- Save / System Notices ----
	"NOTICE_SAVE_BACKUP": "SAVE RECOVERED FROM BACKUP.",

	# ---- Pause Menu ----
	"PAUSE_TITLE": "PAUSED",
	"PAUSE_RESUME": "RESUME",
	"PAUSE_MAP": "MAP",
	"PAUSE_OPTIONS": "OPTIONS",
	"PAUSE_RETRY": "RETRY CHECKPOINT",
	"PAUSE_TITLE_BTN": "TITLE SCREEN",
	"PAUSE_HINT": "ENTER: SELECT   ESC: RESUME",

	# ---- Map & Fast Travel ----
	"MAP_TITLE": "ARCHIPELAGO MAP",
	"MAP_ISLAND_FMT": "ISLAND %d: %s",
	"MAP_UNEXPLORED": "UNCHARTED DARK",
	"MAP_WAYSTONES": "LIT WAYSTONES",
	"MAP_BEACONS": "BEACONS: %d/3",
	"MAP_DUNGEON": "DUNGEON: %s",
	"MAP_DUNGEON_SEALED": "DUNGEON: SEALED",
	"MAP_DUNGEON_CLEAR": "DUNGEON: RELIT",
	"MAP_EMBERS": "EMBERS: %d",
	"MAP_SECRETS": "SECRETS: %d",
	"MAP_TRAVEL_PROMPT": "ENTER: FAST TRAVEL",
	"MAP_NO_WAYSTONES": "NO LIT WAYSTONES YET",
	"MAP_CURRENT": "HERE",
	"MAP_LOCKED": "SEALED",
	"MAP_HINT": "LEFT/RIGHT: ISLAND  UP/DOWN: WARP  ESC: BACK",

	# ---- Options & Rebind (NO AIM ASSIST EVER) ----
	"OPT_TITLE": "OPTIONS",
	"OPT_TAB_AUDIO": "AUDIO",
	"OPT_TAB_DISPLAY": "DISPLAY",
	"OPT_TAB_CONTROLS": "CONTROLS",
	"OPT_TAB_ASSIST": "ASSIST",
	"OPT_BACK": "BACK",
	"OPT_HINT": "LEFT/RIGHT: ADJUST   TAB: SECTION   ESC: BACK",
	"OPT_ON": "ON",
	"OPT_OFF": "OFF",
	"OPT_MASTER": "MASTER VOLUME",
	"OPT_MUSIC": "MUSIC VOLUME",
	"OPT_SFX": "SFX VOLUME",
	"OPT_AMBIENCE": "AMBIENCE VOLUME",
	"OPT_MUTE_UNFOCUS": "MUTE ON UNFOCUS",
	"OPT_FULLSCREEN": "FULLSCREEN",
	"OPT_WIN_SCALE": "WINDOW SCALE",
	"OPT_SCALE_FMT": "%dx",
	"OPT_SHAKE": "SCREEN SHAKE",
	"OPT_FLASH_RED": "FLASH REDUCTION",
	"OPT_CURSOR_SIZE": "CURSOR SIZE",
	"OPT_CURSOR_SMALL": "SMALL",
	"OPT_CURSOR_MED": "MEDIUM",
	"OPT_CURSOR_LARGE": "LARGE",
	"OPT_CURSOR_COLOR": "CURSOR COLOUR",
	"OPT_COL_GOLD": "GOLD",
	"OPT_COL_CREAM": "CREAM",
	"OPT_COL_ICE": "ICE",
	"OPT_COL_LIME": "LIME",
	"OPT_COL_CORAL": "CORAL",
	"OPT_COL_ROSE": "ROSE",
	"OPT_COL_SKY": "SKY",
	"OPT_COL_APRICOT": "APRICOT",
	"OPT_REBIND_OPEN": "REBIND INPUTS",
	"OPT_HOLD_FIRE": "LIGHT BOLT INPUT",
	"OPT_HOLD_BEAM": "BEAM INPUT",
	"OPT_HOLD_WINGS": "WINGS INPUT",
	"OPT_MODE_HOLD": "HOLD",
	"OPT_MODE_TOGGLE": "TOGGLE",
	"OPT_RESET_DEFAULTS": "RESET DEFAULTS",
	"OPT_ASSIST_NOTE": "MANUAL AIM ONLY - NO AIM HELP",
	"OPT_ASSIST_DMG": "DAMAGE TAKEN",
	"OPT_ASSIST_TELLS": "ENEMY TELLS",
	"OPT_ASSIST_SPEED": "GAME SPEED",
	"OPT_DMG_1": "x1",
	"OPT_DMG_HALF": "x0.5",
	"OPT_DMG_ZERO": "x0",
	"OPT_TELL_1": "1x",
	"OPT_TELL_15": "1.5x",

	# ---- Rebind Screen ----
	"REBIND_TITLE": "REBIND CONTROLS",
	"REBIND_DEVICE_KBM": "DEVICE: KEYBOARD + MOUSE",
	"REBIND_DEVICE_PAD": "DEVICE: GAMEPAD",
	"REBIND_LISTEN": "PRESS NEW INPUT... ESC: CANCEL",
	"REBIND_HINT": "ENTER: BIND   LEFT/RIGHT: DEVICE   ESC: BACK",
	"REBIND_RESET": "RESET ALL BINDINGS",
	"ACT_MOVE_UP": "MOVE UP",
	"ACT_MOVE_DOWN": "MOVE DOWN",
	"ACT_MOVE_LEFT": "MOVE LEFT",
	"ACT_MOVE_RIGHT": "MOVE RIGHT",
	"ACT_FIRE": "BOLT / ZIP",
	"ACT_THROW": "THROW / RECALL",
	"ACT_DASH": "FLARE DASH / WINGS",
	"ACT_BEAM": "LANTERN BEAM",
	"ACT_SUNFLARE": "SUNFLARE",
	"ACT_INTERACT": "INTERACT",
	"ACT_PAUSE": "PAUSE",
	"ACT_MAP": "MAP",

	# ---- Lamplighter's Rest Shop (matches luxel/data/upgrades.json) ----
	"SHOP_TITLE": "LAMPLIGHTERS REST",
	"SHOP_SUBTITLE": "OFFER LIGHT SHARDS TO THE FLAME",
	"SHOP_SHARDS_FMT": "SHARDS: %d",
	"SHOP_COST_FMT": "%d SHARDS",
	"SHOP_MAXED": "MAXED",
	"SHOP_BUY_HINT": "ENTER: OFFER   ESC: LEAVE",
	"SHOP_BOUGHT": "THE FLAME GROWS STRONGER.",
	"SHOP_NO_SHARDS": "NOT ENOUGH SHARDS.",
	"SHOP_CLOSE": "LEAVE SHRINE",
	"UPG_BOLT_DMG_NAME": "BRIGHTER WICK",
	"UPG_BOLT_DMG_DESC": "LIGHT BOLTS HIT HARDER.",
	"UPG_BOLT_RATE_NAME": "QUICK SPARK",
	"UPG_BOLT_RATE_DESC": "LIGHT BOLTS FIRE FASTER.",
	"UPG_THROW_DMG_NAME": "HEAVY BRASS",
	"UPG_THROW_DMG_DESC": "THROWN LANTERN HITS HARDER.",
	"UPG_DASH_CD_NAME": "FLEET FLARE",
	"UPG_DASH_CD_DESC": "SHORTER FLARE DASH COOLDOWN.",
	"UPG_EMBER_NAME": "DEEP HEARTH",
	"UPG_EMBER_DESC": "EMBER METER FILLS FASTER.",
	"UPG_PRISM_NAME": "TWIN PRISM",
	"UPG_PRISM_DESC": "PRISM BOLTS BOUNCE TWICE.",

	# ---- Moves (matches luxel/data/moves.json) ----
	"MOVE_BOLT_NAME": "LIGHT BOLT",
	"MOVE_DASH_NAME": "FLARE DASH",
	"MOVE_THROW_NAME": "LANTERN THROW",
	"MOVE_PRISM_NAME": "PRISM",
	"MOVE_BEAM_NAME": "LANTERN BEAM",
	"MOVE_WINGS_NAME": "MOTH WINGS",
	"MOVE_LENS_NAME": "TRUE LENS",
	"MOVE_SUNFLARE_NAME": "SUNFLARE",

	# ---- HUD Labels ----
	"HUD_SHARDS_FMT": "%d",
	"HUD_EMBER": "EMBER",
	"HUD_EMBER_READY": "SUNFLARE READY!",
	"HUD_KEYS_FMT": "KEY x%d",
	"HUD_BOSS_P2": "PHASE 2",
	"HUD_BOSS_P3": "PHASE 3",
	"HUD_BOSS_P4": "PHASE 4",
	"HUD_LAST_HEART": "LAST HEART!",
	"HUD_ZIP_CUE": "%s: ZIP!",
	"HUD_KEY_PROMPT_FMT": "%s: %s",
	"HUD_MAP_HINT": "%s: MAP",

	# ---- Death / Boss Retry / Results / Credits ----
	"DEATH_TITLE": "WICK FELL",
	"DEATH_SUB": "RETURNING TO THE LAST WAYSTONE.",
	"DEATH_BOSS_SUB": "THE BOSS DOOR AWAITS.",
	"DEATH_RETRY_HINT": "PRESS ANY KEY TO RETRY",
	"DEATH_TITLE_HINT": "ESC: TITLE SCREEN",
	"DEATH_STATS_FMT": "TIME %s   DEATHS %d   SHARDS %d",
	"RESULTS_TITLE": "DAWN RETURNS",
	"RESULTS_RANK_FMT": "RANK: %s",
	"RANK_S": "S",
	"RANK_A": "A",
	"RANK_B": "B",
	"RANK_C": "C",
	"RESULTS_TIME_FMT": "TIME: %s",
	"RESULTS_DEATHS_FMT": "DEATHS: %d",
	"RESULTS_EMBERS_FMT": "EMBERS: %d",
	"RESULTS_ISLANDS_FMT": "LAMPS RELIT: %d/8",
	"RESULTS_HINT": "ENTER: CREDITS   ESC: TITLE",
	"CREDITS_TITLE": "LUXEL",
	"CREDITS_END": "SEE YOU AT SUNSET.",
	"CREDITS_SKIP": "ESC: SKIP",
	"CREDITS_DEFAULT_1": "BUILT IN GODOT 4.7",
	"CREDITS_DEFAULT_2": "ORIGINAL LANTERN GOTHIC FOLEY",
	"CREDITS_DEFAULT_3": "MUSIC: LANTERN GOTHIC",

	# ---- Story Intro ----
	"INTRO_1": "AT SUNSET THE LAST BELL RANG.",
	"INTRO_2": "EVERY LAMP ON EVERY ISLAND WENT OUT.",
	"INTRO_3": "ONE LANTERN WAS STILL LIT.",
	"INTRO_SKIP": "ANY KEY: SKIP",

	# ---- All 8 Islands: Arrival, Relight, Bridge (matches luxel/data/islands.json) ----
	"ISL1_ARRIVAL": "BELL ISLE SLEEPS UNDER A STOLEN DUSK.",
	"ISL1_RELIGHT": "THE GREAT BELL RINGS FOR DAWN.",
	"ISL1_BRIDGE": "A BRIDGE OF LIGHT OPENS TO THE HARBOR.",
	"ISL2_ARRIVAL": "TIDEWATER HARBOR STANDS DARK AT LOW TIDE.",
	"ISL2_RELIGHT": "THE HARBOR REMEMBERS THE LIGHT.",
	"ISL2_BRIDGE": "THE SEA PATH GLOWS TOWARD THORNWOOD.",
	"ISL3_ARRIVAL": "THORNWOOD HOLLOW TANGLES IN DEEP SHADE.",
	"ISL3_RELIGHT": "THE HOLLOW OAK BURNS CLEAR AGAIN.",
	"ISL3_BRIDGE": "A GOLDEN BRIDGE SPANS TO MIREFEN.",
	"ISL4_ARRIVAL": "MIREFEN GARDENS DRIFT IN COLD MIST.",
	"ISL4_RELIGHT": "THE CONSERVATORY GLASS SHINES WARM.",
	"ISL4_BRIDGE": "THE LIGHT CLIMBS TOWARD STARFALL RIM.",
	"ISL5_ARRIVAL": "STARFALL OBSERVATORY TURNS IN SILENCE.",
	"ISL5_RELIGHT": "THE ORRERY CATCHES THE SUN AGAIN.",
	"ISL5_BRIDGE": "THE PATH BURNS EAST TO ASHEN KILN.",
	"ISL6_ARRIVAL": "ASHEN KILN COOLS TO GREY CINDER.",
	"ISL6_RELIGHT": "THE GREAT KILN ROARS WITH GOLD.",
	"ISL6_BRIDGE": "A PALE BRIDGE REACHES MOON SHOALS.",
	"ISL7_ARRIVAL": "MOON SHOALS MIRRORS EVERY STEP.",
	"ISL7_RELIGHT": "THE MIRROR SPIRE STANDS UNMASKED.",
	"ISL7_BRIDGE": "THE FINAL BRIDGE LEADS TO THE LONG NIGHT.",
	"ISL8_ARRIVAL": "THE LONG NIGHT RISES OVER EVERY ISLAND.",
	"ISL8_RELIGHT": "THE HUSH BREAKS. THE SKY OPENS.",
	"ISL8_BRIDGE": "EVERY LAMP ON EVERY ISLAND ANSWERS.",

	# ---- Island 1 Act I + Belfry Chapters, Zones & Prompts ----
	"CH2_TITLE": "THE LANTERN ORCHARD",
	"CH3_TITLE": "THE OBSERVATORY RIM",
	"CH4_TITLE": "THE GLASSHOUSE",
	"CH5_TITLE": "THE BELFRY",
	"CH6_TITLE": "THE LAST BELL",
	"ZONE_PLAZA": "SUNDIAL PLAZA",
	"ZONE_ORCHARD": "LANTERN ORCHARD",
	"ZONE_OBSERVATORY": "OBSERVATORY RIM",
	"ZONE_GLASSHOUSE": "GLASSHOUSE",
	"ZONE_BRIDGE": "MOONLIT BRIDGE",
	"ZONE_BELFRY": "THE BELFRY",
	"ZONE_BELL_TOWER": "BELL TOWER",
	"PROMPT_AIM_SHOOT": "AIM AND HOLD %s TO FIRE LIGHT BOLTS.",
	"PROMPT_DASH": "PRESS %s TO FLARE DASH.",
	"PROMPT_THROW": "PRESS %s TO THROW OR RECALL LANTERN.",
	"PROMPT_ZIP": "PRESS %s WHILE OUT TO ZIP TO LANTERN.",
	"PROMPT_PRISM": "PRISM: SHOOT MIRRORS TO BANK BOLTS.",
	"PROMPT_BEAM": "HOLD %s TO CHARGE A PIERCING BEAM.",
	"PROMPT_WINGS": "HOLD %s AFTER DASH TO GLIDE OVER GAPS.",
	"PROMPT_LENS": "LENS: LANTERN LIGHT REVEALS HIDDEN PATHS.",
	"PROMPT_SUNFLARE": "PRESS %s AT FULL EMBER FOR SUNFLARE.",
	"PROMPT_IGNITE": "PRESS %s TO IGNITE.",
	"PROMPT_BOSS_DOOR": "THREE BEACONS BREAK THE BELL ARCH.",
	"PROMPT_CLAIM_SHRINE": "CLAIM SHRINE",
	"PROMPT_LIGHT_BEACON": "LIGHT BEACON",
	"PROMPT_WAYSTONE_LIGHT": "LIGHT WAYSTONE",
	"PROMPT_WAYSTONE_REST": "REST AT WAYSTONE",
	"PROMPT_REST_SHRINE": "REST AND UPGRADE",
	"PROMPT_OPEN_CHEST": "OPEN CHEST",
	"PROMPT_TAKE_KEY": "TAKE KEY",
	"PROMPT_UNLOCK_WICK_KEY": "UNLOCK DOOR",
	"PROMPT_UNLOCK_BOSS_KEY": "UNLOCK BOSS DOOR",
	"PROMPT_TURN_MIRROR": "TURN MIRROR",
	"PROMPT_RELIGHT_GREAT_LAMP": "RELIGHT GREAT LAMP",

	# ---- Enemy & World Cues ----
	"CUE_EATS_BOLTS": "EATS BOLTS!",
	"CUE_BLOCKED": "BLOCKED!",
	"CUE_OPEN": "OPEN!",
	"CUE_PERFECT_DODGE": "PERFECT!",
	"CUE_BELL_ARCH_OPEN": "BELL ARCH OPEN!",
	"CUE_BEACON_LIT": "BEACON LIT!",
	"CUE_WAYSTONE_LIT": "WAYSTONE LIT!",
	"CUE_SHRINE_CLAIMED": "NEW MOVE!",
	"CUE_SEAL_SHATTER": "SEAL SHATTERED!",
	"CUE_KEY_FOUND": "WICK KEY FOUND!",
	"CUE_DOOR_OPEN": "DOOR UNLOCKED!",
	"CUE_EMBER_FOUND": "EMBER PIECE FOUND!",
	"CUE_HEART_GAINED": "NEW HEART!",
	"CUE_LANTERN_STOLEN": "LANTERN STOLEN!",
	"CUE_PHASE_2": "THE DARK SURGES!",
	"CUE_HUSH_P3": "THE LONG NIGHT CLOSES IN!",
	"CUE_HUSH_P4": "THE LAST VEIL FALLS!",

	# ---- Boss Names (Islands 1-8) ----
	"BOSS_BELLKEEPER": "GRAND BELLKEEPER",
	"BOSS_HERMIT": "LIGHTHOUSE HERMIT",
	"BOSS_MATRON": "BRIAR MATRON",
	"BOSS_ABBESS": "HERON ABBESS",
	"BOSS_ASTRONOMER": "THE ASTRONOMER",
	"BOSS_KILNMOTHER": "THE KILNMOTHER",
	"BOSS_HOLLOW": "HOLLOW WICK",
	"BOSS_HUSH": "THE HUSH",

	# ---- Dungeons (Islands 2-8) ----
	"DUNGEON_2_NAME": "THE LIGHTHOUSE",
	"DUNGEON_3_NAME": "THE HOLLOW OAK",
	"DUNGEON_4_NAME": "DROWNED CONSERVATORY",
	"DUNGEON_5_NAME": "THE ORRERY",
	"DUNGEON_6_NAME": "THE GREAT KILN",
	"DUNGEON_7_NAME": "THE MIRROR SPIRE",
	"DUNGEON_8_NAME": "BELL SANCTUM",

	# ---- Zones (Islands 2-8) ----
	"ZONE_ISL2_1": "HARBOR QUAY",
	"ZONE_ISL2_2": "TIDE BOARDWALK",
	"ZONE_ISL2_3": "BARNACLE PIER",
	"ZONE_ISL2_4": "BOATHOUSE COVE",
	"ZONE_ISL2_5": "SEA WALL",
	"ZONE_ISL2_6": "LIGHTHOUSE HEAD",
	"ZONE_ISL3_1": "THORNWOOD GATE",
	"ZONE_ISL3_2": "BRAMBLE WALK",
	"ZONE_ISL3_3": "SPORE GLADE",
	"ZONE_ISL3_4": "ROOT ARCH",
	"ZONE_ISL3_5": "GLOAM HOLLOW",
	"ZONE_ISL3_6": "OAK SANCTUARY",
	"ZONE_ISL4_1": "MIREFEN LANDING",
	"ZONE_ISL4_2": "LILY SHALLOWS",
	"ZONE_ISL4_3": "SUNKEN GLASSHOUSE",
	"ZONE_ISL4_4": "HERON REEDS",
	"ZONE_ISL4_5": "SHATTERED TERRACE",
	"ZONE_ISL4_6": "CONSERVATORY STEPS",
	"ZONE_ISL5_1": "STARFALL LANDING",
	"ZONE_ISL5_2": "WEST DOME",
	"ZONE_ISL5_3": "CLOCKWORK BRIDGE",
	"ZONE_ISL5_4": "COLD RIM",
	"ZONE_ISL5_5": "ECHO GALLERY",
	"ZONE_ISL5_6": "ORRERY APPROACH",
	"ZONE_ISL6_1": "CINDER LANDING",
	"ZONE_ISL6_2": "ASH DRIFTS",
	"ZONE_ISL6_3": "BELLOWS YARD",
	"ZONE_ISL6_4": "SLAG CAUSEWAY",
	"ZONE_ISL6_5": "EMBER FOUNDRY",
	"ZONE_ISL6_6": "KILN GATE",
	"ZONE_ISL7_1": "MOONLIT SHOAL",
	"ZONE_ISL7_2": "MIRROR POOL",
	"ZONE_ISL7_3": "GLASS CAUSEWAY",
	"ZONE_ISL7_4": "PALE PROMENADE",
	"ZONE_ISL7_5": "SHADE GALLERY",
	"ZONE_ISL7_6": "SPIRE THRESHOLD",
	"ZONE_ISL8_1": "THE LONG NIGHT",
	"ZONE_ISL8_2": "DROWNED HARBOR ECHO",
	"ZONE_ISL8_3": "SHADED THORNWOOD ECHO",
	"ZONE_ISL8_4": "FALLEN STARFALL ECHO",

	# ---- Island 7 Twist ----
	"TWIST_HOLLOW": "THE DARK LEARNED TO CARRY A LANTERN.",

	# ---- True Ending (display_off, D6) ----
	"END_ASK_TITLE": "THE LANTERN ASKS",
	"END_ASK_SELL": "SELL LOOK - SOUND - PIXELS",
	"END_DISPLAY_OFF": "DISPLAY: OFF",
	"END_DARK_ATE": "THE DARK ATE THE LAST LIGHT.",
	"END_KEPT_ALL": "THE LANTERN KEPT EVERYTHING YOU SOLD.",
	"END_TOO_MUCH": "IT WAS TOO MUCH LIGHT FOR THE DARK.",
	"END_DISPLAY_ON": "DISPLAY: ON",

	# ---- Dawn Ending (dawn) ----
	"END_DAWN_TITLE": "DAWN RETURNS OVER THE ARCHIPELAGO.",
	"END_DAWN_SUB": "EVERY GREAT LAMP BURNS AGAIN.",
}


static func text(id: String) -> String:
	if TABLE.has(id):
		return str(TABLE[id])
	push_warning("LxStrings: missing id " + id)
	return id


static func fmt(id: String, args: Array) -> String:
	var tmpl: String = text(id)
	return _apply_fmt(tmpl, args)


static func has_id(id: String) -> bool:
	return TABLE.has(id)


static func all_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in TABLE.keys():
		out.append(str(k))
	return out


static func format_time(seconds: float) -> String:
	var total: int = maxi(0, floori(seconds))
	var mins: int = total / 60
	var secs: int = total % 60
	var min_str: String = str(mins)
	var sec_str: String = ("0" + str(secs)) if secs < 10 else str(secs)
	return fmt("FMT_CLOCK", [min_str, sec_str])


static func sanitize(raw: String, max_chars: int = MAX_LEN) -> String:
	var upper: String = raw.to_upper()
	var out: String = ""
	for i: int in range(upper.length()):
		var ch: String = upper[i]
		if ALLOWED.find(ch) >= 0:
			out += ch
		elif ch == "_" or ch == "," or ch == ";" or ch == "(" or ch == ")":
			out += " "
		elif ch == "?":
			out += "!"
		elif ch == "—":
			out += "-"
	out = out.strip_edges()
	while out.find("  ") >= 0:
		out = out.replace("  ", " ")
	if max_chars > 0 and out.length() > max_chars:
		out = out.substr(0, max_chars).strip_edges()
	return out


## Validates every entry in TABLE against ALLOWED and MAX_LEN.
## Entries containing %d or %s are expanded with both 0 and 999.
static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for key: Variant in TABLE.keys():
		var id: String = str(key)
		var val: Variant = TABLE[key]
		if not (val is String):
			errors.append(id + ": NOT A STRING")
			continue
		var raw: String = val as String
		var placeholders: Array[String] = _find_placeholders(raw)
		if placeholders.is_empty():
			_check_line(id, raw, errors)
		else:
			var low_args: Array = []
			var high_args: Array = []
			for kind: String in placeholders:
				if kind == "d":
					low_args.append(0)
					high_args.append(999)
				else:
					low_args.append("0")
					high_args.append("999")
			_check_line(id + "(0)", _apply_fmt(raw, low_args), errors)
			_check_line(id + "(999)", _apply_fmt(raw, high_args), errors)
	return errors


static func _apply_fmt(tmpl: String, args: Array) -> String:
	var out: String = ""
	var arg_idx: int = 0
	var i: int = 0
	var n: int = tmpl.length()
	while i < n:
		if tmpl[i] == "%" and i + 1 < n:
			var nxt: String = tmpl[i + 1]
			if nxt == "d":
				out += str(int(args[arg_idx])) if arg_idx < args.size() else "0"
				arg_idx += 1
				i += 2
				continue
			if nxt == "s":
				out += str(args[arg_idx]) if arg_idx < args.size() else ""
				arg_idx += 1
				i += 2
				continue
		out += tmpl[i]
		i += 1
	return out


static func _find_placeholders(tmpl: String) -> Array[String]:
	var kinds: Array[String] = []
	var i: int = 0
	var n: int = tmpl.length()
	while i < n:
		if tmpl[i] == "%" and i + 1 < n:
			var nxt: String = tmpl[i + 1]
			if nxt == "d" or nxt == "s":
				kinds.append(nxt)
				i += 2
				continue
		i += 1
	return kinds


static func _check_line(tag: String, line: String, errors: PackedStringArray) -> void:
	if line.length() > MAX_LEN:
		errors.append("%s: LEN %d > %d (%s)" % [tag, line.length(), MAX_LEN, line])
	for i: int in range(line.length()):
		var ch: String = line[i]
		if ALLOWED.find(ch) < 0:
			errors.append("%s: BAD CHAR '%s' IN %s" % [tag, ch, line])
			return
