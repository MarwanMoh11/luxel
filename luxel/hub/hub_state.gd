class_name LxHubState
extends RefCounted
## Persistent state helpers for Wick House Hub: minigame scores/medals/rewards,
## boss rematch records, lead forge purchases, flame colours, daily seed, and growth vars.

const MEDAL_NONE: int = 0
const MEDAL_BRONZE: int = 1
const MEDAL_SILVER: int = 2
const MEDAL_GOLD: int = 3

const LEAD_PRICES: Array[int] = [60, 100, 150, 220]

const FLAME_CATALOG: Array[Dictionary] = [
	{"id": "gold", "name_key": "HUB_FLAME_GOLD", "price": 0, "default_owned": true, "rim": "apricot", "core": "cream"},
	{"id": "cream", "name_key": "HUB_FLAME_CREAM", "price": 45, "default_owned": false, "rim": "gold", "core": "cream"},
	{"id": "apricot", "name_key": "HUB_FLAME_APRICOT", "price": 55, "default_owned": false, "rim": "coral", "core": "gold"},
	{"id": "coral", "name_key": "HUB_FLAME_CORAL", "price": 75, "default_owned": false, "rim": "wine", "core": "apricot"},
	{"id": "rose", "name_key": "HUB_FLAME_ROSE", "price": 85, "default_owned": false, "rim": "plum", "core": "cream"},
	{"id": "lime", "name_key": "HUB_FLAME_LIME", "price": 90, "default_owned": false, "rim": "jade", "core": "cream"},
	{"id": "sky", "name_key": "HUB_FLAME_SKY", "price": 95, "default_owned": false, "rim": "blue", "core": "ice"},
	{"id": "ice", "name_key": "HUB_FLAME_ICE", "price": 120, "default_owned": false, "rim": "sky", "core": "cream"},
]

const MINIGAME_IDS: PackedStringArray = [
	"shooting_gallery", "skiff_race", "lantern_juggle",
	"dash_corridor", "bell_choir", "endless_cellar",
]

const MINIGAME_REWARDS: Dictionary = {
	"shooting_gallery": {
		1: {"kind": "shards", "amount": 40},
		2: {"kind": "lead", "amount": 1, "fallback_shards": 65},
		3: {"kind": "pane", "value": "vesper_chime", "bonus_flame": "apricot", "fallback_shards": 90},
	},
	"skiff_race": {
		1: {"kind": "shards", "amount": 40},
		2: {"kind": "flame", "value": "sky", "fallback_shards": 60},
		3: {"kind": "pane", "value": "sea_glass", "bonus_moth": "hub_skiff", "fallback_shards": 90},
	},
	"lantern_juggle": {
		1: {"kind": "shards", "amount": 35},
		2: {"kind": "moth", "value": "hub_juggle", "fallback_shards": 60},
		3: {"kind": "lead", "amount": 1, "bonus_flame": "cream", "fallback_shards": 85},
	},
	"dash_corridor": {
		1: {"kind": "shards", "amount": 35},
		2: {"kind": "flame", "value": "rose", "fallback_shards": 60},
		3: {"kind": "pane", "value": "glass_step", "bonus_lead": 1, "fallback_shards": 90},
	},
	"bell_choir": {
		1: {"kind": "shards", "amount": 35},
		2: {"kind": "moth", "value": "hub_choir", "fallback_shards": 60},
		3: {"kind": "pane", "value": "bell_clapper", "bonus_flame": "lime", "fallback_shards": 90},
	},
	"endless_cellar": {
		1: {"kind": "shards", "amount": 45},
		2: {"kind": "lead", "amount": 1, "fallback_shards": 70},
		3: {"kind": "moth", "value": "hub_cellar", "bonus_ember": 1, "fallback_shards": 100},
	},
}

const FOLK_IDS: PackedStringArray = [
	"ferry_beetle", "bell_snail", "gardener_frog", "owl_chick",
	"kiln_salamander", "mirror_crab", "scribe_worm", "tailor_spider",
]


static func sync_hub_vars() -> void:
	if Lx.vars == null or Lx.state == null:
		return
	var relit_n: int = Lx.state.relit_islands.size()
	var folk_n: int = get_rescued_folk_count()
	var moth_n: int = LxQuests.current().get_moth_count()
	var medal_n: int = get_total_medals()
	Lx.vars.set_var("game", "hub_relit", relit_n)
	Lx.vars.set_var("game", "hub_folk", folk_n)
	Lx.vars.set_var("game", "hub_moths", moth_n)
	Lx.vars.set_var("game", "hub_medals", medal_n)


static func get_rescued_folk_count() -> int:
	if Lx.state == null:
		return 0
	var n: int = 0
	for fid: String in FOLK_IDS:
		if bool(Lx.state.story_flags.get("folk:" + fid, false)):
			n += 1
	return n


static func get_last_relit_island() -> int:
	if Lx.state == null or Lx.state.relit_islands.is_empty():
		return 0
	return int(Lx.state.relit_islands[Lx.state.relit_islands.size() - 1])


# ---- Minigames ----

static func get_minigame_best(mg_id: String, lower_is_better: bool = false) -> float:
	if Lx.state == null:
		return 0.0
	var key: String = "hub:mg:%s:best" % mg_id
	if not Lx.state.story_flags.has(key):
		return 0.0 if not lower_is_better else -1.0
	return float(Lx.state.story_flags.get(key, 0.0))


static func get_minigame_medal(mg_id: String) -> int:
	if Lx.state == null:
		return MEDAL_NONE
	return clampi(int(Lx.state.story_flags.get("hub:mg:%s:medal" % mg_id, 0)), 0, MEDAL_GOLD)


static func get_total_medals() -> int:
	var total: int = 0
	for mid: String in MINIGAME_IDS:
		total += get_minigame_medal(mid)
	return total


static func record_minigame_result(mg_id: String, value: float, medal: int, lower_is_better: bool = false) -> Dictionary:
	## Saves best score/time and grants any newly earned Bronze/Silver/Gold tier rewards.
	## Returns {new_best: bool, new_medal: bool, granted_tiers: Array[int], rewards: Array[String]}.
	var out: Dictionary = {"new_best": false, "new_medal": false, "granted_tiers": [], "rewards": []}
	if Lx.state == null or mg_id.is_empty():
		return out
	var bkey: String = "hub:mg:%s:best" % mg_id
	var has_prev: bool = Lx.state.story_flags.has(bkey)
	var prev: float = float(Lx.state.story_flags.get(bkey, 0.0))
	var improved: bool = not has_prev or (value < prev if lower_is_better else value > prev)
	if improved:
		Lx.state.story_flags[bkey] = snappedf(value, 0.01)
		out["new_best"] = true
	var mkey: String = "hub:mg:%s:medal" % mg_id
	var prev_m: int = clampi(int(Lx.state.story_flags.get(mkey, 0)), 0, MEDAL_GOLD)
	var clamped_m: int = clampi(medal, 0, MEDAL_GOLD)
	if clamped_m > prev_m:
		Lx.state.story_flags[mkey] = clamped_m
		out["new_medal"] = true
	var reward_tbl: Dictionary = MINIGAME_REWARDS.get(mg_id, {}) as Dictionary
	for tier: int in range(1, clamped_m + 1):
		var ckey: String = "hub:mg:%s:claimed_%d" % [mg_id, tier]
		if bool(Lx.state.story_flags.get(ckey, false)):
			continue
		Lx.state.story_flags[ckey] = true
		(out["granted_tiers"] as Array).append(tier)
		var rspec: Dictionary = reward_tbl.get(tier, {}) as Dictionary
		var rlabel: String = _grant_hub_reward(rspec)
		if not rlabel.is_empty():
			(out["rewards"] as Array).append(rlabel)
	sync_hub_vars()
	if Lx.events != null:
		Lx.events.save_requested.emit("hub_mg_" + mg_id)
	return out


static func _grant_hub_reward(rspec: Dictionary) -> String:
	if rspec.is_empty() or Lx.state == null:
		return ""
	var q: LxQuests = LxQuests.current()
	var kind: String = str(rspec.get("kind", ""))
	var val: String = str(rspec.get("value", ""))
	var amt: int = maxi(1, int(rspec.get("amount", 1)))
	var fb: int = int(rspec.get("fallback_shards", 50))
	var ok: bool = false
	match kind:
		"shards":
			Lx.state.add_shards(amt)
			ok = true
		"lead":
			ok = LxPanes.current().add_lead(amt)
			if not ok and fb > 0:
				Lx.state.add_shards(fb)
		"pane":
			ok = LxPanes.current().grant_pane(val)
			if not ok and fb > 0:
				Lx.state.add_shards(fb)
		"flame":
			ok = unlock_flame(val, false)
			if not ok and fb > 0:
				Lx.state.add_shards(fb)
		"moth":
			var mid: String = val if not val.is_empty() else "hub_bonus"
			ok = q.catch_moth(mid)
			if not ok and fb > 0:
				Lx.state.add_shards(fb)
		"ember_piece":
			for _i: int in range(amt):
				Lx.state.add_ember_piece()
			ok = true
	# Optional paired bonuses on Gold medals
	var b_flame: String = str(rspec.get("bonus_flame", ""))
	if not b_flame.is_empty():
		unlock_flame(b_flame, false)
	var b_moth: String = str(rspec.get("bonus_moth", ""))
	if not b_moth.is_empty():
		q.catch_moth(b_moth)
	var b_lead: int = int(rspec.get("bonus_lead", 0))
	if b_lead > 0 and not LxPanes.current().add_lead(b_lead):
		Lx.state.add_shards(45)
	var b_ember: int = int(rspec.get("bonus_ember", 0))
	if b_ember > 0:
		for _i: int in range(b_ember):
			Lx.state.add_ember_piece()
	return kind if ok else "shards"


# ---- Boss Rematch Records ----

static func boss_time_targets(boss_meta: Dictionary) -> Vector3:
	## Returns Vector3(gold_s, silver_s, bronze_s) speed targets for a boss rematch.
	var is_mini: bool = bool(boss_meta.get("mini", false))
	if is_mini:
		return Vector3(35.0, 55.0, 85.0)
	var phases: Array = boss_meta.get("phases", [0.5]) as Array
	if phases.size() >= 3:
		return Vector3(90.0, 135.0, 195.0)
	return Vector3(60.0, 95.0, 140.0)


static func get_rematch_record(boss_id: String) -> Dictionary:
	if Lx.state == null or boss_id.is_empty():
		return {"best_s": -1.0, "no_hit": false, "medal": 0, "wins": 0}
	var pref: String = "hub:rematch:%s:" % boss_id
	return {
		"best_s": float(Lx.state.story_flags.get(pref + "best", -1.0)),
		"no_hit": bool(Lx.state.story_flags.get(pref + "no_hit", false)),
		"medal": clampi(int(Lx.state.story_flags.get(pref + "medal", 0)), 0, MEDAL_GOLD),
		"wins": int(Lx.state.story_flags.get(pref + "wins", 0)),
	}


static func record_rematch_win(boss_id: String, elapsed_s: float, no_hit: bool, boss_meta: Dictionary) -> Dictionary:
	var out: Dictionary = {"new_best": false, "new_no_hit": false, "medal": 0, "reward_key": ""}
	if Lx.state == null or boss_id.is_empty():
		return out
	var pref: String = "hub:rematch:%s:" % boss_id
	var prev_best: float = float(Lx.state.story_flags.get(pref + "best", -1.0))
	var t_snap: float = snappedf(maxf(0.1, elapsed_s), 0.01)
	if prev_best < 0.0 or t_snap < prev_best:
		Lx.state.story_flags[pref + "best"] = t_snap
		out["new_best"] = true
	Lx.state.story_flags[pref + "wins"] = int(Lx.state.story_flags.get(pref + "wins", 0)) + 1
	var targets: Vector3 = boss_time_targets(boss_meta)
	var medal: int = MEDAL_GOLD if t_snap <= targets.x else (MEDAL_SILVER if t_snap <= targets.y else (MEDAL_BRONZE if t_snap <= targets.z else MEDAL_NONE))
	var prev_m: int = clampi(int(Lx.state.story_flags.get(pref + "medal", 0)), 0, MEDAL_GOLD)
	if medal > prev_m:
		Lx.state.story_flags[pref + "medal"] = medal
	out["medal"] = medal
	if no_hit and not bool(Lx.state.story_flags.get(pref + "no_hit", false)):
		Lx.state.story_flags[pref + "no_hit"] = true
		out["new_no_hit"] = true

	# Time / No-Hit rewards
	if medal >= MEDAL_BRONZE and not bool(Lx.state.story_flags.get(pref + "r_bronze", false)):
		Lx.state.story_flags[pref + "r_bronze"] = true
		Lx.state.add_shards(30)
		out["reward_key"] = "HUB_REMATCH_R_SHARDS"
	if medal >= MEDAL_GOLD and not bool(Lx.state.story_flags.get(pref + "r_gold", false)):
		Lx.state.story_flags[pref + "r_gold"] = true
		Lx.state.add_shards(60)
		out["reward_key"] = "HUB_REMATCH_R_GOLD"
	if no_hit and not bool(Lx.state.story_flags.get(pref + "r_nohit", false)):
		Lx.state.story_flags[pref + "r_nohit"] = true
		if not bool(Lx.state.story_flags.get("hub:rematch:first_nohit_ember", false)):
			Lx.state.story_flags["hub:rematch:first_nohit_ember"] = true
			Lx.state.add_ember_piece()
			out["reward_key"] = "HUB_REMATCH_R_NOHIT"
		else:
			Lx.state.add_shards(75)
			out["reward_key"] = "HUB_REMATCH_R_NOHIT"
	# Milestone: 3 Gold rematches -> +1 Lead
	if count_gold_rematches() >= 3 and not bool(Lx.state.story_flags.get("hub:rematch:lead3", false)):
		Lx.state.story_flags["hub:rematch:lead3"] = true
		if not LxPanes.current().add_lead(1):
			Lx.state.add_shards(80)
	if Lx.events != null:
		Lx.events.save_requested.emit("rematch_" + boss_id)
	return out


static func count_gold_rematches() -> int:
	if Lx.state == null or Lx.packs == null:
		return 0
	var n: int = 0
	for bid: String in Lx.packs.all_boss_ids():
		if int(Lx.state.story_flags.get("hub:rematch:%s:medal" % bid, 0)) >= MEDAL_GOLD:
			n += 1
	return n


# ---- Lead Smith Shop ----

static func get_lead_purchases() -> int:
	if Lx.state == null:
		return 0
	return clampi(int(Lx.state.story_flags.get("hub:lead_bought", 0)), 0, LEAD_PRICES.size())


static func get_next_lead_price() -> int:
	var idx: int = get_lead_purchases()
	if idx >= LEAD_PRICES.size() or LxPanes.current().get_max_lead() >= LxPanes.MAX_LEAD_CAP:
		return -1
	return LEAD_PRICES[idx]


static func buy_lead() -> bool:
	if Lx.state == null:
		return false
	var price: int = get_next_lead_price()
	if price < 0 or Lx.state.shards < price:
		return false
	if not LxPanes.current().add_lead(1):
		return false
	Lx.state.shards -= price
	Lx.state.story_flags["hub:lead_bought"] = get_lead_purchases() + 1
	if Lx.events != null:
		Lx.events.save_requested.emit("hub_buy_lead")
	return true


# ---- Flame Colour Tailor ----

static func get_equipped_flame() -> String:
	if Lx.state == null:
		return "gold"
	var c: String = str(Lx.state.story_flags.get("cosmetic:flame", "gold"))
	return c if LxPalette.is_valid_color(c) else "gold"


static func is_flame_owned(flame_id: String) -> bool:
	if flame_id == "gold":
		return true
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get("cosmetic:flame_" + flame_id, false))


static func unlock_flame(flame_id: String, auto_equip: bool = false) -> bool:
	if Lx.state == null or not LxPalette.is_valid_color(flame_id):
		return false
	var was_owned: bool = is_flame_owned(flame_id)
	Lx.state.story_flags["cosmetic:flame_" + flame_id] = true
	if auto_equip:
		Lx.state.story_flags["cosmetic:flame"] = flame_id
	return not was_owned


static func equip_flame(flame_id: String) -> bool:
	if Lx.state == null or not is_flame_owned(flame_id):
		return false
	Lx.state.story_flags["cosmetic:flame"] = flame_id
	if Lx.events != null:
		Lx.events.save_requested.emit("hub_flame_" + flame_id)
	return true


static func buy_flame(flame_id: String) -> bool:
	if Lx.state == null or is_flame_owned(flame_id):
		return false
	for entry: Dictionary in FLAME_CATALOG:
		if str(entry.get("id", "")) == flame_id:
			var cost: int = int(entry.get("price", 0))
			if cost <= 0 or Lx.state.shards < cost:
				return false
			Lx.state.shards -= cost
			unlock_flame(flame_id, true)
			if Lx.events != null:
				Lx.events.save_requested.emit("hub_buy_flame_" + flame_id)
			return true
	return false


static func get_flame_spec(flame_id: String) -> Dictionary:
	for entry: Dictionary in FLAME_CATALOG:
		if str(entry.get("id", "")) == flame_id:
			return entry
	return FLAME_CATALOG[0]


# ---- Daily Seed for Endless Cellar ----

static func get_daily_seed_info() -> Dictionary:
	var dt: Dictionary = Time.get_date_dict_from_system()
	var y: int = int(dt.get("year", 2026))
	var m: int = int(dt.get("month", 11))
	var d: int = int(dt.get("day", 25))
	var code: int = y * 10000 + m * 100 + d
	return {"code": code, "label": "%04d-%02d-%02d" % [y, m, d]}


static func get_daily_cellar_best() -> int:
	if Lx.state == null:
		return 0
	var info: Dictionary = get_daily_seed_info()
	return int(Lx.state.story_flags.get("hub:cellar:day_%d" % int(info["code"]), 0))


static func record_daily_cellar_wave(wave: int) -> bool:
	if Lx.state == null or wave <= 0:
		return false
	var info: Dictionary = get_daily_seed_info()
	var key: String = "hub:cellar:day_%d" % int(info["code"])
	var prev: int = int(Lx.state.story_flags.get(key, 0))
	if wave > prev:
		Lx.state.story_flags[key] = wave
		return true
	return false
