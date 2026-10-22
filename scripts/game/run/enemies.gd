extends RefCounted
## Brain host (ported from low_settings_island.gd): spawn, step at enemy_tempo, hits and deaths, contact with
## Wick, remnants (killed brains playing their death), hazards (enemy projectiles), the crowd grid and the enemy
## sound thinning. Kills drop light shards (run.shards.drop) and emit run.killed.

const BRAIN := preload("res://scripts/cast/enemies/enemy.gd")
const KIT := preload("res://scripts/cast/enemies/enemy_kit.gd")
const DIRECTOR := preload("res://scripts/game/run/director.gd")
const BRAIN_PATH := "res://scripts/cast/enemies/%s.gd"
const GRID := 24.0 # px: cell of the walkers' grid for the crowd push (at least the widest size pair / 2)
const SCRIPTED_TEMPO := 0.8 # the tutorial's scripted Snuffers walk slower
## Enemy sounds in a crowd: one id restarts at most every SOUND_GAP s (SOUND_GAPS for the crowd's own sounds), and
## at most SOUND_VOICES enemy sounds start within SOUND_WINDOW s, except the tells (SOUND_TELLS always play).
## Tonal ones (SOUND_TONAL, on D or A) play at their pitch; the rest get play()'s small random pitch.
const SOUND_GAP := 0.08
const SOUND_GAPS := {"snuffer_spawn": 0.35, "snuffer_pop": 0.1, "snuffer_clatter": 0.18, "toad_hop": 0.25,
	"toad_turn": 0.3, "toad_block": 0.1, "spore_pop": 0.1, "gloam_hush": 0.15, "gloam_tick": 0.15,
	"owl_wingbeat": 0.2, "owl_ruffle": 0.3, "sporecap_swell": 0.3, "sporecap_puff": 0.2}
const SOUND_VOICES := 3
const KILL_GAP_MS := 60 # the kill sound restarts at most this often (ms of run.anim_time, which also runs in the frozen blast)
const SOUND_WINDOW := 0.12
const SOUND_TELLS: Array[String] = ["owl_hoot", "owl_whoosh", "magpie_chatter", "magpie_alarm", "magpie_laugh",
	"star_chime", "star_home", "sporecap_land", "sporecap_swell", "gloam_open", "formation"]
const SOUND_TONAL: Array[String] = ["owl_hoot", "owl_squawk", "magpie_chatter", "magpie_alarm", "magpie_squawk",
	"magpie_laugh", "star_chime", "star_home", "snuffer_pop", "snuffer_clatter", "toad_croak", "toad_death",
	"sporecap_swell", "sporecap_death", "gloam_tick", "formation"]

var run ## the Run (run.gd), duck-typed
var list: Array = [] ## live brains (the same array as run.enemies)
var remnants: Array = [] ## killed brains still playing their death
var hazards: Array = [] ## enemy projectiles
var kills := 0 ## this run
var scripted := {} ## brain -> true: the tutorial's slow Snuffers

var _scripts := {} # kind id -> its brain script
var _kits := {} # kind id -> KIT
var _grid := {} # Vector2i cell -> the solid enemies in it, rebuilt every step (the crowd push looks 3x3 cells)
var _grid_used: Array[Vector2i] = []
var _heard := {} # enemy sound id -> clock when it last started
var _voices: Array[float] = [] # clock of the enemy sounds started lately (SOUND_WINDOW)
var _sfx := {} # settings_fx's SFX_DB, when it has one
var _clock := 0.0 # real seconds, for the sound gaps
var _kill_ms := -100000 # run.anim_time ms of the last kill sound (KILL_GAP_MS)


## Keeps the back-reference to the run and loads every brain and kit once.
func setup(r) -> void:
	run = r
	for id in DIRECTOR.KINDS:
		if ResourceLoader.exists(BRAIN_PATH % id):
			_scripts[id] = load(BRAIN_PATH % id)
			kit(id)


## Reads the sound table from settings_fx (main calls fx.setup first).
func read_sfx() -> void:
	var consts: Dictionary = run.fx.get_script().get_script_constant_map()
	_sfx = consts.get("SFX_DB", {})


## Clears every enemy, remnant and hazard.
func reset() -> void:
	for e in list:
		_drop(e)
	for r in remnants:
		_drop(r)
	list.clear()
	remnants.clear()
	hazards.clear()
	scripted.clear()
	kills = 0
	_heard.clear()
	_voices.clear()


## The kind's art and numbers, loaded once.
func kit(id: String) -> KIT:
	if not _kits.has(id):
		_kits[id] = KIT.new(id)
	return _kits[id]


func has_brain(id: String) -> bool:
	return _scripts.has(id)


## Spawns brain `i` of `n` of kind `id` arriving at `anchor`; returns it (a Snuffer if the kind has no brain).
func spawn(id: String, anchor: Vector2, i: int, n: int) -> RefCounted:
	if not has_brain(id):
		id = DIRECTOR.FALLBACK
	var e: BRAIN = _scripts[id].new()
	e.game = run
	e.id = id
	e.kit = kit(id)
	e.kind = DIRECTOR.KINDS.find(id)
	e.hp = run.director.hp(id)
	e.node = Node2D.new()
	e.node.draw.connect(run.view.paint_brain.bind(e))
	run.island.add_actor(e.node)
	e.arrive(anchor, i, n)
	e.setup()
	e.node.position = e.pos.round()
	list.append(e)
	run.stat("spawned_" + id)
	return e


## Live enemies of kind `id`.
func alive(id: String) -> int:
	var n := 0
	for e in list:
		if e.id == id:
			n += 1
	return n


## Steps brains and hazards (dt x run.enemy_tempo), contact damage. Deaths happen in hurt_enemy. World seconds.
func step(dt: float) -> void:
	var edt: float = dt * run.enemy_tempo
	_fill_grid()
	for i in range(list.size() - 1, -1, -1):
		var b = list[i]
		var bdt := edt * SCRIPTED_TEMPO if scripted.has(b) else edt
		b.flash = maxf(b.flash - bdt, 0.0)
		if b.hit_stop > 0.0:
			b.hit_stop -= bdt
			continue
		b.step(bdt)
		if b.gone: # left the field alive (no kill)
			list.remove_at(i)
			scripted.erase(b)
			_drop(b)
			run.stat("left_" + b.id)
	for i in range(remnants.size() - 1, -1, -1):
		var r = remnants[i]
		if r.hit_stop > 0.0:
			r.hit_stop -= edt
			continue
		r.step_dead(edt)
		if r.gone:
			remnants.remove_at(i)
			_drop(r)
			run.stat("remnants_done_" + r.id)
	for i in range(hazards.size() - 1, -1, -1):
		var h = hazards[i]
		h.step(edt)
		if h.blocked_by_cover and h.harmful and not h.gone and not run.view.open(h.pos, 2, false):
			h.on_blocked()
			run.stat("hazards_blocked")
		if h.gone:
			hazards.remove_at(i)


## The first brain or hazard touching Wick's body: "" if none, else the source ("hazard" or the kind id).
func contact() -> String:
	var body: Vector2 = run.player.body_centre()
	var r: float = run.player.BODY_RADIUS
	for e in list:
		if e.touches(body, r):
			return e.id
	for h in hazards:
		if h.touches(body, r):
			h.on_hit_wick()
			return "hazard"
	return ""


## Damages `e` (`from` = the hit's source, for the toad's parasol); kills it at 0 hp.
func hurt_enemy(e, dmg: int, push: Vector2, from := Vector2.INF) -> void:
	if e == null or e.dead or not list.has(e):
		return
	if from != Vector2.INF and e.blocks(from):
		var c: Vector2 = e.centre()
		e.on_block(c + (from - c).normalized() * e.reach(), from)
		run.stat("blocks")
		return
	e.hp -= dmg
	run.stat("hits")
	if e.hp > 0:
		e.hurt(dmg, push, from)
		run.fx.play("hit")
		return
	list.erase(e)
	scripted.erase(e)
	kills += 1
	var at: Vector2 = e.centre()
	e.die(push, from)
	remnants.append(e)
	run.stat("killed_" + e.id)
	var ms := int(run.anim_time * 1000.0) # the run's clock, not the wall's: fx.play's pitch jitter keeps a seeded run's RNG
	if ms - _kill_ms >= KILL_GAP_MS: # a blast kills the horde in one frame: one kill sound, not a pile of them
		_kill_ms = ms
		run.fx.play("kill")
	run.on_kill(e.id, at)


## Plays an enemy sound if settings_fx has it, thinned in a crowd (SOUND_GAP, SOUND_VOICES).
func sound(sfx: String, now: float) -> void:
	if not _sfx.is_empty() and not _sfx.has(sfx):
		return
	if now - float(_heard.get(sfx, -INF)) < float(SOUND_GAPS.get(sfx, SOUND_GAP)):
		return
	while not _voices.is_empty() and now - _voices[0] >= SOUND_WINDOW:
		_voices.pop_front()
	if _voices.size() >= SOUND_VOICES and not SOUND_TELLS.has(sfx):
		return
	_heard[sfx] = now
	_voices.append(now)
	run.fx.play(sfx, 0.0 if SOUND_TONAL.has(sfx) else 0.06)
	run.stat("sound_" + sfx)


## The crowd push on `e` from overlapping walkers (director ROSTER `size`).
func separation(e) -> Vector2:
	var sep := Vector2.ZERO
	var size := DIRECTOR.size(e.id)
	var c := Vector2i((e.pos / GRID).floor())
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell: Variant = _grid.get(c + Vector2i(dx, dy))
			if cell == null:
				continue
			for o in cell:
				if o == e:
					continue
				var d: Vector2 = e.pos - o.pos
				var min_d := (size + DIRECTOR.size(o.id)) * 0.5
				var l2 := d.length_squared()
				if l2 < min_d * min_d and l2 > 0.0001:
					var l := sqrt(l2)
					sep += d / l * (min_d - l)
	return sep


## Shoves every live enemy within 30 px of `at` away (a hit on Wick, so one touch never chains into several).
func shove(at: Vector2) -> void:
	for e in list:
		var d: Vector2 = e.pos - at
		if d.length_squared() < 900.0:
			e.push = d.normalized() * 160.0


## Sorts the solid enemies into GRID cells (arrays are kept and reused).
func _fill_grid() -> void:
	for k in _grid_used:
		(_grid[k] as Array).clear()
	_grid_used.clear()
	for e in list:
		if not e.solid():
			continue
		var k := Vector2i((e.pos / GRID).floor())
		var cell: Variant = _grid.get(k)
		if cell == null:
			cell = []
			_grid[k] = cell
		if (cell as Array).is_empty():
			_grid_used.append(k)
		(cell as Array).append(e)


func _drop(b) -> void:
	if b != null and b.node != null:
		b.node.queue_free()
		b.node = null
