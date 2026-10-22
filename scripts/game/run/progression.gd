extends RefCounted
## Level, light, the need curve (design 7.3), power multipliers, shots, pierce, hearts.
## Light comes from shards.gd; sale powers from run._apply_sale (design 9.1: damage, fire, speed and range compound,
## hearts, shots and pierce add).

# Level curve: need(1) = XP_BASE (the tutorial's six Snuffers), then XP_BASE + XP_LINEAR n + XP_SQUARE n^2 (n = L - 1):
# 6, 10, 14, 19, 23, 28, 32, 37 ... 96 at L 19. Fitted to design 5's menu table on run_check seeds 1-3 after the
# forms began to hit hard (2026-10-20; was 1.2 / 0.33, which brought the menus early once kills got faster).
const XP_BASE := 6.0
const XP_LINEAR := 4.1
const XP_SQUARE := 0.05
const GAMER_NEED := 1.25 # x the need from level 2 in GAMER MODE (its extra enemies would bring the menus early)
const EPS := 0.000001

# Base stats (design 6); damage is an int x10 so small % powers count.
const BASE_DAMAGE := 10
const BASE_FIRE := 0.34
const BASE_SPEED := 85.0
const BASE_ACCEL := 1000.0
const BASE_RANGE := 150.0
const BASE_LIFE := 0.8
const BASE_HP: int = preload("res://scripts/game/run/player.gd").BASE_HP # one base for reset, sales and previews

var run ## the Run (run.gd), duck-typed

var level := 1
var light := 0.0 ## light toward the next level
var need := XP_BASE ## light the current level needs
var mult := {"damage": 1.0, "fire": 1.0, "speed": 1.0, "range": 1.0} ## compounded: x (1 + v) per sale
var shots := 1 ## shots per volley
var pierce := 0
var hearts := 0 ## extra hearts from sales
var pending := 0 ## gauge fills not yet turned into menus (take_level_up)
var total_light := 0.0 ## every bit of light landed this run (stats.light)
var clock_fill := -1.0 ## closing: the run's clock fill shown by fill(); -1 = off


## Keeps the back-reference to the run.
func setup(r) -> void:
	run = r


## Back to level 1 with no powers.
func reset() -> void:
	level = 1
	light = 0.0
	need = need_for(1)
	mult = {"damage": 1.0, "fire": 1.0, "speed": 1.0, "range": 1.0}
	shots = 1
	pierce = 0
	hearts = 0
	pending = 0
	total_light = 0.0
	clock_fill = -1.0


## Light needed to leave `lvl` (design 7.3).
func need_for(lvl: int) -> float:
	var n := float(maxi(lvl, 1) - 1)
	var v := XP_BASE + XP_LINEAR * n + XP_SQUARE * n * n
	return roundf(v * (GAMER_NEED if lvl > 1 and run != null and run.gamer else 1.0))


## Adds light; returns the level-ups gained (overflow carries over; each one also adds to `pending`).
func add_light(v: float) -> int:
	if v <= 0.0:
		return 0
	total_light += v
	light += v
	var ups := 0
	while light >= need - EPS:
		light = maxf(light - need, 0.0)
		level += 1
		ups += 1
		need = need_for(level)
	pending += ups
	return ups


## The lantern spills: empties the gauge and returns its light. Taken off total_light too, so picking the shards
## back up (add_light) never counts it twice.
func spill() -> float:
	var v := light
	light = 0.0
	total_light = maxf(total_light - v, 0.0)
	return v


## Takes one pending level-up for a menu; returns the level that menu is for (0 if none is pending).
func take_level_up() -> int:
	if pending <= 0:
		return 0
	pending -= 1
	return level - pending


## Gauge fill 0..1 toward the next level, for the HUD: full while a level-up waits, the clock in the closing.
func fill() -> float:
	if clock_fill >= 0.0:
		return clampf(clock_fill, 0.0, 1.0)
	if pending > 0:
		return 1.0
	return light_fill()


## The true fill (light / need), overflow after a level-up included.
func light_fill() -> float:
	return clampf(light / need, 0.0, 1.0)


## The fill once `v` more light lands, capped at 1 (the shard that fills the lantern reads 1: the top of the ladder).
func fill_after(v: float) -> float:
	return clampf((light + v) / need, 0.0, 1.0)


## Applies a sale's power dictionary (damage, fire, speed, range multiply; hearts, shots, pierce add).
## `heal` false (HEALING sold): new hearts come empty.
func gain(power: Dictionary, heal: bool) -> void:
	for key: String in power:
		var v: float = power[key]
		match key:
			"damage", "fire", "speed", "range":
				mult[key] = float(mult[key]) * (1.0 + v)
			"hearts":
				hearts += int(v)
				_grow_hearts(int(v), heal)
			"shots":
				shots += int(v)
			"pierce":
				pierce += int(v)
			_:
				push_warning("progression: unknown power '%s'" % key)


## The powers a sale of `power` would leave, without applying it (the menu's NEW: tags): {mult, shots, pierce}.
## Same rules as gain().
func preview(power: Dictionary) -> Dictionary:
	var m: Dictionary = mult.duplicate()
	var s := shots
	var p := pierce
	for key: String in power:
		var v: float = power[key]
		match key:
			"damage", "fire", "speed", "range":
				m[key] = float(m[key]) * (1.0 + v)
			"shots":
				s += int(v)
			"pierce":
				p += int(v)
	return {"mult": m, "shots": s, "pierce": p}


## Shot damage (absolute, x10 scale).
func damage() -> int:
	return roundi(BASE_DAMAGE * float(mult["damage"]))


## Seconds between volleys.
func fire_interval() -> float:
	return BASE_FIRE / float(mult["fire"])


## Wick's top speed in px/s.
func speed() -> float:
	return BASE_SPEED * float(mult["speed"])


## Wick's acceleration in px/s^2 (the player applies MOVEMENT's ice factor on top).
func accel() -> float:
	return BASE_ACCEL * float(mult["speed"])


## Auto-aim range in px.
func range_px() -> float:
	return BASE_RANGE * float(mult["range"])


## A shot's lifetime in seconds.
func shot_life() -> float:
	return BASE_LIFE * float(mult["range"])


## Wick's heart count with every sold heart.
func max_hp() -> int:
	return BASE_HP + hearts


func _grow_hearts(n: int, heal: bool) -> void:
	if run == null or run.get("player") == null:
		return
	run.player.max_hp = max_hp()
	if heal and n > 0:
		run.player.heal(n)
