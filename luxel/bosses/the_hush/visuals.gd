extends RefCounted
## Greybox 20-colour Last Light visuals for LxTheHushBoss (keeps brain.gd <= 400 lines).

static func draw_hush(b: LxEnemyBrain, off: Vector2) -> void:
	var pal: Dictionary = LxEnemyBrain.PAL
	var phase: int = b.phase
	var r: float = b.body_radius
	# Crown of the Hush: 4 phase sigil pips orbiting the dark core
	for i: int in range(4):
		var pip: Vector2 = off + Vector2.from_angle(b.anim_t * 1.6 + float(i) * (TAU * 0.25)) * (r + 5.0)
		b.draw_circle(pip, 2.0, (pal["gold"] as Color) if i < phase else (pal["dusk"] as Color))

	var veil_intact: bool = bool(b.get("veil_intact"))
	var lens_lit_t: float = float(b.get("lens_lit_t"))
	if veil_intact:
		b.draw_arc(off, r + 3.0, 0.0, TAU, 24, (pal["ice"] as Color) if lens_lit_t > 0.0 else (pal["plum"] as Color), 2.2)

	if bool(b.get("void_orb_out")):
		var orb_off: Vector2 = (b.get("void_orb_pos") as Vector2) - b.pos
		b.draw_line(off, orb_off, pal["sky"] as Color, 1.2)
		b.draw_circle(orb_off, 4.0, pal["deep"] as Color)
		b.draw_circle(orb_off, 2.0, pal["ice"] as Color)

	var active_move: int = int(b.get("active_move"))
	var commit_dir: Vector2 = b.get("commit_dir") as Vector2
	var sweep_start: float = float(b.get("sweep_start_ang"))
	var sweep_sign: float = float(b.get("sweep_sign"))
	var beam_ang: float = float(b.get("beam_angle"))
	var ring_stage: int = int(b.get("ring_stage"))
	var ring_prog: float = float(b.get("ring_progress"))

	if b.state == LxEnemyBrain.State.TELL:
		var prog: float = 1.0 - clampf(b.state_timer / maxf(b.last_tell_duration, 0.05), 0.0, 1.0)
		if active_move == 3: # SILENCE_RING
			b.draw_arc(off, lerpf(84.0, 20.0, prog), 0.0, TAU, 28, pal["ice"] as Color, 1.8)
		elif active_move == 4: # ECLIPSE_BEAM
			b.draw_line(off, off + Vector2.from_angle(sweep_start) * 158.0, pal["gold"] as Color, 1.5)
			b.draw_line(off, off + Vector2.from_angle(sweep_start + sweep_sign * 1.45) * 158.0, pal["coral"] as Color, 1.0)
		else:
			b.draw_line(off, off + commit_dir * 64.0, pal["ice"] as Color, 1.8)
	elif b.state == LxEnemyBrain.State.COMMIT:
		if active_move == 3 and ring_stage != 1:
			var ring_r: float = lerpf(12.0, 84.0, ring_prog)
			b.draw_arc(off, ring_r, 0.0, TAU, 32, pal["sky"] as Color, 3.5)
			b.draw_arc(off, maxf(2.0, ring_r - 2.5), 0.0, TAU, 24, pal["cream"] as Color, 1.4)
		elif active_move == 4:
			var bend: Vector2 = off + Vector2.from_angle(beam_ang) * 158.0
			b.draw_line(off, bend, pal["coral"] as Color, 4.5)
			b.draw_line(off, bend, pal["cream"] as Color, 1.8)
		elif active_move == 0: # VOLLEY
			b.draw_line(off, off + commit_dir * 152.0, pal["ice"] as Color, 2.0)
	elif bool(b.get("_roaring")):
		b.draw_arc(off, r + 15.0, 0.0, TAU, 26, pal["gold"] as Color, 2.5)
