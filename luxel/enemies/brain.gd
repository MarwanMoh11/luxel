class_name LxEnemyBrain
extends Node2D
## Base enemy brain contract for Luxel 1.0.
## Enforces routine/leash/no-pursuit, shared attack director token, tell/recover floors,
## event-bus-only damage output, and 20-colour Last Light greybox/sprite rendering.

enum State {
	ROUTINE, NOTICE, POSITION, WAIT_TOKEN, TELL, COMMIT, RECOVER, STAGGER, RETURN, DEAD,
}

enum HitResult {
	GLANCED = -1, BLOCKED = 0, CHIPPED = 1, OPENED = 2, KILLED = 3,
}

const STATE_NAMES: PackedStringArray = [
	"ROUTINE", "NOTICE", "POSITION", "WAIT_TOKEN", "TELL",
	"COMMIT", "RECOVER", "STAGGER", "RETURN", "DEAD",
]

const PAL: Dictionary = {
	"void": Color("0d0b1e"), "night": Color("211a3b"), "dusk": Color("3d2c5c"),
	"plum": Color("6a3d6f"), "wine": Color("a0466a"), "coral": Color("e2725b"),
	"apricot": Color("f5a96a"), "gold": Color("ffd98c"), "cream": Color("fff4dc"),
	"pine": Color("1d3d4c"), "teal": Color("2b6b68"), "jade": Color("4c9e78"),
	"lime": Color("a3cf7d"), "deep": Color("263873"), "blue": Color("3e6db0"),
	"sky": Color("78a9da"), "ice": Color("c7e5ef"), "mauve": Color("8a6e91"),
	"stone": Color("c2a7ae"), "rose": Color("ec9fa8"),
}

const MIN_NORMAL_TELL: float = 0.35
const MIN_HEAVY_TELL: float = 0.50
const MIN_COUNTER_TELL: float = 0.25
const MIN_RECOVER_TIME: float = 0.60

const _STATE_ANIMS: Dictionary = { State.TELL: "tell", State.COMMIT: "commit", State.RECOVER: "recover", State.STAGGER: "stagger" }
const _VARIANT_SHEETS: Dictionary = {
	"bell_warden": ["enemies/warden", "gold", 1.18], "crab_warden": ["enemies/warden", "coral", 1.0],
	"forge_warden": ["enemies/warden", "apricot", 1.0], "clockwork_warden": ["enemies/warden", "sky", 1.0],
	"moonshade_warden": ["enemies/warden", "ice", 1.0], "moonshade_snatcher": ["enemies/snatcher", "ice", 1.0],
	"gull_thief": ["enemies/snatcher", "stone", 1.0], "moonshade_owl": ["enemies/owl", "ice", 1.0],
	"phantom_owl": ["enemies/owl", "ice", 1.0], "hollow_wick": ["wick/wick", "plum", 1.0],
	"hollow_wick_boss": ["wick/wick", "plum", 1.0],
}

@export var home: Vector2 = Vector2.ZERO
@export var leash_radius: float = 158.0
@export var notice_radius: float = 120.0
@export var tell_time: float = 0.48
@export var recover_time: float = 1.15

var kind: String = "enemy"
var pos: Vector2 = Vector2.ZERO
var facing: float = 0.0
var hp: float = 4.0
var max_hp: float = 4.0
var body_radius: float = 5.0
var routine_speed: float = 36.0
var state: int = State.ROUTINE
var is_boss: bool = false
var phase: int = 1
var director: LxAttackDirector = null
var world_ctx: Node = null
var flash_t: float = 0.0
var clank_t: float = 0.0
var awaken_t: float = 0.0
var knock: Vector2 = Vector2.ZERO
var opened_kill: bool = false
var last_tell_duration: float = 0.0
var last_recover_duration: float = 0.0
var attack_damage: float = 1.0

var data: LxEnemyData = null
var enemy_id: String = ""
var zone: String = ""
var slot: int = 0
var state_timer: float = 0.0
var anim_t: float = 0.0
var alert_t: float = 0.0
var lost_t: float = 0.0
var cooldown: float = 0.0
var rally_t: float = -1.0
var shard_drop: int = 2
var give_up_time: float = 2.2
var is_counter_attack: bool = false
var boss_id: String = ""
var island_id: int = 1
var _sprite_sheet: LxSpriteSheet = null
var _sprite_tint: Color = Color.WHITE
var _sprite_scale: Vector2 = Vector2.ONE
var _fallback_rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func _to_vec2(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Vector2:
		return v as Vector2
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float((v as Array)[0]), float((v as Array)[1]))
	return fallback


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	if p_director != null:
		director = p_director
	elif spec.get("director") is LxAttackDirector:
		director = spec["director"] as LxAttackDirector
	else:
		director = null
	if p_world != null:
		world_ctx = p_world
	elif spec.get("region") is Node:
		world_ctx = spec["region"] as Node
	elif spec.get("world") is Node:
		world_ctx = spec["world"] as Node
	_fallback_rng.seed = int(spec.get("seed", 101))

	if spec.has("data") and spec["data"] is LxEnemyData:
		_apply_data(spec["data"] as LxEnemyData)
	if spec.has("kind"):
		kind = str(spec["kind"])
	if spec.has("id"):
		enemy_id = str(spec["id"])
	if spec.has("home"):
		home = _to_vec2(spec["home"], home)
	elif spec.has("post"):
		home = _to_vec2(spec["post"], home)
	elif spec.has("pos"):
		home = _to_vec2(spec["pos"], home)

	pos = _to_vec2(spec["pos"], home) if spec.has("pos") else home
	facing = float(spec.get("facing", facing))
	if spec.has("leash_radius"):
		leash_radius = maxf(16.0, float(spec["leash_radius"]))
	elif spec.has("leash"):
		leash_radius = maxf(16.0, float(spec["leash"]))
	if spec.has("notice_radius"):
		notice_radius = maxf(16.0, float(spec["notice_radius"]))
	if spec.has("tell_time"):
		tell_time = float(spec["tell_time"])
	if spec.has("recover_time"):
		recover_time = maxf(MIN_RECOVER_TIME, float(spec["recover_time"]))
	if spec.has("routine_speed"):
		routine_speed = maxf(8.0, float(spec["routine_speed"]))
	if spec.has("body_radius"):
		body_radius = maxf(2.0, float(spec["body_radius"]))
	if spec.has("max_hp"):
		max_hp = maxf(0.25, float(spec["max_hp"]))
	max_hp *= maxf(0.1, float(spec.get("hp_scale", 1.0)))
	hp = max_hp
	if spec.has("attack_damage"):
		attack_damage = maxf(0.5, float(spec["attack_damage"]))
	if spec.has("shard_drop"):
		shard_drop = maxi(0, int(spec["shard_drop"]))
	if spec.has("zone"):
		zone = str(spec["zone"])
	if spec.has("island_id"):
		island_id = int(spec["island_id"])

	state = State.ROUTINE
	phase = 1
	state_timer = 0.0
	anim_t = 0.0
	flash_t = 0.0
	clank_t = 0.0
	awaken_t = 0.0
	alert_t = 0.0
	lost_t = 0.0
	cooldown = 0.0
	rally_t = -1.0
	knock = Vector2.ZERO
	opened_kill = false
	is_counter_attack = false
	last_tell_duration = 0.0
	last_recover_duration = 0.0

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clamp_to_leash()
	_try_load_optional_sprite()
	if director != null:
		director.register(self)
	queue_redraw()


func _apply_data(d: LxEnemyData) -> void:
	data = d
	kind = d.kind
	max_hp = d.max_hp
	hp = d.max_hp
	body_radius = d.body_radius
	routine_speed = d.routine_speed
	leash_radius = d.leash_radius
	notice_radius = d.notice_radius
	tell_time = d.tell_time
	recover_time = maxf(MIN_RECOVER_TIME, d.recover_time)
	shard_drop = d.shard_drop
	attack_damage = d.attack_damage
	is_boss = d.is_boss


func tick(dt: float) -> void:
	if state == State.DEAD:
		return
	anim_t += dt
	flash_t = maxf(0.0, flash_t - dt)
	clank_t = maxf(0.0, clank_t - dt)
	awaken_t = maxf(0.0, awaken_t - dt)
	alert_t = maxf(0.0, alert_t - dt)
	cooldown = maxf(0.0, cooldown - dt)
	if knock.length() > 1.0:
		_move_step(knock * dt, is_flying())
		knock = knock.move_toward(Vector2.ZERO, 600.0 * dt)
	_step_brain(dt)
	_clamp_to_leash()
	queue_redraw()


func _step_brain(_dt: float) -> void:
	pass


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var rel: Vector2 = (h["origin"] as Vector2) - pos
	hp -= float(h["damage"])
	flash_t = 0.12
	if rel.length() > 0.01:
		knock = -rel.normalized() * 110.0
	if hp <= 0.001:
		opened_kill = state == State.RECOVER or state == State.STAGGER or state == State.ROUTINE
		_die(hit)
		return HitResult.KILLED
	if bool(h["stagger"]):
		_release_token()
		state = State.STAGGER
		state_timer = 0.45
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func wants_token() -> bool: return state == State.POSITION or state == State.WAIT_TOKEN
func is_alive() -> bool: return state != State.DEAD and hp > 0.001
func is_targetable() -> bool: return is_alive()
func is_flying() -> bool: return false
func get_state_name() -> String: return STATE_NAMES[state] if (state >= 0 and state < STATE_NAMES.size()) else "UNKNOWN"


func debug_state() -> Dictionary:
	return {
		"kind": kind,
		"state": state,
		"state_name": get_state_name(),
		"pos": pos,
		"home": home,
		"dist_home": pos.distance_to(home),
		"hp": hp,
		"max_hp": max_hp,
		"has_token": director != null and director.token_holder == self,
		"tell_duration": last_tell_duration,
		"recover_duration": last_recover_duration,
		"is_counter": is_counter_attack,
		"committing": state == State.COMMIT,
	}


func distance_to_attention_target() -> float:
	return pos.distance_to(_get_wick_pos())


func apply_separation_push(push: Vector2) -> void:
	_move_step(push, false)
	_clamp_to_leash()


func _claim_token(ignore_gap: bool = false) -> bool:
	return true if director == null else director.claim_token(self, ignore_gap)


func _can_claim_token(ignore_gap: bool = false) -> bool:
	return true if director == null else director.can_claim_token(self, ignore_gap)


func _release_token() -> void:
	if director != null:
		director.release_token(self)


func _assist_tell_scale() -> float:
	if Lx.save != null and Lx.save.settings.has("assist_tell_scale"):
		return clampf(float(Lx.save.settings["assist_tell_scale"]), 1.0, 1.5)
	return 1.0


func _scaled_tell(base_tell: float, is_counter: bool = false, dmg: float = -1.0) -> float:
	var eff: float = attack_damage if dmg < 0.0 else dmg
	var fl: float = MIN_COUNTER_TELL if is_counter else (MIN_HEAVY_TELL if eff > 1.0 else MIN_NORMAL_TELL)
	return maxf(fl, base_tell) * _assist_tell_scale()


func _is_on_screen() -> bool:
	if Lx.camera != null and is_instance_valid(Lx.camera):
		return Lx.camera.is_on_screen(pos)
	return true


func _clamp_to_leash() -> void:
	if leash_radius > 0.0:
		var cap: float = maxf(0.0, leash_radius - 0.5)
		var off: Vector2 = pos - home
		var d: float = off.length()
		if d > cap and d > 0.0001:
			pos = home + (off / d) * cap
	position = pos.round()


func _move_step(step_vec: Vector2, flying: bool = false) -> void:
	pos = _collide_move(pos, pos + step_vec, flying)
	_clamp_to_leash()


func _turn_toward(target_angle: float, rate: float, dt: float) -> void:
	var diff: float = angle_difference(facing, target_angle)
	facing = wrapf(facing + clampf(diff, -rate * dt, rate * dt), -PI, PI)


func _has_player() -> bool:
	if world_ctx != null and is_instance_valid(world_ctx):
		if world_ctx.has_method("get_wick_pos") or world_ctx.get("wick_pos") is Vector2 \
				or world_ctx.get("wick") is Vector2 or world_ctx.get("wick") is Node2D:
			return true
	return Lx.player != null and is_instance_valid(Lx.player)


func _get_wick_pos() -> Vector2:
	if world_ctx != null and is_instance_valid(world_ctx):
		if world_ctx.has_method("get_wick_pos"):
			var vp: Variant = world_ctx.call("get_wick_pos")
			if vp is Vector2:
				return vp as Vector2
		if world_ctx.get("wick_pos") is Vector2:
			return world_ctx.get("wick_pos") as Vector2
		var wv: Variant = world_ctx.get("wick")
		if wv is Vector2:
			return wv as Vector2
		if wv is Node2D and is_instance_valid(wv):
			return (wv as Node2D).global_position
	if Lx.player != null and is_instance_valid(Lx.player):
		if Lx.player.get("pos") is Vector2:
			return Lx.player.get("pos") as Vector2
		if Lx.player is Node2D:
			return (Lx.player as Node2D).global_position
	return home + Vector2(9999.0, 9999.0)


func _get_lantern_state() -> int:
	if world_ctx != null and is_instance_valid(world_ctx):
		if world_ctx.has_method("get_lantern_state"):
			return int(world_ctx.call("get_lantern_state"))
		if world_ctx.get("lan_state") != null:
			return int(world_ctx.get("lan_state"))
		if world_ctx.get("lure") != null and bool(world_ctx.get("lure")):
			return 2
	if Lx.player != null and is_instance_valid(Lx.player):
		var lan: Variant = Lx.player.get("lantern")
		if lan is Object and is_instance_valid(lan) and (lan as Object).get("state") != null:
			return int((lan as Object).get("state"))
		if Lx.player.get("lan_state") != null:
			return int(Lx.player.get("lan_state"))
	return 0


func _is_lantern_hung() -> bool:
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("is_lantern_hung"):
		return bool(world_ctx.call("is_lantern_hung"))
	return _get_lantern_state() == 2


func _is_lantern_out() -> bool:
	if world_ctx != null and is_instance_valid(world_ctx):
		if world_ctx.has_method("is_lantern_out"):
			return bool(world_ctx.call("is_lantern_out"))
		if world_ctx.get("lure") != null:
			return bool(world_ctx.get("lure"))
	var st: int = _get_lantern_state()
	return st == 1 or st == 2


func _get_lantern_pos() -> Vector2:
	if world_ctx != null and is_instance_valid(world_ctx):
		if world_ctx.has_method("get_lantern_pos"):
			var lp: Variant = world_ctx.call("get_lantern_pos")
			if lp is Vector2:
				return lp as Vector2
		for key: String in ["lan_pos", "lantern_pos", "lantern"]:
			if world_ctx.get(key) is Vector2:
				return world_ctx.get(key) as Vector2
	if Lx.player != null and is_instance_valid(Lx.player):
		var lan: Variant = Lx.player.get("lantern")
		if lan is Object and is_instance_valid(lan):
			if (lan as Object).get("pos") is Vector2:
				return (lan as Object).get("pos") as Vector2
			if lan is Node2D:
				return (lan as Node2D).global_position
	return _get_wick_pos()


func _collide_move(from_p: Vector2, to_p: Vector2, flying: bool) -> Vector2:
	for ctx: Node in [world_ctx, Lx.world]:
		if ctx == null or not is_instance_valid(ctx):
			continue
		if flying and ctx.has_method("collide_fly"):
			return ctx.call("collide_fly", to_p, body_radius) as Vector2
		if ctx.has_method("collide_step"):
			return ctx.call("collide_step", from_p, to_p, body_radius, flying) as Vector2
		if ctx.has_method("collide_circle"):
			return ctx.call("collide_circle", to_p, body_radius, flying) as Vector2
		if ctx.has_method("collide"):
			return ctx.call("collide", to_p, body_radius) as Vector2
	return to_p


func _has_clear_view(a: Vector2, b: Vector2) -> bool:
	for ctx: Node in [world_ctx, Lx.world]:
		if ctx == null or not is_instance_valid(ctx):
			continue
		if ctx.has_method("clear_view"):
			return bool(ctx.call("clear_view", a, b))
		if ctx.has_method("has_line_of_sight"):
			return bool(ctx.call("has_line_of_sight", a, b))
	return true


func _randf_range(a: float, b: float) -> float:
	return Lx.rng.randf_range(a, b) if Lx.rng != null else _fallback_rng.randf_range(a, b)


func _read_hit(hit: Object) -> Dictionary:
	var dmg: float = float(hit.get("damage")) if hit.get("damage") != null else 0.0
	var dir_v: Variant = hit.get("dir")
	var dir: Vector2 = (dir_v as Vector2) if (dir_v is Vector2) else Vector2.ZERO
	var sw_v: Variant = hit.get("shield_wear")
	var orig_v: Variant = hit.get("origin")
	var orig: Vector2 = (orig_v as Vector2) if (orig_v is Vector2) else (pos - dir.normalized() * 16.0 if dir.length_squared() > 0.001 else _get_wick_pos())
	return {
		"source": str(hit.get("source")) if hit.get("source") != null else "",
		"damage": dmg,
		"dir": dir,
		"pierce": bool(hit.get("pierce")) if hit.get("pierce") != null else false,
		"shield_wear": float(sw_v) if (sw_v != null and float(sw_v) > 0.0) else dmg,
		"stagger": bool(hit.get("stagger")) if hit.get("stagger") != null else false,
		"origin": orig,
		"attacker": hit.get("attacker"),
		"cracks_armour": bool(hit.get("cracks_armour")) if hit.get("cracks_armour") != null else false,
	}


func _emit_enemy_hit(hit: Object, result: int) -> void:
	if Lx.events != null:
		Lx.events.enemy_hit.emit(self, hit, result)


func _emit_attack_started() -> void:
	if Lx.events != null:
		Lx.events.enemy_attack_started.emit(self, kind, pos)


func _emit_player_hit(hit_dir: Vector2, dmg: float = -1.0) -> void:
	var amt: float = attack_damage if dmg < 0.0 else dmg
	var d: Vector2 = hit_dir.normalized() if hit_dir.length_squared() > 0.001 else Vector2.from_angle(facing)
	if Lx.events != null:
		Lx.events.enemy_attack_landed.emit(self, kind, pos, d, amt)
		Lx.events.player_damaged.emit(amt, pos, d, kind)


func _emit_sfx(sfx_id: String) -> void:
	if Lx.events != null:
		Lx.events.sfx_requested.emit(sfx_id, pos, true)


func _die(hit: Object) -> void:
	hp = 0.0
	state = State.DEAD
	_release_token()
	if director != null:
		director.release_light(self)
		director.unregister(self)
	_emit_enemy_hit(hit, HitResult.KILLED)
	_emit_sfx("boss_kill" if is_boss else "enemy_kill")
	if Lx.state != null and shard_drop > 0: Lx.state.add_shards(shard_drop + (1 if opened_kill else 0))
	if Lx.events != null:
		Lx.events.enemy_killed.emit(self, kind, pos, opened_kill)
		if is_boss and boss_id != "": Lx.events.boss_defeated.emit(boss_id, island_id)
	queue_redraw()


func _try_load_optional_sprite() -> void:
	_sprite_sheet = null
	_sprite_tint = Color.WHITE
	_sprite_scale = Vector2.ONE
	for p: String in ["res://luxel/art/enemies/%s.json" % kind, "res://luxel/art/bosses/%s.json" % kind]:
		if FileAccess.file_exists(p):
			_sprite_sheet = LxSpriteSheet.load_sheet(p)
			if _sprite_sheet != null:
				return
	if _VARIANT_SHEETS.has(kind):
		var cfg: Array = _VARIANT_SHEETS[kind] as Array
		var vp: String = "res://luxel/art/%s.json" % str(cfg[0])
		if FileAccess.file_exists(vp):
			_sprite_sheet = LxSpriteSheet.load_sheet(vp)
			if _sprite_sheet != null:
				_sprite_tint = PAL[str(cfg[1])] as Color
				_sprite_scale = Vector2.ONE * float(cfg[2])


func _body_color() -> Color: return PAL["plum"] as Color
func _has_active_shield() -> bool: return false
func _shield_color() -> Color: return PAL["teal"] as Color
func _visual_offset() -> Vector2: return Vector2.ZERO
func _is_visually_lured() -> bool: return (has_method("_is_lured") and bool(call("_is_lured"))) or (has_method("_can_lure") and bool(call("_can_lure")))


func _draw() -> void:
	if state == State.DEAD:
		return
	var r: float = body_radius
	var off: Vector2 = _visual_offset()
	draw_circle(Vector2(2.0, r * 0.55), r * 0.9, PAL["void"] as Color)
	if is_boss and phase >= 2:
		var pn: int = mini(phase * 2, 8)
		var pc: Color = (PAL["cream"] if phase >= 4 else (PAL["coral"] if phase >= 3 else PAL["gold"])) as Color
		for pi: int in range(pn):
			var pa: float = anim_t * (1.8 + float(phase) * 0.6) + float(pi) * (TAU / float(pn))
			draw_rect(Rect2((off + Vector2(cos(pa) * (r + 5.0), r * 0.45 + sin(pa) * (r * 0.48 + 2.0))).round(), Vector2(2.0, 1.0)), pc if (pi % 2 == 0) else (PAL["gold"] as Color))

	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var ring_r: float = lerpf(r + 10.0, r + 3.0, prog)
		var tc: Color = (PAL["gold"] as Color) if is_counter_attack else (PAL["coral"] as Color)
		draw_arc(off, ring_r, facing - 0.95, facing + 0.95, 16, tc, 2.0)
		draw_line(off, off + Vector2.from_angle(facing) * (r + 5.0 + prog * 5.0), PAL["cream"] as Color, 1.5)
	elif state == State.COMMIT:
		draw_arc(off, r + 14.0, facing - 1.1, facing + 1.1, 16, PAL["gold"] as Color, 2.5)

	var drew_sprite: bool = false
	var sq: float = clampf(flash_t / 0.12, 0.0, 1.0)
	var draw_sc: Vector2 = _sprite_scale * Vector2(1.0 + 0.18 * sq, 1.0 - 0.16 * sq)
	if _sprite_sheet != null:
		var anim_name: String = str(_STATE_ANIMS.get(state, ("phase%d" % phase) if (phase >= 2 and state == State.ROUTINE and _sprite_sheet.animations.has("phase%d" % phase)) else ("phase2" if (phase >= 2 and state == State.ROUTINE and _sprite_sheet.animations.has("phase2")) else "routine")))
		var mod: Color = (PAL["cream"] as Color) if flash_t > 0.0 else _sprite_tint
		drew_sprite = _sprite_sheet.draw_actor(self, off, anim_name, Vector2.from_angle(facing), anim_t, mod, draw_sc)
	if not drew_sprite:
		var fill: Color = (PAL["cream"] as Color) if flash_t > 0.0 else ((PAL["stone"] as Color) if state == State.STAGGER else ((PAL["dusk"] as Color) if state == State.RECOVER else _body_color()))
		var sz := Vector2(r * 2.0 * (1.0 + 0.16 * sq), r * 2.0 * (1.0 - 0.14 * sq))
		var box := Rect2(off - sz * 0.5, sz)
		draw_rect(box, fill, true); draw_rect(box, PAL["night"] as Color, false, 1.0)
		draw_circle(off + Vector2.from_angle(facing) * (r * 0.55), 1.5, PAL["gold"] as Color)
	LxDamageFx.draw_wear(self, off)
	if _has_active_shield():
		LxDamageFx.draw_shield_arc(self, off, _shield_color())

	if alert_t > 0.0:
		var top: Vector2 = off + Vector2(0.0, -r - 9.0)
		draw_rect(Rect2(top + Vector2(-1.5, -5.0), Vector2(3.0, 5.0)), PAL["night"] as Color, true)
		draw_rect(Rect2(top + Vector2(-1.0, -4.5), Vector2(2.0, 3.5)), PAL["gold"] as Color, true)
		draw_rect(Rect2(top + Vector2(-1.0, 1.0), Vector2(2.0, 2.0)), PAL["gold"] as Color, true)
	elif state in [State.NOTICE, State.POSITION, State.WAIT_TOKEN, State.TELL] and _is_visually_lured():
		var lt: Vector2 = (off + Vector2(0.0, -r - 9.0 + sin(anim_t * 6.5) * 1.2)).round()
		draw_rect(Rect2(lt + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), PAL["gold"] as Color)
		draw_rect(Rect2(lt + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), PAL["gold"] as Color)
		draw_rect(Rect2(lt + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), PAL["apricot"] as Color)
		draw_rect(Rect2(lt, Vector2.ONE), PAL["cream"] as Color)

	if state == State.RECOVER or state == State.STAGGER:
		var scol: Color = (PAL["cream"] if int(anim_t * 10.0) % 2 == 0 else PAL["gold"]) if state == State.STAGGER else (PAL["gold"] as Color)
		for i: int in range(3):
			var ang: float = anim_t * (7.5 if state == State.STAGGER else 5.0) + float(i) * (TAU / 3.0)
			draw_circle(off + Vector2(cos(ang) * (r + 2.0), -r - 4.0 + sin(ang) * 2.0), 1.5, scol)

	if not is_boss and hp < max_hp - 0.01:
		var w: float = maxf(12.0, r * 2.4)
		var bp: Vector2 = off + Vector2(-w * 0.5, -r - 6.0)
		draw_rect(Rect2(bp, Vector2(w, 2.0)), PAL["night"] as Color, true)
		draw_rect(Rect2(bp, Vector2(w * clampf(hp / maxf(max_hp, 0.01), 0.0, 1.0), 2.0)), PAL["coral"] as Color, true)

	_draw_extra(off)


func _draw_extra(_off: Vector2) -> void:
	pass
