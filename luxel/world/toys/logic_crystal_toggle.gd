class_name LxCrystalToggle
extends LxToy
## Two-phase crystal switch (phase 0 = gold diamond, phase 1 = blue square).
## Striking or interacting flips all LxCrystalToggle and LxToggleBlock nodes sharing `group`.
## Props: group (String), phase (int 0|1), cooldown (float), persist (bool), target_id/target_ids.

var group_id: String = "default"
var phase: int = 0
var _init_phase: int = 0
var _cd: float = 0.0
var _flip_t: float = 0.0


func _toy_setup() -> void:
	kind = "crystal_toggle"
	group_id = str(props.get("group", "default")).strip_edges()
	if group_id.is_empty():
		group_id = "default"
	_init_phase = 1 if int(props.get("phase", 1 if powered else 0)) == 1 else 0
	phase = _init_phase
	powered = phase == 1
	radius = maxf(11.0, radius)
	_cd = 0.0
	_flip_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and phase != _init_phase:
		return
	_apply_phase(_init_phase, true)


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _flip_t > 0.0:
		_flip_t = maxf(0.0, _flip_t - dt)
		dirty = true
	if not LxHudFx.flash_reduced():
		if int(floorf(_clock * 4.0)) != int(floorf((_clock - dt) * 4.0)):
			dirty = true
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _cd > 0.0:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		flip_group()
		return true
	return false


func interact(_actor: Node = null) -> bool:
	if not active or _cd > 0.0:
		return false
	flip_group()
	return true


func flip_group() -> void:
	var next_phase: int = 1 - phase
	_cd = maxf(0.12, float(props.get("cooldown", 0.25)))
	_apply_phase(next_phase, true)
	_emit_sfx("crystal_clank" if next_phase == 1 else "mirror_ping")
	_emit_gust(48.0, 32.0)


func set_group_phase(new_phase: int) -> void:
	var p: int = 1 if new_phase == 1 else 0
	if p == phase:
		return
	phase = p
	_flip_t = 0.26
	powered = phase == 1
	queue_redraw()


func _apply_phase(new_phase: int, broadcast: bool) -> void:
	phase = 1 if new_phase == 1 else 0
	_flip_t = 0.26
	powered = phase == 1
	_notify_linked_targets(powered)
	if broadcast and region != null and region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if not (it_v is LxInteractable) or it_v == self:
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it):
				continue
			if it.has_method("set_group_phase") and str(it.get("group_id")) == group_id:
				it.call("set_group_phase", phase)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var boost: float = 14.0 if _flip_t > 0.0 else 0.0
	return Vector4(pos.x, pos.y - 6.0, 36.0 + boost, 0.65)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["phase"] = phase
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("phase"):
		_apply_phase(int(d["phase"]), false)
	queue_redraw()


func _draw() -> void:
	var is_blue: bool = phase == 1
	var c_dark: Color = (PAL["deep"] if is_blue else PAL["wine"]) as Color
	var c_mid: Color = (PAL["blue"] if is_blue else PAL["apricot"]) as Color
	var c_hi: Color = (PAL["ice"] if is_blue else PAL["gold"]) as Color
	var c_cream: Color = PAL["cream"] as Color
	var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.6 + pos.x * 0.05) * 1.0)

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 6.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(-6.0, 0.0, 12.0, 6.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["mauve"] as Color)

	# Crystal prism body (distinct outline & shape between Phase 0 diamond and Phase 1 twin-spire)
	var cy: float = -7.0 + bob
	if not is_blue:
		# Phase 0: Gold Diamond Crystal
		draw_rect(Rect2(-5.0, cy - 2.0, 10.0, 5.0), PAL["void"] as Color)
		draw_rect(Rect2(-3.0, cy - 5.0, 6.0, 11.0), PAL["void"] as Color)
		draw_rect(Rect2(-4.0, cy - 1.0, 8.0, 3.0), c_dark)
		draw_rect(Rect2(-2.0, cy - 4.0, 4.0, 9.0), c_mid)
		draw_rect(Rect2(-1.0, cy - 3.0, 2.0, 6.0), c_hi)
		draw_rect(Rect2(-1.0, cy - 3.0, 1.0, 2.0), c_cream)
	else:
		# Phase 1: Blue Faceted Pillar Crystal (bright sky/ice with twin horizontal ribs)
		draw_rect(Rect2(-5.0, cy - 6.0, 10.0, 11.0), PAL["void"] as Color)
		draw_rect(Rect2(-4.0, cy - 5.0, 8.0, 9.0), c_dark)
		draw_rect(Rect2(-3.0, cy - 4.0, 6.0, 7.0), PAL["sky"] as Color)
		draw_rect(Rect2(-2.0, cy - 3.0, 4.0, 5.0), c_hi)
		draw_rect(Rect2(-2.0, cy - 4.0, 4.0, 1.0), c_cream)
		# Crisp horizontal bar notch for greyscale clarity
		draw_rect(Rect2(-3.0, cy - 1.0, 6.0, 1.0), c_cream)
		draw_rect(Rect2(-3.0, cy + 1.0, 6.0, 1.0), c_dark)

	if _flip_t > 0.0:
		var u: float = 1.0 - clampf(_flip_t / 0.26, 0.0, 1.0)
		draw_arc(Vector2(0.0, cy), roundf(lerpf(5.0, 14.0, u)), 0.0, TAU, 16, c_cream if u < 0.4 else c_hi, 1.0)
	_draw_signal_pulses()
