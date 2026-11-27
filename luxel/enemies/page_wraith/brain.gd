class_name LxPageWraithBrain
extends LxEnemyBrain
## Island 8 Enemy: Page Wraith (Ambush Trickster / Cover-Dropper | HP 2.5 | Shards 4).
## Torn illuminated folio disguised as a floor rug (1 corner curls every 2.4s — instantly
## exposed if sold:world_anims!). L-hops (tell 0.50s, commit 0.26s) dropping a 16x16
## bolt-blocking Stolen Page, then flattens (recover 1.15s). Beam/Sunflare burns Pages;
## Recall slices through; Throw pins flat!

const CURL_PERIOD: float = 2.40
const SNAP_TELL: float = 0.50
const HOP_COMMIT: float = 0.26
const FLAT_RECOVER: float = 1.15
const HOP_SPEED: float = 152.0
const HOP_HIT_R: float = 20.0
const PAGE_TTL: float = 7.0
const PAGE_HALF: float = 8.0
const NOTICE_TIME: float = 0.22

var _disguised: bool = true
var _curl_t: float = 0.0
var _hop_dir: Vector2 = Vector2.RIGHT
var _hop_perp: Vector2 = Vector2.DOWN
var _hop_elapsed: float = 0.0
var _hop_hit_done: bool = false
var _page_dropped: bool = false
var _pages: Array[Dictionary] = []


func _init() -> void:
	kind = "page_wraith"
	island_id = 8
	max_hp = 2.5
	hp = 2.5
	body_radius = 6.0
	routine_speed = 38.0
	leash_radius = 150.0
	notice_radius = 64.0
	tell_time = SNAP_TELL
	recover_time = FLAT_RECOVER
	give_up_time = 2.1
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_disguised = not _is_world_anims_sold()
	_curl_t = _randf_range(0.0, CURL_PERIOD)
	_hop_dir = Vector2.from_angle(facing)
	_hop_perp = _hop_dir.rotated(PI * 0.5)
	_hop_elapsed = 0.0
	_hop_hit_done = false
	_page_dropped = false
	_pages.clear()


func _is_world_anims_sold() -> bool:
	if ResourceLoader.exists("res://luxel/core/sold_settings.gd"):
		var sc: Variant = ResourceLoader.load("res://luxel/core/sold_settings.gd")
		if sc is GDScript and (sc as GDScript).has_method("current"):
			var inst: Variant = (sc as GDScript).call("current")
			if inst is Object and (inst as Object).has_method("is_sold"):
				return bool((inst as Object).call("is_sold", "world_anims"))
	if Lx.vars != null:
		return bool(Lx.vars.get_var("island:8", "sold_world_anims", false))
	return false


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		_release_token()
		state = State.STAGGER
		state_timer = 2.0
		_emit_sfx("clockwork_chime")
	elif t == "war":
		_disguised = false
		_pages.clear()
		if state == State.ROUTINE:
			_enter_notice()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_fire: bool = src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE
	var is_throw: bool = src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_ZIP
	var is_heavy: bool = bool(h["stagger"]) or is_throw or is_fire

	if is_fire:
		# Beam / Sunflare incinerates all Stolen Pages & scorches wraith!
		if not _pages.is_empty():
			_pages.clear()
			_emit_sfx("bramble_burn")
		dmg *= 1.45
	elif state == State.RECOVER or state == State.STAGGER:
		dmg *= 1.35

	_disguised = false
	var is_opening: bool = is_fire or is_throw or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (105.0 if is_heavy else 28.0)

	if hp <= 0.001:
		opened_kill = is_opening
		_pages.clear()
		_die(hit)
		return HitResult.KILLED

	if is_throw or is_fire or is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.5 if src == LxHit.SOURCE_SUNFLARE else 1.25
		_emit_sfx("paper_snap")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_curl_t = fmod(_curl_t + dt, CURL_PERIOD)
	if _disguised and _is_world_anims_sold():
		_disguised = false
	_tick_pages(dt)

	match state:
		State.ROUTINE:
			if _has_player() and pos.distance_to(_get_wick_pos()) <= notice_radius:
				_disguised = false
				_enter_notice()
		State.NOTICE:
			var to_w: Vector2 = _get_wick_pos() - pos
			if to_w.length() > 0.1:
				_turn_toward(to_w.angle(), 5.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt)
		State.TELL:
			_step_tell(dt)
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.85
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.60
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)


func _step_position(dt: float) -> void:
	if _should_give_up():
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var wp: Vector2 = _get_wick_pos()
	var to_w: Vector2 = wp - pos
	var dist: float = to_w.length()
	if dist > 0.1:
		_turn_toward(to_w.angle(), 3.8, dt)
		if dist > 44.0:
			_move_step(to_w.limit_length(routine_speed * 0.88 * dt), false)

	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN
	if can_tok and cooldown <= 0.0 and _is_on_screen() and dist <= notice_radius + 22.0:
		if _claim_token():
			_hop_dir = to_w.normalized() if dist > 0.1 else Vector2.from_angle(facing)
			_hop_perp = _hop_dir.rotated(PI * 0.5 if int(anim_t * 2.0) % 2 == 0 else -PI * 0.5)
			facing = _hop_dir.angle()
			state = State.TELL
			is_counter_attack = false
			last_tell_duration = _scaled_tell(SNAP_TELL, false, attack_damage)
			state_timer = last_tell_duration
			_hop_elapsed = 0.0
			_hop_hit_done = false
			_page_dropped = false
			_emit_attack_started()
			_emit_sfx("paper_snap")


func _step_tell(dt: float) -> void:
	if state_timer > 0.16 * _assist_tell_scale() and _has_player():
		var to_w: Vector2 = _get_wick_pos() - pos
		if to_w.length() > 0.1:
			_turn_toward(to_w.angle(), 3.2, dt)
			_hop_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = HOP_COMMIT
		_hop_elapsed = 0.0
		_hop_hit_done = false
		_page_dropped = false
		_emit_sfx("page_hop")


func _step_commit(dt: float) -> void:
	_hop_elapsed += dt
	# L-hop: first 60% straight lunge, last 40% sharp perpendicular dart + drops Stolen Page!
	var move_d: Vector2 = _hop_dir if _hop_elapsed < HOP_COMMIT * 0.60 else _hop_perp
	if not _page_dropped and _hop_elapsed >= HOP_COMMIT * 0.55:
		_page_dropped = true
		_drop_stolen_page(pos)
	_move_step(move_d * HOP_SPEED * dt, false)
	if not _hop_hit_done and _has_player() and pos.distance_to(_get_wick_pos()) <= HOP_HIT_R:
		_hop_hit_done = true
		_emit_player_hit(move_d)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, FLAT_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.5:
		pos = home
		state = State.ROUTINE
		_disguised = not _is_world_anims_sold()
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 3.6, dt)
	_move_step(to_h.limit_length(routine_speed * 0.94 * dt), false)


func _drop_stolen_page(at: Vector2) -> void:
	if _pages.size() >= 2:
		_pages.pop_front()
	_pages.append({"pos": at, "ttl": PAGE_TTL})
	_emit_sfx("paper_snap")


func _tick_pages(dt: float) -> void:
	if _pages.is_empty():
		return
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var beam_on: bool = wick_node != null and wick_node.move_beam != null and wick_node.move_beam.beam_vis_t > 0.0
	for i: int in range(_pages.size() - 1, -1, -1):
		var pg: Dictionary = _pages[i]
		pg["ttl"] = float(pg["ttl"]) - dt
		if float(pg["ttl"]) <= 0.0:
			_pages.remove_at(i)
			continue
		var pp: Vector2 = pg["pos"] as Vector2
		# Beam burns Stolen Page instantly!
		if beam_on and Geometry2D.get_closest_point_to_segment(pp, wick_node.move_beam.beam_start, wick_node.move_beam.beam_end).distance_to(pp) <= PAGE_HALF + 4.0:
			_emit_sfx("bramble_burn")
			_pages.remove_at(i)
			continue
		# Non-piercing bolts are blocked by the Stolen Page!
		if wick_node != null:
			for bi: int in range(wick_node.bolts.size() - 1, -1, -1):
				var bv: Variant = wick_node.bolts[bi]
				if bv is Object and not bool(bv.get("is_pierce")):
					var bp: Vector2 = bv.get("pos") as Vector2
					if absf(bp.x - pp.x) <= PAGE_HALF + 2.0 and absf(bp.y - pp.y) <= PAGE_HALF + 2.0:
						wick_node.bolts.remove_at(bi)
						_emit_sfx("paper_snap")
						break


func _should_give_up() -> bool:
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.65
	lost_t = 0.0
	_emit_sfx("paper_snap")


func _body_color() -> Color:
	return PAL["cream"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Subtle corner curl cue every 2.4s (or permanent gold glint if world_anims sold!)
	if state == State.ROUTINE and (_curl_t < 0.35 or not _disguised):
		var gp: Vector2 = (c + Vector2(9.0, -4.0)).round()
		draw_rect(Rect2(gp, Vector2(3.0, 3.0)), PAL["gold"] as Color)
	# Dropped 16x16 bolt-blocking Stolen Pages!
	for pg: Dictionary in _pages:
		var rp: Vector2 = ((pg["pos"] as Vector2) - pos).round()
		draw_rect(Rect2(rp - Vector2(PAGE_HALF, PAGE_HALF), Vector2(16.0, 16.0)), PAL["stone"] as Color)
		draw_rect(Rect2(rp - Vector2(PAGE_HALF - 1.0, PAGE_HALF - 1.0), Vector2(14.0, 14.0)), PAL["cream"] as Color)
		draw_rect(Rect2(rp - Vector2(PAGE_HALF, PAGE_HALF), Vector2(16.0, 16.0)), PAL["night"] as Color, false, 1.0)
		draw_line(rp + Vector2(-4.0, -3.0), rp + Vector2(4.0, -3.0), PAL["gold"] as Color, 1.0)
		draw_line(rp + Vector2(-4.0, 1.0), rp + Vector2(3.0, 1.0), PAL["plum"] as Color, 1.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var knee: Vector2 = _hop_dir * (HOP_SPEED * HOP_COMMIT * 0.60)
		LxBossTelegraphFx.draw_ground_danger_lane(self, Vector2.ZERO, knee, 10.0, prog, anim_t, "gold", "cream")
		LxBossTelegraphFx.draw_ground_danger_lane(self, knee, knee + _hop_perp * (HOP_SPEED * HOP_COMMIT * 0.40), 10.0, prog, anim_t, "coral", "gold")
