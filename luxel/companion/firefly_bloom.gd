class_name LxFireflyBloom
extends Node2D
## Glowing Nectar Bloom flower pollinated by Pip (or Wick walking over it).
## Grants +1 Nectar toward Pip's Bond Rank and +15 shards (+5 bonus when pollinated by sent Pip).
## Strictly uses the 20 Last Light colours (LxPalette.PAL) and integer pixel-snapped drawing.

const RADIUS: float = 12.0

var bloom_id: String = ""
var pos: Vector2 = Vector2.ZERO
var island_id: int = 1
var collected: bool = false

var _clock: float = 0.0
var _burst_t: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(p_id: String, p_pos: Vector2, p_island: int) -> void:
	bloom_id = p_id
	pos = p_pos.round()
	island_id = clampi(p_island, 1, 8)
	position = pos
	collected = LxFireflyState.is_bloom_collected(bloom_id)
	_burst_t = 0.0
	_phase = absf(pos.x * 0.031 + pos.y * 0.017)
	name = p_id if not p_id.is_empty() else "FireflyBloom"
	queue_redraw()


func tick(dt: float, player_pos: Vector2) -> void:
	_clock += dt
	if _burst_t > 0.0:
		_burst_t = maxf(0.0, _burst_t - dt)
	if not collected and player_pos.is_finite() and player_pos.distance_to(pos) <= 13.0:
		try_pollinate(false)
	queue_redraw()


func try_pollinate(by_pip: bool) -> bool:
	if collected:
		return false
	collected = true
	_burst_t = 0.85
	var res: Dictionary = LxFireflyState.collect_bloom(bloom_id, 1)
	var shard_gain: int = 20 if by_pip else 15
	if Lx.state != null:
		Lx.state.add_shards(shard_gain)
	elif Lx.events != null:
		Lx.events.shard_collected.emit(shard_gain)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var eff_i: float = 0.85 if LxHudFx.flash_reduced() else 1.25
		LxDarknessLayer.active_instance.add_burst_light(pos, 72.0, eff_i, 0.45)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_bloom", pos, true)
	var bloom_n: int = LxFireflyState.get_bloom_count()
	var hud: Object = Lx.ui.get("hud") as Object if (Lx.ui != null and Lx.ui.get("hud") is Object) else null
	if hud != null and is_instance_valid(hud) and hud.has_method("spawn_world_cue"):
		hud.call("spawn_world_cue", "PIP_BLOOM_FMT", pos + Vector2(0.0, -12.0), "lime", 1.8, [bloom_n])
	if bool(res.get("ranked_up", false)):
		_announce_bond_up(int(res.get("rank", LxFireflyState.get_bond_rank())))
	if Lx.events != null:
		Lx.events.save_requested.emit("pip_bloom")
	queue_redraw()
	return true


func _announce_bond_up(rank: int) -> void:
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_bond_up", pos, false)
	var desc_key: String = LxFireflyState.get_bond_desc_key(rank)
	var nar: Object = Lx.ui.get("narration") as Object if (Lx.ui != null and Lx.ui.get("narration") is Object) else null
	if nar != null and is_instance_valid(nar) and nar.has_method("say_lines"):
		var lines := PackedStringArray([LxStrings.fmt("PIP_BOND_UP_FMT", [rank])])
		if not desc_key.is_empty():
			lines.append(LxStrings.text(desc_key))
		nar.call("say_lines", lines, "title", 3.2, -1.0, 1, "title")
	elif Lx.events != null and not desc_key.is_empty():
		Lx.events.narration_requested.emit(desc_key, "title", 3.0)


func get_light_pool() -> Vector4:
	return Vector4(pos.x, pos.y - 4.0, 38.0 if collected else 32.0, 0.72 if collected else 0.62)


func _draw() -> void:
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var sway: float = 0.0 if fred else roundf(sin(_clock * 2.4 + _phase) * 1.0)
	var petal_hi: Color = LxBiomePalette.col(island_id, "hi")
	var petal_glow: Color = LxBiomePalette.col(island_id, "glow")
	var leaf_c: Color = (pal["jade"] if collected else pal["teal"]) as Color
	var core_c: Color = (pal["cream"] if collected else pal["lime"]) as Color

	# Crisp void-backed base silhouette & leaves
	draw_rect(Rect2(-5.0, 0.0, 10.0, 3.0), void_c)
	draw_rect(Rect2(-4.0, -1.0, 8.0, 3.0), pal["pine"] as Color)
	draw_rect(Rect2(-3.0, -1.0, 2.0, 2.0), leaf_c)
	draw_rect(Rect2(1.0, -1.0, 2.0, 2.0), leaf_c)

	# Stem
	draw_rect(Rect2(-1.0 + sway, -6.0, 3.0, 6.0), void_c)
	draw_rect(Rect2(sway, -6.0, 1.0, 6.0), leaf_c)

	# Blossom cup (bud when uncollected, radiant open bloom when collected)
	var fc := Vector2(sway, -7.0)
	if collected:
		draw_rect(Rect2(fc + Vector2(-5.0, -3.0), Vector2(11.0, 6.0)), void_c)
		draw_rect(Rect2(fc + Vector2(-3.0, -5.0), Vector2(7.0, 10.0)), void_c)
		draw_rect(Rect2(fc + Vector2(-4.0, -2.0), Vector2(9.0, 4.0)), petal_hi)
		draw_rect(Rect2(fc + Vector2(-2.0, -4.0), Vector2(5.0, 8.0)), petal_hi)
		draw_rect(Rect2(fc + Vector2(-2.0, -2.0), Vector2(5.0, 4.0)), petal_glow)
		draw_rect(Rect2(fc + Vector2(-1.0, -1.0), Vector2(3.0, 2.0)), pal["gold"] as Color)
		draw_rect(Rect2(fc, Vector2.ONE), core_c)
	else:
		var pulse_on: bool = fred or (int(floorf(_clock * 3.0 + _phase)) % 2 == 0)
		draw_rect(Rect2(fc + Vector2(-4.0, -3.0), Vector2(9.0, 6.0)), void_c)
		draw_rect(Rect2(fc + Vector2(-3.0, -2.0), Vector2(7.0, 4.0)), petal_hi)
		draw_rect(Rect2(fc + Vector2(-2.0, -3.0), Vector2(5.0, 4.0)), petal_glow)
		draw_rect(Rect2(fc + Vector2(-1.0, -2.0), Vector2(3.0, 2.0)), pal["lime"] as Color if pulse_on else pal["gold"] as Color)
		draw_rect(Rect2(fc + Vector2(0.0, -2.0), Vector2.ONE), pal["cream"] as Color)

	# Gently rising pollen motes (calm under flash_reduced)
	var mote_n: int = 1 if fred else 2
	for i: int in range(mote_n):
		var u: float = fmod(_clock * (0.35 if fred else 0.62) + _phase + float(i) * 0.5, 1.0)
		var mx: float = roundf(sway + sin(_clock * 2.0 + float(i) * 3.1 + _phase) * (2.0 + u * 2.0))
		var my: float = roundf(-10.0 - u * 8.0)
		var mc: Color = (pal["cream"] if u < 0.35 else pal["lime"]) as Color
		draw_rect(Rect2(mx - 1.0, my - 1.0, 3.0, 3.0), void_c)
		draw_rect(Rect2(mx, my, 1.0, 1.0), mc)

	# Pollinate burst ring
	if _burst_t > 0.0:
		var bu: float = 1.0 - clampf(_burst_t / 0.85, 0.0, 1.0)
		var r: float = roundf(lerpf(4.0, 22.0, bu))
		draw_arc(fc, r, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(fc, r, 0.0, TAU, 16, (pal["cream"] if bu < 0.35 else pal["lime"]) as Color, 1.0)
