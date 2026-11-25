class_name LxBossDuel
extends RefCounted
## Player-like opponent helper (Hollow Wick, Understudy, Gardener Twice, Shadow at Noon).
## Reads Wick's unlocked kit + temper, mirrors them as fair telegraphed attacks,
## supports move-stealing hooks (set_move_locked), and records a 6 s player echo buffer.

const ECHO_WINDOW_S: float = 6.0
const SAMPLE_INTERVAL: float = 0.10

var boss: LxEnemyBrain = null
var stolen_moves: PackedStringArray = PackedStringArray()
var _echo_buf: Array[Dictionary] = []
var _sample_cd: float = 0.0
var _clock: float = 0.0


func _init(p_boss: LxEnemyBrain = null) -> void:
	boss = p_boss


func reset() -> void:
	restore_stolen_moves()
	_echo_buf.clear()
	_sample_cd = 0.0
	_clock = 0.0


func read_wick_kit() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var order: PackedStringArray = ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"]
	if Lx.state != null:
		for mid: String in order:
			if Lx.state.has_move(mid):
				out.append(mid)
	if out.is_empty():
		out.append("bolt")
	return out


func read_wick_temper() -> String:
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.get("temper") != null:
		return str(Lx.player.get("temper"))
	return ""


func steal_move(move_id: String) -> bool:
	if move_id.is_empty() or stolen_moves.has(move_id):
		return false
	stolen_moves.append(move_id)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("set_move_locked"):
		Lx.player.call("set_move_locked", move_id, true)
	return true


func restore_stolen_moves() -> void:
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("set_move_locked"):
		for mid: String in stolen_moves:
			Lx.player.call("set_move_locked", mid, false)
	stolen_moves.clear()


func tick_echo_recorder(dt: float) -> void:
	_clock += dt
	_sample_cd -= dt
	if _sample_cd > 0.0:
		return
	_sample_cd = SAMPLE_INTERVAL
	if is_instance_valid(Lx.player) and Lx.player is Node2D:
		var wp: Vector2 = (Lx.player as Node2D).global_position
		var wf: Vector2 = Lx.player.get("facing") as Vector2 if Lx.player.get("facing") is Vector2 else Vector2.RIGHT
		var dashing: bool = Lx.player.has_method("is_dashing") and bool(Lx.player.call("is_dashing"))
		_echo_buf.append({"t": _clock, "pos": wp, "facing": wf, "dashing": dashing})
		while _echo_buf.size() > 2 and (_clock - float(_echo_buf[0]["t"])) > ECHO_WINDOW_S:
			_echo_buf.pop_front()


func get_echo_snapshot(delay_s: float = 2.0) -> Dictionary:
	if _echo_buf.is_empty():
		return {}
	var want_t: float = _clock - clampf(delay_s, 0.1, ECHO_WINDOW_S)
	var best: Dictionary = _echo_buf[0]
	for s: Dictionary in _echo_buf:
		if float(s["t"]) <= want_t:
			best = s
		else:
			break
	return best


func register_mirror_kit(b: LxBossBase, opts: Dictionary = {}) -> PackedStringArray:
	## Registers telegraphed boss attacks matching every move currently unlocked by Wick.
	var kit: PackedStringArray = read_wick_kit()
	var registered: PackedStringArray = PackedStringArray()
	var col: String = str(opts.get("color", "sky"))
	var temper: String = read_wick_temper()

	if kit.has("bolt"):
		registered.append("duel_bolt")
		b.register_attack("duel_bolt", {
			"weight": 1.2, "tell": 0.48, "commit": 0.30, "recover": 0.90, "cooldown": 1.2,
			"on_tell": func(me: LxBossBase, tgt: Vector2, _dt: float, prog: float) -> void:
				if prog < 0.02:
					var d: Vector2 = (tgt - me.pos).normalized() if tgt.distance_to(me.pos) > 0.1 else Vector2.RIGHT
					me.ground.warn_lane(me.pos, me.pos + d * 130.0, 9.0, me.last_tell_duration, 0.0, col, "gold"),
			"on_commit_start": func(me: LxBossBase, tgt: Vector2) -> void:
				var d: Vector2 = (tgt - me.pos).normalized() if tgt.distance_to(me.pos) > 0.1 else Vector2.from_angle(me.facing)
				var cnt: int = 5 if (me.phase >= 2 or temper == "scatter") else 3
				var spd: float = 165.0 if temper == "lance" else 145.0
				me.patterns.emit_fan(me.pos, d, cnt, 0.48, spd, {"color": col, "source": "duel_bolt"}),
		})

	if kit.has("dash"):
		registered.append("duel_dash")
		b.register_attack("duel_dash", {
			"weight": 1.0, "tell": 0.50, "commit": 0.24, "recover": 0.95, "cooldown": 2.0,
			"on_tell": func(me: LxBossBase, tgt: Vector2, _dt: float, prog: float) -> void:
				if prog < 0.02:
					var d: Vector2 = (tgt - me.pos).normalized() if tgt.distance_to(me.pos) > 0.1 else Vector2.RIGHT
					me.set_meta("_duel_dir", d)
					me.ground.warn_lane(me.pos, me.pos + d * 82.0, 12.0, me.last_tell_duration, 0.0, "coral", "gold"),
			"on_commit": func(me: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
				var d: Vector2 = me.get_meta("_duel_dir", Vector2.from_angle(me.facing)) as Vector2
				me.move_boss(d * 270.0 * dt, true)
				me.check_contact_damage(15.0, d, 1.0, "duel_dash"),
		})

	if kit.has("throw"):
		registered.append("duel_zip")
		b.register_attack("duel_zip", {
			"weight": 0.9, "tell": 0.54, "commit": 0.28, "recover": 1.00, "cooldown": 2.6,
			"on_tell": func(me: LxBossBase, tgt: Vector2, _dt: float, prog: float) -> void:
				if prog < 0.02:
					var dest: Vector2 = me.clamp_to_arena(tgt)
					me.set_meta("_duel_zip", dest)
					me.ground.warn_ring(dest, 24.0, me.last_tell_duration, 0.0, col, "coral"),
			"on_commit": func(me: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
				var dest: Vector2 = me.get_meta("_duel_zip", me.pos) as Vector2
				me.move_boss((dest - me.pos).limit_length(320.0 * dt), true)
				if me.pos.distance_to(dest) <= 8.0:
					me.check_contact_damage(24.0, Vector2.from_angle(me.facing), 1.0, "duel_zip"),
		})

	if kit.has("beam"):
		registered.append("duel_beam")
		b.register_attack("duel_beam", {
			"phases": [2, 3, 4], "weight": 1.0, "tell": 0.58, "commit": 0.28, "recover": 1.10, "cooldown": 3.0,
			"on_tell": func(me: LxBossBase, tgt: Vector2, _dt: float, prog: float) -> void:
				if prog < 0.02:
					var d: Vector2 = (tgt - me.pos).normalized() if tgt.distance_to(me.pos) > 0.1 else Vector2.RIGHT
					me.set_meta("_duel_beam", d)
					me.ground.warn_lane(me.pos, me.pos + d * 150.0, 10.0, me.last_tell_duration, 1.0, col, "coral"),
		})

	if kit.has("sunflare"):
		registered.append("duel_flare")
		b.register_attack("duel_flare", {
			"phases": [2, 3, 4], "weight": 0.85, "tell": 0.60, "commit": 0.30, "recover": 1.15, "cooldown": 3.8,
			"on_tell": func(me: LxBossBase, _tgt: Vector2, _dt: float, prog: float) -> void:
				if prog < 0.02:
					me.ground.warn_ring(me.pos, 64.0, me.last_tell_duration, 1.0, "gold", "coral"),
			"on_commit_start": func(me: LxBossBase, _tgt: Vector2) -> void:
				me.patterns.emit_gap_ring(me.pos, 10, 125.0, me.facing, 0.72, {"color": "gold", "source": "duel_flare"}),
		})

	return registered
