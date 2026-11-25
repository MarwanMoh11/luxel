class_name LxTrainingDummy
extends LxInteractable
## Wick House Training Dummy: absorbs any player hit, displays floating damage pips,
## and renders a live Tempo (hits/s), DPS, and Combo Streak readout plaque above the post.

const WINDOW_SECS: float = 4.0
const COMBO_TIMEOUT: float = 2.6
const MAX_SAMPLES: int = 256

var _hit_t: float = 0.0
var _recoil_dir: Vector2 = Vector2.RIGHT
var _pips: Array[Dictionary] = [] # {pips, heavy, age, life, dx}
var _samples: Array[Dictionary] = [] # {t: float, dmg: float}
var _sim_t: float = 0.0
var _since_hit: float = 99.0
var _plaque_t: float = 0.0

var total_hits: int = 0
var last_damage: float = 0.0
var combo_streak: int = 0
var tempo_hps: float = 0.0
var live_dps: float = 0.0
var peak_dps: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "training_dummy"
	radius = 11.0
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if not active or hit == null:
		return false
	total_hits += 1
	last_damage = hit.damage
	_hit_t = 0.28
	_since_hit = 0.0
	_plaque_t = 4.5
	combo_streak += 1
	if _samples.size() >= MAX_SAMPLES:
		_samples.remove_at(0)
	_samples.append({"t": _sim_t, "dmg": hit.damage})
	_recompute_tempo()
	_recoil_dir = hit.dir.normalized() if hit.dir.length_squared() > 0.01 else Vector2.RIGHT
	var pip_count: int = clampi(roundi(hit.damage * 4.0), 1, 12)
	_pips.append({
		"pips": pip_count,
		"heavy": hit.is_heavy() or hit.is_blue(),
		"age": 0.0,
		"life": 1.15,
		"dx": float((total_hits % 3) - 1) * 4.0,
	})
	if _pips.size() > 6:
		_pips.remove_at(0)
	_emit_sfx("heavy_hit" if hit.is_heavy() else "bolt_chip")
	if Lx.events != null:
		Lx.events.enemy_hit.emit(self, hit, 1)
	queue_redraw()
	return true


func _recompute_tempo() -> void:
	var cutoff: float = _sim_t - WINDOW_SECS
	while not _samples.is_empty() and float(_samples[0]["t"]) < cutoff:
		_samples.remove_at(0)
	if _samples.is_empty():
		tempo_hps = 0.0
		live_dps = 0.0
		return
	var span: float = maxf(0.5, _sim_t - float(_samples[0]["t"]))
	if _samples.size() == 1:
		span = 1.0
	var sum_d: float = 0.0
	for s: Dictionary in _samples:
		sum_d += float(s["dmg"])
	tempo_hps = float(_samples.size()) / span
	live_dps = sum_d / span
	if live_dps > peak_dps:
		peak_dps = live_dps


func tick(dt: float) -> void:
	super.tick(dt)
	_sim_t += dt
	_since_hit += dt
	var dirty: bool = false
	if _since_hit > COMBO_TIMEOUT and combo_streak > 0:
		combo_streak = 0
		_recompute_tempo()
		dirty = true
	if _plaque_t > 0.0:
		_plaque_t = maxf(0.0, _plaque_t - dt)
		_recompute_tempo()
		dirty = true
	if _hit_t > 0.0:
		_hit_t = maxf(0.0, _hit_t - dt)
		dirty = true
	for i: int in range(_pips.size() - 1, -1, -1):
		_pips[i]["age"] = float(_pips[i]["age"]) + dt
		if float(_pips[i]["age"]) >= float(_pips[i]["life"]):
			_pips.remove_at(i)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	_draw_ground_shadow(7.0, 2.5, Vector2(0.0, 1.0))
	var tilt: float = 0.0
	if _hit_t > 0.0:
		tilt = roundf(sin(_hit_t * 36.0) * 2.5 * signf(_recoil_dir.x if absf(_recoil_dir.x) > 0.1 else 1.0))
	# Post & burlap lantern-target dummy
	draw_rect(Rect2(-2.0, -4.0, 4.0, 6.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-1.0, -3.0, 2.0, 4.0), LxPalette.PAL["dusk"])
	var body_c: Color = LxPalette.PAL["cream"] if _hit_t > 0.20 else LxPalette.PAL["stone"]
	draw_rect(Rect2(-6.0 + tilt, -14.0, 12.0, 10.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-5.0 + tilt, -13.0, 10.0, 8.0), body_c)
	# Crossbar arms & brass bullseye
	draw_rect(Rect2(-9.0 + tilt, -11.0, 18.0, 2.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(-2.0 + tilt, -11.0, 4.0, 4.0), LxPalette.PAL["coral"])
	draw_rect(Rect2(-1.0 + tilt, -10.0, 2.0, 2.0), LxPalette.PAL["gold"])
	# Head lantern cap
	draw_rect(Rect2(-4.0 + tilt, -20.0, 8.0, 6.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-3.0 + tilt, -19.0, 6.0, 4.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(-2.0 + tilt, -18.0, 1.0, 1.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(1.0 + tilt, -18.0, 1.0, 1.0), LxPalette.PAL["gold"])

	# Live Tempo & DPS Readout Plaque
	if _plaque_t > 0.0:
		var pr := Rect2(-32.0, -42.0, 64.0, 18.0)
		draw_rect(pr, LxPalette.PAL["void"])
		draw_rect(pr.grow(-1.0), LxPalette.PAL["night"])
		draw_rect(Rect2(pr.position.x + 1.0, pr.position.y + 1.0, pr.size.x - 2.0, 1.0), LxPalette.PAL["gold"])
		var bpm: int = clampi(roundi(tempo_hps * 60.0), 0, 999)
		var l1: String = "%d BPM x%d" % [bpm, combo_streak]
		var l2: String = "DPS %.1f" % live_dps
		LxPixelFont.draw_centered(self, l1, 0.0, pr.position.y + 3.0, LxPalette.PAL["gold"], 1)
		LxPixelFont.draw_centered(self, l2, 0.0, pr.position.y + 10.0, LxPalette.PAL["cream"], 1)
		# Tempo meter pips along plaque bottom
		var lit_pips: int = clampi(roundi(tempo_hps * 2.0), 0, 8)
		for bi: int in range(8):
			var bc: Color = LxPalette.PAL["coral"] if bi >= 6 else (LxPalette.PAL["gold"] if bi >= 3 else LxPalette.PAL["lime"])
			draw_rect(Rect2(-15.0 + float(bi * 4), pr.end.y - 2.0, 3.0, 1.0), bc if bi < lit_pips else LxPalette.PAL["dusk"])

	# Floating damage pips
	for entry: Dictionary in _pips:
		var age: float = float(entry["age"])
		var life: float = float(entry["life"])
		var u: float = clampf(age / maxf(life, 0.01), 0.0, 1.0)
		var count: int = int(entry["pips"])
		var heavy: bool = bool(entry["heavy"])
		var col: Color = LxPalette.PAL["gold"] if heavy else LxPalette.PAL["cream"]
		if u > 0.72:
			col = LxPalette.PAL["mauve"]
		var py: float = roundf(-25.0 - u * 14.0)
		var row_w: float = float(count * 3 - 1)
		var px0: float = roundf(float(entry["dx"]) - row_w * 0.5)
		draw_rect(Rect2(px0 - 1.0, py - 1.0, row_w + 2.0, 4.0), LxPalette.PAL["void"])
		for p: int in range(count):
			draw_rect(Rect2(px0 + float(p * 3), py, 2.0, 2.0), col)
