class_name LxClockHand
extends LxToy
## Island 1 Belfry walkable brass clock hand / Mainspring rotating bridge (`belfry_r11`, `belfry_r15`).
## Supports continuous sweeping hands (`hand:"hour"|"minute"`) AND tone-stepped bridges (`hand:"bridge"`,
## Dawn turns CW, War turns CCW, syncing `belfry_clock_hand` in `Lx.vars`).
## Dusk ring freezes `dusk_freezable` hands (e.g. Minute hand) for `freeze_secs` (2.5 s) so Wick can bridge across!
## Props: hand ("hour"|"minute"|"bridge"), length (float, 64), width (float, 18), speed (float, 0.35),
## start_deg (float, 0), dusk_freezable (bool, true), freeze_secs (float, 2.5),
## dawn_step_deg (float, 90), war_step_deg (float, -90), sync_var (String), sync_scope (String), persist (bool).

const CARDINAL_NAMES: Dictionary = {0: "east", 1: "south", 2: "west", 3: "north"}

var hand_kind: String = "minute"
var length: float = 64.0
var width: float = 18.0
var speed: float = 0.35
var dusk_freezable: bool = true
var freeze_secs: float = 2.5
var dawn_step_deg: float = 90.0
var war_step_deg: float = -90.0
var sync_var: String = ""
var sync_scope: String = "dungeon:belfry"

var angle: float = 0.0
var target_angle: float = 0.0
var frozen_t: float = 0.0


func _toy_setup() -> void:
	kind = "clock_hand"
	hand_kind = str(props.get("hand", "minute")).strip_edges().to_lower()
	if hand_kind not in ["hour", "minute", "bridge"]:
		hand_kind = "minute"
	length = maxf(24.0, float(props.get("length", 64.0)))
	width = clampf(float(props.get("width", 18.0)), 12.0, 32.0)
	speed = float(props.get("speed", 0.0 if hand_kind == "bridge" else (0.14 if hand_kind == "hour" else 0.42)))
	dusk_freezable = bool(props.get("dusk_freezable", hand_kind != "hour"))
	freeze_secs = maxf(0.5, float(props.get("freeze_secs", 2.5)))
	dawn_step_deg = float(props.get("dawn_step_deg", 90.0))
	war_step_deg = float(props.get("war_step_deg", -90.0))
	sync_var = str(props.get("sync_var", "")).strip_edges()
	sync_scope = str(props.get("sync_scope", "dungeon:belfry")).strip_edges()
	angle = deg_to_rad(float(props.get("start_deg", 180.0 if hand_kind == "bridge" else 0.0)))
	target_angle = angle
	frozen_t = 0.0
	radius = length
	size = Vector2(length * 2.0, length * 2.0)
	z_index = -4
	_sync_from_world_var()
	queue_redraw()


func _sync_from_world_var() -> void:
	if sync_var.is_empty():
		return
	var raw_v: Variant = Lx.vars.get_var(sync_scope, sync_var, "") if Lx.vars != null else LxToyDraw.world_get_var(sync_scope, sync_var, "")
	var cur: String = str(raw_v).strip_edges().to_lower()
	for q: int in CARDINAL_NAMES.keys():
		if str(CARDINAL_NAMES[q]) == cur:
			angle = float(q) * (PI * 0.5)
			target_angle = angle
			return


func reset_toy() -> void:
	if persist:
		return
	frozen_t = 0.0
	angle = deg_to_rad(float(props.get("start_deg", 180.0 if hand_kind == "bridge" else 0.0)))
	target_angle = angle
	queue_redraw()


func is_frozen() -> bool:
	return frozen_t > 0.0


func get_tip_pos() -> Vector2:
	return pos + Vector2.from_angle(angle) * length


func is_platform_solid() -> bool:
	return active


func get_platform_rect() -> Rect2:
	if not active:
		return Rect2()
	var tip: Vector2 = get_tip_pos()
	var hw: float = width * 0.5
	var x0: float = minf(pos.x, tip.x) - hw
	var y0: float = minf(pos.y, tip.y) - hw
	var x1: float = maxf(pos.x, tip.x) + hw
	var y1: float = maxf(pos.y, tip.y) + hw
	return Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))


func on_ring(in_tone: String, _dir: Vector2) -> void:
	if not active:
		return
	var t: String = in_tone.strip_edges().to_lower()
	if t == "dusk" and dusk_freezable:
		frozen_t = freeze_secs
		_emit_sfx(_pick_sfx("bell_dusk_ring", "crystal_clank"))
		queue_redraw()
		return
	if hand_kind == "bridge":
		if t == "dawn":
			target_angle += deg_to_rad(dawn_step_deg)
			_emit_sfx("clockwork_chime")
			_write_world_var()
			queue_redraw()
		elif t == "war":
			target_angle += deg_to_rad(war_step_deg)
			_emit_sfx("clockwork_chime")
			_write_world_var()
			queue_redraw()


func _write_world_var() -> void:
	if sync_var.is_empty():
		return
	var q: int = posmod(int(roundf(target_angle / (PI * 0.5))), 4)
	var name_dir: String = str(CARDINAL_NAMES.get(q, "west"))
	if Lx.vars != null:
		Lx.vars.set_var(sync_scope, sync_var, name_dir)
	else:
		LxToyDraw.world_set_var(sync_scope, sync_var, name_dir)


func tick(dt: float) -> void:
	super.tick(dt)
	if island_id == 1 and Lx.world == region and region != null:
		var rnode: Node = region.get_node_or_null("Island1RuleOverlay")
		if rnode != null and rnode.has_method("tick_from_toy"):
			rnode.call("tick_from_toy", self, dt)
	if not active:
		return
	if frozen_t > 0.0:
		frozen_t = maxf(0.0, frozen_t - dt)
		queue_redraw()
		return
	var da: float = 0.0
	if hand_kind == "bridge":
		if absf(target_angle - angle) > 0.0005:
			var prev_a: float = angle
			angle = move_toward(angle, target_angle, PI * 1.15 * dt)
			da = angle - prev_a
	elif absf(speed) > 0.0001:
		da = speed * dt
		angle = fposmod(angle + da, TAU)
		target_angle = angle
	if absf(da) > 0.00001:
		_carry_riders(da)
		queue_redraw()


func _carry_riders(da: float) -> void:
	var tip: Vector2 = get_tip_pos()
	var hw: float = width * 0.5 + 3.0
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead and not w.is_dashing() and not w.is_gliding() and not w.is_zipping() and not w.is_launched() and not w.is_mounted():
			var cp: Vector2 = Geometry2D.get_closest_point_to_segment(w.global_position, pos, tip)
			if cp.distance_to(w.global_position) <= hw:
				var np: Vector2 = pos + (w.global_position - pos).rotated(da)
				if region != null and region.has_method("collide"):
					np = region.call("collide", np, LxWick.BODY_RADIUS, true, true) as Vector2
				w.global_position = np
				w.last_pos = np
		if w.lantern != null and w.lantern.is_hanging():
			var cpl: Vector2 = Geometry2D.get_closest_point_to_segment(w.lantern.pos, pos, tip)
			if cpl.distance_to(w.lantern.pos) <= hw:
				w.lantern.pos = pos + (w.lantern.pos - pos).rotated(da)
				w.lantern.prev_pos = w.lantern.pos
				w.lantern.global_position = w.lantern.pos.round()


func _pick_sfx(preferred: String, fallback: String) -> String:
	if Lx.packs != null and not Lx.packs.sfx_cue(preferred).is_empty():
		return preferred
	return fallback


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["angle"] = target_angle
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("angle"):
		angle = float(d.get("angle", angle))
		target_angle = angle
	queue_redraw()


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var dir := Vector2.from_angle(angle)
	var perp := Vector2(-dir.y, dir.x)
	var tip: Vector2 = dir * length
	var hw: float = width * 0.5
	var is_fr: bool = frozen_t > 0.0

	# Subtle clock dial ring on pit below
	draw_arc(Vector2.ZERO, roundf(length), 0.0, TAU, 32, Color(c_dusk, 0.28 if red else 0.42), 1.0)
	# Walkable brass hand polygon
	var poly := PackedVector2Array([
		(-perp * hw).round(),
		(tip - perp * (hw * 0.8)).round(),
		(tip + dir * 4.0).round(),
		(tip + perp * (hw * 0.8)).round(),
		(perp * hw).round(),
	])
	var fill_c: Color = PAL["sky"] as Color if is_fr else (c_apricot if hand_kind == "hour" else (c_gold if hand_kind == "bridge" else PAL["mauve"] as Color))
	var edge_c: Color = c_ice if is_fr else (c_cream if hand_kind == "bridge" else c_gold)
	draw_colored_polygon(poly, fill_c)
	for i: int in range(poly.size()):
		draw_line(poly[i], poly[(i + 1) % poly.size()], c_void, 2.0)
		draw_line(poly[i], poly[(i + 1) % poly.size()], edge_c, 1.0)
	# Greyscale-distinct hand landmarks: hour counterweight, bridge rung notches, minute eyelet
	if hand_kind == "hour":
		var cw_p: Vector2 = (-dir * 10.0).round()
		draw_circle(cw_p, 5.0, c_void)
		draw_circle(cw_p, 3.0, c_apricot)
	elif hand_kind == "bridge":
		for ri: int in range(1, 4):
			var rp: Vector2 = (dir * (length * float(ri) * 0.25)).round()
			draw_line((rp - perp * 4.0).round(), (rp + perp * 4.0).round(), c_void, 2.0)
			draw_line((rp - perp * 3.0).round(), (rp + perp * 3.0).round(), c_cream, 1.0)
	else:
		var eye_p: Vector2 = (dir * (length * 0.72)).round()
		draw_circle(eye_p, 3.0, c_void)
		draw_circle(eye_p, 2.0, c_ice if is_fr else c_cream)
	# Center ridge & brass hub
	draw_line(Vector2.ZERO, tip.round(), c_night, 2.0)
	draw_line(Vector2.ZERO, tip.round(), edge_c, 1.0)
	draw_circle(Vector2.ZERO, 8.0, c_void)
	draw_circle(Vector2.ZERO, 6.0, c_night)
	draw_circle(Vector2.ZERO, 3.0, c_ice if is_fr else c_gold)
	if is_fr:
		# Void-backed frost studs + countdown bar so frozen state pops in greyscale
		for fp: Vector2 in [Vector2(-6.0, -6.0), Vector2(5.0, 5.0)]:
			draw_rect(Rect2(fp - Vector2.ONE, Vector2(3.0, 3.0)), c_void)
			draw_rect(Rect2(fp, Vector2(2.0, 2.0)), c_cream)
		LxToyDraw.draw_bar(self, Vector2(-7.0, -14.0), 14.0, frozen_t / maxf(0.1, freeze_secs), c_ice)
	_draw_signal_pulses()
