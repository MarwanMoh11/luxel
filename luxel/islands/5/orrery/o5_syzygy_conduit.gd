class_name LxO5SyzygyConduit
extends LxToy
## Island 5 Grand Orrery (orrery_r16): Syzygy Bridge alignment glyph.
## Monitors the 3 syzygy star_nodes (including the Lens-only center star); when all 3
## are lit together, emits its signal to raise the golden ascension bridge to orrery_r10.

var star_ids: PackedStringArray = PackedStringArray()
var aligned: bool = false
var _synced: bool = false
var _sets_flag: String = "o5_r16_syzygy"
var _pulse_t: float = 0.0
var _align_fx_t: float = 0.0


func _toy_setup() -> void:
	kind = "o5_syzygy_conduit"
	radius = 18.0
	_sets_flag = str(props.get("sets_flag", "o5_r16_syzygy"))
	star_ids = PackedStringArray()
	var raw_stars: Variant = props.get("stars", [])
	if raw_stars is Array:
		for sv: Variant in (raw_stars as Array):
			var sid: String = str(sv).strip_edges()
			if not sid.is_empty():
				star_ids.append(sid)
	aligned = Lx.state != null and not _sets_flag.is_empty() and bool(Lx.state.story_flags.get(_sets_flag, false))
	_synced = false
	_align_fx_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	_pulse_t += dt
	if _align_fx_t > 0.0:
		_align_fx_t = maxf(0.0, _align_fx_t - dt)
	if aligned and not _synced:
		_synced = true
		_notify_linked_targets(true)
	if not aligned and _all_stars_lit():
		aligned = true
		_synced = true
		_align_fx_t = 0.55
		if Lx.state != null and not _sets_flag.is_empty():
			Lx.state.story_flags[_sets_flag] = true
		_emit_sfx("o5_syzygy_chord")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.12)
			if LxStrings.has_id("I5_OR_SYZYGY_LIT"):
				Lx.events.narration_requested.emit("I5_OR_SYZYGY_LIT", "title", 2.8)
		_notify_linked_targets(true)
	queue_redraw()


func _all_stars_lit() -> bool:
	if region == null or star_ids.is_empty():
		return false
	for sid: String in star_ids:
		var it: LxInteractable = region.find_interactable(sid)
		if it == null or not bool(it.get("lit")):
			return false
	return true


func _draw() -> void:
	if not visible:
		return
	var pal: Dictionary = LxPalette.PAL
	var fr: bool = LxHudFx.flash_reduced()
	var gold: Color = pal["gold"] as Color
	var cream: Color = pal["cream"] as Color
	var sky: Color = pal["sky"] as Color
	var ice: Color = pal["ice"] as Color
	var deep: Color = pal["deep"] as Color
	var void_c: Color = pal["void"] as Color
	var pulse: float = 0.85 if fr else (0.76 + 0.24 * sin(_pulse_t * 3.0))
	var col: Color = gold if aligned else deep
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(col, 0.90 if aligned else 0.80), 1.5)
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 18, Color(cream if aligned else sky, pulse), 1.0)
	var lit_count: int = 0
	if region != null:
		for sid: String in star_ids:
			var it: LxInteractable = region.find_interactable(sid)
			if it == null:
				continue
			var rel: Vector2 = (it.pos - pos).round()
			if bool(it.get("lit")):
				lit_count += 1
				draw_line(Vector2.ZERO, rel, Color(gold if aligned else sky, 0.65 * pulse), 1.5)
				var mid_p: Vector2 = (rel * 0.5).round()
				draw_rect(Rect2(mid_p, Vector2.ONE), Color(cream if aligned else ice, 0.80))
			else:
				# Crisp dashed chalk guide toward unlit syzygy stars for instant puzzle sightline
				var dist: float = rel.length()
				if dist > 4.0:
					var dn: Vector2 = rel / dist
					var cur: float = 14.0
					while cur < dist - 8.0:
						var seg_end: float = minf(cur + 4.0, dist - 8.0)
						draw_line((dn * cur).round(), (dn * seg_end).round(), Color(sky, 0.28), 1.0)
						cur += 9.0
		# Bridge / ascension target sightline thread
		var raw_tgts: Variant = props.get("target_ids", [])
		if raw_tgts is Array:
			for tid_v: Variant in (raw_tgts as Array):
				var tid: String = str(tid_v).strip_edges()
				if tid.is_empty():
					continue
				var tgt: LxInteractable = region.find_interactable(tid)
				if tgt == null:
					continue
				var trel: Vector2 = (tgt.pos - pos).round()
				var tdist: float = trel.length()
				if tdist > 14.0:
					if aligned:
						draw_line(Vector2.ZERO, trel, Color(gold, 0.52 * pulse), 1.0)
					else:
						var tdn: Vector2 = trel / tdist
						var tc: float = 16.0
						while tc < tdist - 8.0:
							draw_line((tdn * tc).round(), (tdn * minf(tc + 3.0, tdist - 8.0)).round(), Color(sky, 0.20), 1.0)
							tc += 9.0
	# Diegetic 0/3..3/3 syzygy completion pips along upper arc
	var n_stars: int = star_ids.size()
	if n_stars > 0:
		for pi: int in range(n_stars):
			var spread: float = float(pi) - float(n_stars - 1) * 0.5
			var pip_p := Vector2(roundf(spread * 7.0), -17.0)
			var is_on: bool = aligned or pi < lit_count
			draw_rect(Rect2(pip_p - Vector2.ONE, Vector2(3.0, 3.0)), void_c)
			draw_rect(Rect2(pip_p, Vector2.ONE), cream if is_on else sky)
			if is_on:
				draw_rect(Rect2(pip_p + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(gold, 0.85))
	if aligned:
		draw_circle(Vector2.ZERO, 4.0, Color(cream, pulse))
	if _align_fx_t > 0.0:
		var u: float = 1.0 - clampf(_align_fx_t / 0.55, 0.0, 1.0)
		var ar: float = 18.0 if fr else roundf(lerpf(14.0, 44.0, u))
		draw_arc(Vector2.ZERO, ar, 0.0, TAU, 24, Color(gold, (1.0 - u) * (0.50 if fr else 0.88)), 1.5)
