extends RefCounted
## Every player-facing story line by hook id (design 15; the text lives in docs/STORY.md). A "\n" splits a line
## pair (two narration or tip lines). Charset and widths are checked by check() (tests/flow_check).

const CHARSET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-:x/.+= %"
const MAX_CHARS := 45 ## per line at scale 1 (180 px: STORY.md 0)
const SCREEN_W := 320
const SETTINGS_TOTAL := 19 ## shop rows a run can sell before the finale (design 11)
const CHECK_COUNTS: Array[int] = [0, 999] ## check() fills a %d template with these (the narrowest and widest counts)

const TEXT := {
	# Title (STORY.md 2)
	"title.name": "LUXEL",
	"title.sub": "ALL SETTINGS: HIGH",
	"title.prompt": "CLICK OR PRESS ANY KEY",
	"title.gamer_off": "GAMER MODE: OFF",
	"title.gamer_on": "GAMER MODE: ON",
	"title.gamer_note": "MORE DARK. LESS MERCY. YOU CAN LOSE.",
	# Intro (STORY.md 3)
	"intro.skip": "ANY KEY: SKIP",
	"intro.1": "AT SUNSET THE DARK COMES TO EAT THE LIGHT.",
	"intro.2": "AND WICK THE LAMPLIGHTER LIGHTS IT AGAIN.",
	"intro.3": "TONIGHT THE DARK IS HUNGRIER.\nTHE LANTERN WILL TAKE ANYTHING THAT GLOWS.",
	"intro.4": "YOUR SCREEN GLOWS.",
	# Tutorial (STORY.md 4, design 12)
	"tut.move": "ARROWS OR WASD: MOVE",
	"tut.lantern": "THE LANTERN FIRES BY ITSELF.\nYOU JUST MOVE.",
	"tut.shard": "THAT SNUFFER WAS FULL OF STOLEN LIGHT.\nTHE LANTERN TAKES IT BACK.",
	"tut.menu_header": "THE LANTERN BUYS SETTINGS",
	"tut.menu_quip": "THERE WERE NO SUBTITLES. FREE POWER.",
	"tut.menu_quip_alt": "NOBODY HERE TALKS. FREE POWER.",
	"tut.menu_keys": "SPACE: SELL",
	"tut.go": "FILL IT. SELL A SETTING. GET STRONGER.\nNOW SURVIVE THE NIGHT.",
	# Menu headers (STORY.md 4)
	"menu.levelup": "LEVEL UP!",
	"menu.header": "SELL 1 SETTING. GET 1 POWER.",
	"menu.not_yet": "NOT FOR SALE YET.",
	"menu.try_tab": "TRY ANOTHER TAB.",
	# The menu footer and the tutorial menu's how-to: what a sale costs and pays, in plain words
	"menu.lose": "YOU LOSE:",
	"menu.get": "YOU GET:",
	"menu.new_form": "NEW LANTERN FORM:",
	"menu.new_mark": "NEW",
	"menu.skip": "SKIP: KEEP ALL SETTINGS",
	"menu.skip.lose": "NOTHING. EVERY SETTING STAYS.",
	"menu.skip.no_heal": "NOTHING. HEALING IS SOLD.",
	"menu.how.title": "HOW IT WORKS",
	"menu.how.1": "EVERY ROW IS A SETTING OF THIS GAME.",
	"menu.how.2": "SELL ONE AND IT GETS WORSE FOR GOOD.",
	"menu.how.3": "THE LANTERN PAYS YOU IN POWER.",
	# What each sale takes away (YOU LOSE:); lose.<id>_2 is a row's second step. Rows without one show their quip.
	"lose.subtitles": "NOTHING. THIS GAME HAS NO SUBTITLES.",
	"lose.tips": "NO MORE HINTS ON SCREEN.",
	"lose.shake": "HITS STOP SHAKING THE SCREEN.",
	"lose.timer": "THE RUN CLOCK DISAPPEARS.",
	"lose.gauge": "THE LANTERN FILL BAR DISAPPEARS.",
	"lose.hearts": "YOU CAN NO LONGER SEE YOUR HEARTS.",
	"lose.warnings": "NO ARROWS FOR ENEMIES OFF SCREEN.",
	"lose.language": "ALL TEXT IS SCRAMBLED FOR 2 MENUS.",
	"lose.difficulty": "ENEMIES MOVE 15% FASTER.",
	"lose.difficulty_2": "ENEMIES MOVE 30% FASTER.",
	"lose.mercy": "LESS SAFE TIME AFTER A HIT.",
	"lose.knockback": "HITS NO LONGER PUSH ENEMIES BACK.",
	"lose.healing": "NOTHING HEALS YOU ANY MORE.",
	"lose.movement": "WICK SLIDES AROUND LIKE ON ICE.",
	"lose.input_delay": "YOUR KEYS ANSWER 0.2 S LATE.",
	"lose.aim": "THE LANTERN AIMS AT RANDOM.",
	"lose.up_key": "YOUR UP KEY CUTS OUT NOW AND THEN.",
	"lose.ray_tracing": "NOTHING. IT WAS NEVER ON.",
	"lose.confirm": "THE GAME SELLS ITS PRETTY SETTINGS ITSELF.",
	# BUY BACK (design 9.4): menu text, so LANGUAGE scrambles it like the rest of the menu
	"menu.buy_back.header": "SELL ONE OR BUY ONE BACK ONCE",
	"menu.buy_back.tag": "BUY BACK",
	"menu.buy_back.lose": "THIS LEVEL UP. NO NEW POWER.",
	"menu.buy_back.get": "AGAIN. YOU KEEP THE POWER.",
	"menu.buy_back.key": "SPACE: BUY",
	"menu.buy_back.done": "BOUGHT BACK. POWER KEPT.",
	"menu.buy_back.kept": "BOUGHT BACK",
	# Lantern forms (STORY.md 4): the menu's NEW: tag after a row's reward, and the callout over Wick after the sale
	"form.new": "NEW:",
	"form.prism": "PRISM SHARDS",
	"form.needle": "STAR NEEDLE",
	"form.moon": "MOON TRAIL",
	"form.toll": "BELL TOLL",
	"form.flies": "FIREFLY",
	"form.wake": "RIVER WAKE",
	# Debut tips, then the general tips (design 15.3; tip.1-8 are P4 copy, not in STORY.md)
	"tip.owl": "OWLS DIVE WHERE YOU STOOD. STEP ASIDE.",
	"tip.magpie": "CATCH THE MAGPIE. IT STOLE A STAR.",
	"tip.toad": "THE PARASOL BLOCKS. HIT THE TOAD FROM BEHIND.",
	"tip.sporecap": "SPORES FLY IN RINGS. FIND THE GAP.",
	"tip.gloam": "GLOAMS HIDE OUTSIDE THE LIGHT.",
	"tip.formation": "SOMETHING IS COMING.",
	"tip.1": "FILL THE LANTERN. SELL A SETTING.",
	"tip.2": "TIP: THE DARK IS FULL OF STOLEN LIGHT.",
	"tip.3": "TIP: TIPS CAN BE SOLD TOO.",
	"tip.4": "THIS TIP INTENTIONALLY LEFT BLANK.",
	"tip.5": "TIP: WICK IS THE ONE WITH THE LANTERN.",
	"tip.6": "SNUFFERS CANNOT READ TIPS.",
	"tip.7": "TIP: KEEP MOVING. THE LANTERN AIMS.",
	"tip.8": "TIP: SELL WHAT YOU WILL NOT MISS.",
	# Finale (STORY.md 5, design 10)
	"finale.swell": "THE DARK IS COMING ALL AT ONCE.",
	"finale.need_power": "YOU NEED MORE POWER.",
	"finale.too_many": "THEY ARE TOO MANY.",
	"finale.one_blast": "SELL EVERYTHING. ONE BLAST KILLS THEM ALL.",
	"finale.nothing_left": "SELL IT ALL. ONE BLAST KILLS THEM ALL.",
	"finale.blast_tag": "NEW: BLAST",
	"finale.confirm_quip": "ALL THE PRETTY SETTINGS. ONE BIG BLAST.",
	"finale.blast_count": "BLAST",
	"finale.must_go": "EVERYTHING MUST GO",
	"finale.header": "THE LANTERN WANTS THE GOOD STUFF",
	"finale.open": "HOLD ON. THE BLAST IS CHARGING.",
	"finale.cleared": "THE DARK IS GONE. BUT THE SCREEN IS BROKEN.",
	"finale.relight": "THE LANTERN CAN FIX IT. MASH SPACE.",
	"finale.relight_key": "SPACE: FIX THE SCREEN",
	"finale.relit": "THERE IT IS.",
	"finale.spent": "THE LANTERN USED UP ITS LIGHT.",
	"finale.rest": "HERE COMES THE REST OF THE DARK.",
	"finale.alone": "THE LANTERN CANNOT DO THIS ALONE.",
	"finale.give_screen": "GIVE IT YOUR SCREEN.",
	"finale.last_heart": "LAST HEART",
	"finale.pixels": "ONE SETTING LEFT. IT IS THE SCREEN.",
	"finale.pixel_first": "1% AT A TIME.",
	"finale.stage1": "EVERY PIXEL IS MORE POWER.",
	"finale.stage2": "THE LANTERN IS FIGHTING BACK.",
	"finale.stage3": "GIVE IT EVERYTHING.",
	"finale.last_pixel": "LAST PIXEL.",
	# The PIXELS panel (design 10.4; plain English, LANGUAGE never scrambles it)
	"menu.pixels.auto": "AUTO-SELL",
	"menu.pixels.auto_note": "THE REST SELL THEMSELVES",
	"menu.pixels.auto_quip": "KEEP FIGHTING. THE SCREEN SELLS ITSELF.",
	"menu.pixels.sell_key": "SPACE: SELL 1%",
	"menu.pixels.auto_key": "SPACE: AUTO-SELL",
	"menu.pixels.auto_on": "AUTO-SELL ON.",
	# Sale quips STORY.md 5 sets (shop_data holds the live copy; STORY.md wins where they differ)
	"quip.music": "THE ORGANIST GOES HOME.",
	"quip.sound": "SILENCE. WAS THAT A HIT.",
	"quip.audio_quality": "A PHONE CALL FROM DOWN A WELL.",
	"quip.colour_4": "FOUR COLOURS. LIKE AN OLD HANDHELD.",
	"quip.colour_2": "BLACK AND WHITE. MOSTLY BLACK.",
	"quip.resolution_half": "EVERYTHING GETS CHUNKY.",
	"quip.resolution_quarter": "WHICH BLOB IS WICK.",
	"quip.brightness": "ALL THE LANTERNS GO OUT. BUT ONE.",
	"quip.animations": "EVERYONE FREEZES IN ONE POSE.",
	"quip.particles": "THE FIREFLIES GO HOME.",
	"quip.frame_rate": "A SLIDESHOW. WITH TEETH.",
	"quip.view_distance": "THE WORLD ENDS AT THE LANTERN.",
	"quip.shadows": "THE SUNDIAL LOSES TRACK OF TIME.",
	"quip.movement": "THE ISLAND IS A FROZEN POND NOW.",
	"quip.crosshair": "THERE WAS NO CROSSHAIR EITHER.",
	"quip.camera_smoothing": "THE CAMERA STOPS BEING POLITE.",
	"quip.credits": "NOBODY MADE THIS GAME. IT JUST HAPPENED.",
	# The lantern spill (player.gd: a guarded last-heart hit from GUARD_LEVEL; cards.gd counts them, %d = spills)
	"quip.lantern_spills": "THE LANTERN SPILLS.",
	"results.lantern_saves": "SAVED BY THE LANTERN x%d",
	# Ending (STORY.md 6; ending.gd owns the staging)
	"ending.skip": "PRESS AGAIN TO SKIP",
	"ending.display_off": "DISPLAY: OFF",
	"ending.one_light": "THEY CAN STILL SEE ONE LIGHT.",
	"ending.ate": "THE DARK ATE THE LAST LIGHT.",
	"ending.kept": "THE LANTERN KEPT EVERYTHING YOU SOLD.",
	"ending.too_much": "IT WAS TOO MUCH LIGHT FOR THE DARK.",
	"ending.display_on": "DISPLAY: ON",
	"ending.see_you": "SEE YOU AT SUNSET.",
	"ending.toast.1": "MUSIC: ON",
	"ending.toast.2": "VIEW DISTANCE: FULL",
	"ending.toast.3": "COLOURS: 4",
	"ending.toast.4": "COLOURS: 16",
	"ending.toast.5": "RESOLUTION: FULL",
	"ending.toast.6": "FRAME RATE: 60",
	"ending.toast.7": "SOUND: ON",
	"ending.toast.8": "ANIMATIONS: ON",
	"ending.toast.9": "BRIGHTNESS: 100%",
	"ending.toast.10": "PARTICLES: ON",
	"ending.toast.11": "TIMER: ON - HEARTS: SHOWN",
	"ending.toast.12": "MOVEMENT: SNAPPY - INPUT DELAY: 0 MS",
	"ending.toast.13": "UP KEY: ON",
	"ending.toast.14": "SUBTITLES: ON",
	"ending.toast.credits": "CREDITS: ON", # only if CREDITS becomes a spare early sale (STORY.md 7)
	"ending.credit.1": "A GAME BY MARWAN",
	"ending.credit.2": "MADE FOR JAM NAME\nTHEME: TRADE-OFF",
	"ending.credit.5": "MADE IN GODOT 4.7",
	"ending.credit.6": "MADE WITH CLAUDE",
	"ending.credit.7": "SOUND EFFECTS: KENNEY.NL - CC0",
	"ending.credit.8": "MUSIC: LANTERN GOTHIC",
	"ending.credit.10": "SOUNDFONT: MUSESCORE GENERAL\nFLUIDR3 - FLUIDR3MONO - S. CHRISTIAN COLLINS",
	"ending.credit.11": "PLAY-TESTED BY NAMES",
	"ending.credit.13": "THE UP KEY IS BACK. LOOK AFTER IT.",
	"ending.credit.14": "STILL NO SUBTITLES. SORRY.",
	# Results (STORY.md 7)
	"results.title": "NIGHT SURVIVED",
	"results.line": "SOLD EVERY SETTING. GOT THEM ALL BACK.",
	"results.keys": "SPACE OR R: PLAY AGAIN   ESC: TITLE",
	# Death card (STORY.md 7, design 11)
	"death.title": "WICK FELL",
	"death.keys": "SPACE OR R: AGAIN   ESC: TITLE",
	"death.default_1": "THE DARK SAYS THANKS FOR THE SNACK.",
	"death.default_2": "THE DARK ATE WELL TONIGHT.",
	"death.default_3": "ONE MORE SETTING MIGHT HAVE DONE IT.",
	"death.subtitles": "THE SUBTITLES WOULD NOT HAVE HELPED.",
	"death.tips": "TIP: AVOID THAT. TOO LATE.",
	"death.shake": "THE SCREEN DID NOT EVEN SHAKE.",
	"death.hit_flash": "NOTHING FLASHED. YOU NEVER KNEW.",
	"death.timer": "YOU LASTED A WHILE. PROBABLY.",
	"death.hearts": "YOU HAD 0 HEARTS. NOW YOU KNOW.",
	"death.movement": "WICK SLID RIGHT INTO IT.",
	"death.input_delay": "YOU DIED 200 MS AGO.",
	"death.aim": "THE LANTERN WAS AIMING AT A ROCK.",
	"death.up_key": "THE UP KEY WAS DOING ITS BEST.",
	"death.view_distance": "IT WAS RIGHT THERE. JUST OUT OF VIEW.",
	# Pause card (design 11)
	"pause.title": "PAUSED",
	"pause.keys": "SPACE: RESUME   R: RESTART   Q: TITLE",
}

## Lines drawn bigger than scale 1 (their width limit is the screen).
const SCALE := {"title.name": 3, "ending.display_off": 2, "ending.display_on": 2, "death.title": 2,
	"pause.title": 2, "finale.too_many": 2, "finale.alone": 2}

## Placeholders still to fill; flow_check lists them.
const TBD: Array[String] = ["ending.credit.2", "ending.credit.11"]

## Intro beats (STORY.md 3): narration id -> {t: start s, secs: on screen, colour}. The intro reads these.
const INTRO := {
	"intro.1": {"t": 0.8, "secs": 3.8, "colour": "cream"},
	"intro.2": {"t": 13.8, "secs": 3.6, "colour": "cream"},
	"intro.3": {"t": 17.6, "secs": 3.8, "colour": "cream"},
	"intro.4": {"t": 21.6, "secs": 2.4, "colour": "cream"},
}

## The ending's narration beats (STORY.md 6, t from the last pixel sold); bars come from credits().
const ENDING := [
	{"id": "ending.display_off", "t": 0.4, "secs": 3.0, "colour": "ice", "y": 40, "scale": 2},
	{"id": "ending.one_light", "t": 4.0, "secs": 2.6, "colour": "stone", "y": 150, "scale": 1},
	{"id": "ending.ate", "t": 9.5, "secs": 2.5, "colour": "mauve", "y": 150, "scale": 1},
	{"id": "ending.kept", "t": 20.0, "secs": 2.6, "colour": "cream", "y": 150, "scale": 1},
	{"id": "ending.too_much", "t": 22.8, "secs": 2.6, "colour": "cream", "y": 150, "scale": 1},
	{"id": "ending.display_on", "t": 23.3, "secs": 2.4, "colour": "gold", "y": 40, "scale": 2},
]


## The line for hook `id`, or `fallback`.
static func line(id: String, fallback := "") -> String:
	return TEXT.get(id, fallback)


## The line for `id` split into its lines ("\n").
static func lines(id: String) -> PackedStringArray:
	var s := line(id)
	return PackedStringArray() if s == "" else s.split("\n")


## A story card: {lines: PackedStringArray, shot: String, secs: float} (intro beats: shot "intro", plus t, colour).
static func card(id: String) -> Dictionary:
	var beat: Dictionary = INTRO.get(id, {})
	var out := {"lines": lines(id), "shot": "intro" if not beat.is_empty() else "", "secs": beat.get("secs", 0.0)}
	out.merge(beat)
	return out


## The ending storyboard beats in order: ENDING with each beat's lines filled in.
static func ending() -> Array:
	var out := []
	for beat: Dictionary in ENDING:
		var b := beat.duplicate()
		b["lines"] = lines(beat["id"])
		out.append(b)
	return out


## The buy-back bars 1-14 (STORY.md 6 part 4): [{bar, toast, credit: PackedStringArray}].
static func credits() -> Array:
	var out := []
	for bar in range(1, 15):
		out.append({"bar": bar, "toast": line("ending.toast.%d" % bar),
			"credit": lines("ending.credit.%d" % bar)})
	return out


## The death quip id for the last setting sold (design 11): death.<id> if it has one, else a random default.
static func death_quip_id(last_sale_id: String) -> String:
	if TEXT.has("death." + last_sale_id) and not last_sale_id.begins_with("default"):
		return "death." + last_sale_id
	return "death.default_%d" % randi_range(1, 3)


## The tag for lantern forms a sale lights ([[form, tier], ...] from light_fx.gd): "NEW: FIREFLY 2 + BELL TOLL";
## "" for none. `prefix` false leaves out NEW: (a tight menu row).
static func form_tag(gained: Array, prefix := true) -> String:
	if gained.is_empty():
		return ""
	var names := PackedStringArray()
	for g: Array in gained:
		var name := line("form." + str(g[0]), str(g[0]).to_upper())
		names.append(name if int(g[1]) <= 1 else "%s %d" % [name, int(g[1])])
	var tag := " + ".join(names)
	return line("form.new", "NEW:") + " " + tag if prefix else tag


## m:ss
static func clock(seconds: float) -> String:
	var s := maxi(floori(seconds), 0)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


## The best record for the title and cards (design 11), "" when there is none; GAMER MODE's says so.
static func best_line(best: Dictionary, gamer := false) -> String:
	if best.is_empty():
		return ""
	var head := "GAMER BEST: " if gamer else "BEST: "
	if best.get("done", false):
		return head + "DISPLAY OFF IN " + clock(best.get("time", 0.0))
	return head + "%d OF %d SOLD" % [int(best.get("sold", 0)), SETTINGS_TOTAL]


## Problems with the text: characters outside the 3x5 charset and lines too wide. Empty = all good. A %d template
## is checked as drawn, filled with each of CHECK_COUNTS.
static func check() -> PackedStringArray:
	var bad := PackedStringArray()
	for id: String in TEXT:
		var scale: int = SCALE.get(id, 1)
		for n in CHECK_COUNTS:
			var s: String = TEXT[id].replace("%d", str(n))
			for l in s.split("\n"):
				for c in l:
					if not CHARSET.contains(c) and not bad.has("%s: '%s' not in the charset" % [id, c]):
						bad.append("%s: '%s' not in the charset" % [id, c])
				var w := (l.length() * 4 - 1) * scale
				if (scale == 1 and l.length() > MAX_CHARS) or w > SCREEN_W - 4:
					bad.append("%s: %d chars at scale %d is too wide" % [id, l.length(), scale])
			if not TEXT[id].contains("%d"):
				break
	return bad
