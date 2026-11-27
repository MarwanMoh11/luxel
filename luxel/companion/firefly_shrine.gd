class_name LxFireflyShrine
extends Node2D
## Secret side-cave Firefly Shrine puzzle (1 per island 1..8), solvable purely with Pip
## Send/Perch (plus optional Lantern Tether synergy) and zero unowned moves required.
## Strictly 20 Last Light colours (LxPalette.PAL / LxBiomePalette.col) & pixel-snapped drawing.

const PED_RADIUS: float = 14.0
const BELL_RADIUS: float = 14.0
const ALCOVE_RADIUS: float = 14.0
const CHARGE_WINDOW_S: float = 7.5

var shrine_id: String = ""
var charm_id: String = ""
var island_id: int = 1
var ped_pos: Vector2 = Vector2.ZERO
var bell_pos: Vector2 = Vector2.ZERO
var alcove_pos: Vector2 = Vector2.ZERO
var unsealed: bool = false
var cleared: bool = false

var _clock: float = 0.0
var _ped_charge: float = 0.0
var _bell_charge: float = 0.0
var _burst_t: float = 0.0
var _nar_cd: float = 0.0

func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

static func _parse_vec2(val: Variant) -> Vector2:
	if val is Vector2: return (val as Vector2).round()
	if val is Array and (val as Array).size() >= 2:
		var arr: Array = val as Array
		return Vector2(float(arr[0]), float(arr[1])).round()
	return Vector2.ZERO

func setup(spec: Dictionary) -> void:
	shrine_id = str(spec.get("id", ""))
	charm_id = str(spec.get("charm", ""))
	island_id = clampi(int(spec.get("island", 1)), 1, 8)
	ped_pos = _parse_vec2(spec.get("ped_pos", Vector2.ZERO))
	bell_pos = _parse_vec2(spec.get("bell_pos", Vector2.ZERO))
	alcove_pos = _parse_vec2(spec.get("alcove_pos", Vector2.ZERO))
	cleared = LxFireflyState.is_shrine_cleared(shrine_id)
	unsealed = cleared
	_ped_charge = 0.0; _bell_charge = 0.0; _burst_t = 0.0; _nar_cd = 0.0
	name = shrine_id if not shrine_id.is_empty() else "FireflyShrine"
	queue_redraw()

func tick(dt: float, player_pos: Vector2, pip_pos: Vector2, pip_perched: bool) -> void:
	_clock += dt
	_ped_charge = maxf(0.0, _ped_charge - dt)
	_bell_charge = maxf(0.0, _bell_charge - dt)
	_burst_t = maxf(0.0, _burst_t - dt)
	_nar_cd = maxf(0.0, _nar_cd - dt)
	if not unsealed and not cleared:
		if pip_perched and pip_pos.is_finite() and pip_pos.distance_to(ped_pos) <= 22.0:
			_ped_charge = maxf(_ped_charge, 3.0)
		if Lx.player != null and is_instance_valid(Lx.player):
			var lan_v: Variant = Lx.player.get("lantern")
			if lan_v is LxLantern and is_instance_valid(lan_v):
				var lan: LxLantern = lan_v as LxLantern
				if lan.is_lure_active() and lan.pos.distance_to(ped_pos) <= 26.0:
					_ped_charge = maxf(_ped_charge, 2.5)
		if _ped_charge > 0.0 and _bell_charge > 0.0:
			_unseal_alcove()
	elif unsealed and not cleared and player_pos.is_finite() and player_pos.distance_to(alcove_pos) <= 13.0:
		claim_alcove()
	queue_redraw()

func on_pip_pass(pip_pos: Vector2, prev_pos: Vector2, radius: float, _pip: Node) -> bool:
	if cleared: return false
	if unsealed:
		if Geometry2D.get_closest_point_to_segment(alcove_pos, prev_pos, pip_pos).distance_to(alcove_pos) <= radius + ALCOVE_RADIUS:
			claim_alcove()
			return true
		return false
	if Geometry2D.get_closest_point_to_segment(ped_pos, prev_pos, pip_pos).distance_to(ped_pos) <= radius + PED_RADIUS:
		var fresh_p: bool = _ped_charge <= CHARGE_WINDOW_S - 0.45
		_ped_charge = CHARGE_WINDOW_S
		if fresh_p:
			_burst_light(ped_pos, 64.0, 1.20, 0.36); _emit_sfx("pip_tag", ped_pos, true)
		if _bell_charge > 0.0: _unseal_alcove()
		elif fresh_p and _nar_cd <= 0.0:
			_nar_cd = 2.5
			if Lx.events != null: Lx.events.narration_requested.emit("PIP_SHRINE_CHARGE", "narration", 2.4)
		queue_redraw(); return true
	if Geometry2D.get_closest_point_to_segment(bell_pos, prev_pos, pip_pos).distance_to(bell_pos) <= radius + BELL_RADIUS:
		var fresh_b: bool = _bell_charge <= CHARGE_WINDOW_S - 0.45
		_bell_charge = CHARGE_WINDOW_S
		if fresh_b:
			_burst_light(bell_pos, 64.0, 1.20, 0.36); _emit_sfx("pip_bloom", bell_pos, true)
		if _ped_charge > 0.0: _unseal_alcove()
		elif fresh_b and _nar_cd <= 0.0:
			_nar_cd = 2.5
			if Lx.events != null: Lx.events.narration_requested.emit("PIP_SHRINE_BELL", "narration", 2.4)
		queue_redraw(); return true
	return false

func try_interact(_actor: Node, actor_pos: Vector2, reach: float = 24.0) -> bool:
	if unsealed and not cleared and actor_pos.is_finite() and actor_pos.distance_to(alcove_pos) <= reach + ALCOVE_RADIUS:
		return claim_alcove()
	return false

func get_interact_prompt_info(actor_pos: Vector2, reach: float = 24.0) -> Dictionary:
	if unsealed and not cleared and actor_pos.is_finite() and actor_pos.distance_to(alcove_pos) <= reach + ALCOVE_RADIUS:
		return {"prompt": "PIP_SHRINE_PROMPT", "pos": alcove_pos}
	return {}

func claim_alcove() -> bool:
	if cleared: return false
	unsealed = true; cleared = true; _burst_t = 1.0
	var res: Dictionary = LxFireflyState.complete_shrine(shrine_id, charm_id)
	if Lx.state != null:
		Lx.state.add_shards(45)
		Lx.state.hearts = minf(float(Lx.state.max_hearts), Lx.state.hearts + 0.5)
	elif Lx.events != null:
		Lx.events.shard_collected.emit(45)
	if Lx.events != null:
		Lx.events.player_healed.emit(0.5)
		Lx.events.save_requested.emit("pip_shrine")
	_burst_light(alcove_pos, 108.0, 1.35, 0.65)
	_emit_sfx("pip_bond_up", alcove_pos, false)
	var spec: Dictionary = LxFireflyState.get_charm_spec(charm_id)
	var name_key: String = str(spec.get("name_key", ""))
	var desc_key: String = str(spec.get("desc_key", ""))
	var nar: Object = Lx.ui.get("narration") as Object if (Lx.ui != null and Lx.ui.get("narration") is Object) else null
	if nar != null and is_instance_valid(nar) and nar.has_method("say_lines") and not name_key.is_empty():
		var lines := PackedStringArray([LxStrings.fmt("PIP_SHRINE_CLEAR_FMT", [LxStrings.text(name_key)])])
		if not desc_key.is_empty(): lines.append(LxStrings.text(desc_key))
		nar.call("say_lines", lines, "title", 3.6, -1.0, 1, "title")
	elif Lx.events != null:
		Lx.events.narration_requested.emit("PIP_SHRINE_UNSEAL", "title", 3.0)
	if bool(res.get("ranked_up", false)):
		var hud: Object = Lx.ui.get("hud") as Object if (Lx.ui != null and Lx.ui.get("hud") is Object) else null
		if hud != null and is_instance_valid(hud) and hud.has_method("spawn_world_cue"):
			hud.call("spawn_world_cue", "PIP_BOND_UP_FMT", alcove_pos + Vector2(0.0, -16.0), "gold", 2.2, [int(res.get("rank", LxFireflyState.get_bond_rank()))])
	queue_redraw()
	return true

func find_nearest_sense_target(from_pos: Vector2, max_dist: float) -> Vector2:
	if cleared: return Vector2.INF
	var target: Vector2 = alcove_pos if unsealed else (bell_pos if _ped_charge > 0.0 else ped_pos)
	return target if from_pos.distance_to(target) <= max_dist else Vector2.INF

func get_light_pools() -> Array[Vector4]:
	return [
		Vector4(ped_pos.x, ped_pos.y - 6.0, 52.0 if (_ped_charge > 0.0 or unsealed) else 34.0, 0.92 if (_ped_charge > 0.0 or unsealed) else 0.56),
		Vector4(bell_pos.x, bell_pos.y - 7.0, 52.0 if (_bell_charge > 0.0 or unsealed) else 34.0, 0.92 if (_bell_charge > 0.0 or unsealed) else 0.56),
		Vector4(alcove_pos.x, alcove_pos.y - 6.0, 74.0 if (unsealed and not cleared) else (54.0 if cleared else 32.0), 1.12 if (unsealed and not cleared) else (0.85 if cleared else 0.50)),
	]

func _unseal_alcove() -> void:
	if unsealed or cleared: return
	unsealed = true; _burst_t = 0.85
	_burst_light(alcove_pos, 96.0, 1.28, 0.55); _emit_sfx("pip_bloom", alcove_pos, true)
	if Lx.events != null: Lx.events.narration_requested.emit("PIP_SHRINE_UNSEAL", "title", 2.8)
	queue_redraw()

func _burst_light(at_p: Vector2, rad: float, intensity: float, dur: float) -> void:
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(at_p, rad, intensity * (0.65 if LxHudFx.flash_reduced() else 1.0), dur)

func _emit_sfx(sfx_id: String, at_p: Vector2, spatial: bool) -> void:
	if Lx.events != null: Lx.events.sfx_requested.emit(sfx_id, at_p, spatial)

func _draw() -> void:
	var fred: bool = LxHudFx.flash_reduced()
	if not cleared: _draw_sightline(ped_pos + Vector2(0.0, -6.0), bell_pos + Vector2(0.0, -7.0), fred)
	_draw_pedestal(fred)
	_draw_bell(fred)
	_draw_alcove(fred)

func _draw_sightline(a: Vector2, b: Vector2, fred: bool) -> void:
	var pal: Dictionary = LxPalette.PAL
	var delta: Vector2 = b - a; var dist: float = delta.length()
	if dist < 8.0: return
	var sdir: Vector2 = delta / dist
	var active: bool = _ped_charge > 0.0 or _bell_charge > 0.0 or unsealed
	var cursor: float = 0.0 if (fred and not active) else fmod(_clock * (8.0 if fred else (18.0 if active else 7.0)), 8.0)
	var k: int = 0
	var c0: Color = (pal["lime"] as Color) if active else LxBiomePalette.col(island_id, "mid")
	var c1: Color = (pal["gold"] if active else pal["dusk"]) as Color
	while cursor < dist:
		var pt: Vector2 = (a + sdir * cursor).round()
		draw_rect(Rect2(pt - Vector2.ONE, Vector2(3.0, 3.0)), pal["void"] as Color)
		draw_rect(Rect2(pt, Vector2.ONE), c0 if (k % 2 == 0) else c1)
		cursor += 8.0; k += 1

func _draw_pedestal(fred: bool) -> void:
	var pal: Dictionary = LxPalette.PAL; var void_c: Color = pal["void"] as Color
	var p: Vector2 = ped_pos.round(); var lit_p: bool = _ped_charge > 0.0 or unsealed
	var rune_c: Color = (pal["lime"] as Color) if lit_p else LxBiomePalette.col(island_id, "hi")
	draw_rect(Rect2(p + Vector2(-7.0, -10.0), Vector2(14.0, 13.0)), void_c)
	draw_rect(Rect2(p + Vector2(-6.0, -2.0), Vector2(12.0, 4.0)), pal["dusk"] as Color)
	draw_rect(Rect2(p + Vector2(-5.0, -9.0), Vector2(10.0, 8.0)), pal["night"] as Color)
	draw_rect(Rect2(p + Vector2(-4.0, -9.0), Vector2(8.0, 2.0)), (pal["stone"] if lit_p else pal["mauve"]) as Color)
	draw_rect(Rect2(p + Vector2(-3.0, -6.0), Vector2(6.0, 4.0)), LxBiomePalette.col(island_id, "dark"))
	draw_rect(Rect2(p + Vector2(-1.0, -6.0), Vector2(2.0, 4.0)), rune_c)
	draw_rect(Rect2(p + Vector2(-2.0, -5.0), Vector2(4.0, 2.0)), rune_c)
	draw_rect(Rect2(p + Vector2(0.0, -5.0), Vector2.ONE), (pal["cream"] if (lit_p or fred) else pal["gold"]) as Color)
	if not unsealed and _ped_charge > 0.0:
		var frac: float = clampf(_ped_charge / CHARGE_WINDOW_S, 0.0, 1.0)
		draw_arc(p + Vector2(0.0, -5.0), 10.0, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(p + Vector2(0.0, -5.0), 10.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, (pal["coral"] if frac < 0.25 else pal["lime"]) as Color, 1.0)

func _draw_bell(fred: bool) -> void:
	var pal: Dictionary = LxPalette.PAL; var void_c: Color = pal["void"] as Color
	var lit_b: bool = _bell_charge > 0.0 or unsealed
	var bob: float = 0.0 if fred else roundf(sin(_clock * (6.0 if lit_b else 2.8)) * 1.0)
	var c: Vector2 = (bell_pos + Vector2(0.0, -7.0 + bob)).round()
	draw_rect(Rect2(bell_pos.round() + Vector2(-3.0, 1.0), Vector2(6.0, 2.0)), void_c)
	if not unsealed and _bell_charge > 0.0:
		var frac: float = clampf(_bell_charge / CHARGE_WINDOW_S, 0.0, 1.0)
		draw_arc(c, 9.0, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(c, 9.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, (pal["coral"] if frac < 0.25 else pal["gold"]) as Color, 1.0)
	draw_rect(Rect2(c + Vector2(-4.0, -4.0), Vector2(9.0, 8.0)), void_c)
	draw_rect(Rect2(c + Vector2(-5.0, 1.0), Vector2(11.0, 3.0)), void_c)
	draw_rect(Rect2(c + Vector2(-3.0, -3.0), Vector2(7.0, 6.0)), (pal["gold"] if lit_b else pal["apricot"]) as Color)
	draw_rect(Rect2(c + Vector2(-4.0, 2.0), Vector2(9.0, 1.0)), (pal["gold"] if lit_b else pal["apricot"]) as Color)
	draw_rect(Rect2(c + Vector2(-1.0, -3.0), Vector2(2.0, 4.0)), (pal["cream"] if lit_b else pal["lime"]) as Color)
	draw_rect(Rect2(c + Vector2(0.0, 3.0), Vector2.ONE), (pal["cream"] if lit_b else pal["gold"]) as Color)

func _draw_alcove(fred: bool) -> void:
	var pal: Dictionary = LxPalette.PAL; var void_c: Color = pal["void"] as Color
	var a: Vector2 = alcove_pos.round()
	draw_rect(Rect2(a + Vector2(-8.0, -14.0), Vector2(16.0, 17.0)), void_c)
	draw_rect(Rect2(a + Vector2(-7.0, -13.0), Vector2(14.0, 15.0)), pal["night"] as Color)
	draw_rect(Rect2(a + Vector2(-6.0, -12.0), Vector2(12.0, 2.0)), LxBiomePalette.col(island_id, "hi") if unsealed else (pal["plum"] as Color))
	draw_rect(Rect2(a + Vector2(-6.0, -1.0), Vector2(12.0, 3.0)), pal["dusk"] as Color)
	if not unsealed:
		draw_rect(Rect2(a + Vector2(-5.0, -10.0), Vector2(10.0, 9.0)), pal["dusk"] as Color)
		draw_rect(Rect2(a + Vector2(-4.0, -9.0), Vector2(8.0, 7.0)), LxBiomePalette.col(island_id, "ward_a"))
		draw_rect(Rect2(a + Vector2(-1.0, -9.0), Vector2(2.0, 7.0)), void_c)
		draw_rect(Rect2(a + Vector2(-4.0, -6.0), Vector2(8.0, 2.0)), void_c)
		draw_rect(Rect2(a + Vector2(-1.0, -6.0), Vector2(2.0, 2.0)), LxBiomePalette.col(island_id, "ward_b"))
	elif not cleared:
		var pulse: bool = fred or (int(floorf(_clock * 4.5)) % 2 == 0)
		var lift: float = 0.0 if fred else roundf(sin(_clock * 3.8) * 1.0)
		draw_rect(Rect2(a + Vector2(-4.0, -9.0), Vector2(8.0, 8.0)), pal["pine"] as Color)
		draw_rect(Rect2(a + Vector2(-3.0, -7.0 + lift), Vector2(6.0, 4.0)), pal["gold"] as Color)
		draw_rect(Rect2(a + Vector2(-2.0, -8.0 + lift), Vector2(4.0, 4.0)), (pal["lime"] if pulse else pal["gold"]) as Color)
		draw_rect(Rect2(a + Vector2(-1.0, -7.0 + lift), Vector2(2.0, 2.0)), pal["cream"] as Color)
		draw_rect(Rect2(a + Vector2(-2.0, -3.0), Vector2(4.0, 2.0)), pal["apricot"] as Color)
	else:
		draw_rect(Rect2(a + Vector2(-4.0, -9.0), Vector2(8.0, 8.0)), LxBiomePalette.col(island_id, "dark"))
		draw_rect(Rect2(a + Vector2(-2.0, -7.0), Vector2(4.0, 5.0)), LxBiomePalette.col(island_id, "glow"))
		draw_rect(Rect2(a + Vector2(-1.0, -6.0), Vector2(2.0, 3.0)), pal["gold"] as Color)
		draw_rect(Rect2(a + Vector2(0.0, -6.0), Vector2.ONE), pal["cream"] as Color)
	if _burst_t > 0.0:
		var u: float = 1.0 - clampf(_burst_t, 0.0, 1.0)
		var r: float = roundf(lerpf(6.0, 28.0, u))
		draw_arc(a + Vector2(0.0, -6.0), r, 0.0, TAU, 18, void_c, 3.0)
		draw_arc(a + Vector2(0.0, -6.0), r, 0.0, TAU, 18, (pal["cream"] if u < 0.35 else pal["lime"]) as Color, 2.0)
