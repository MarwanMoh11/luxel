extends SceneTree
## Live gameplay capture for The Undercroft vertical proof (30 fps PNG sequence -> .mp4).
## Run: Godot --path . --always-on-top --resolution 320x180 --script res://luxel/islands/1/undercroft/uc_qa_capture.gd -- clip=<r9_choir|r11_sexton> out=<rel_dir>

const MAIN_SCENE_PATH: String = "res://luxel/luxel.tscn"
const DT: float = 1.0 / 60.0
const SUBSTEPS: int = 2

var _clip: String = "r9_choir"
var _out_rel: String = ".swarm/renders/clip_r9"
var _frames: int = 195
var _main: Node = null
var _runner: Node = null
var _phase_bumped: bool = false
var _p3_bumped: bool = false
var _dash_cd: int = 0


func _initialize() -> void:
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with("clip="):
			_clip = raw.get_slice("=", 1).strip_edges().to_lower()
		elif raw.begins_with("out="):
			_out_rel = raw.get_slice("=", 1).strip_edges().trim_prefix("res://").trim_suffix("/")
		elif raw.begins_with("frames="):
			_frames = clampi(int(raw.get_slice("=", 1).strip_edges()), 30, 480)
	_runner = Node.new()
	_runner.name = "UcQaCaptureRunner"
	root.add_child(_runner)
	call_deferred("_run")


func _force_play_flow() -> void:
	if _main != null and is_instance_valid(_main) and int(_main.get("flow")) != 2:
		_main.set("flow", 2)
		if Lx.audio != null:
			Lx.audio.set_paused(false)
		_main.call("_sync_ui_flow")


func _run() -> void:
	Lx.load_all_data()
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	_runner.add_child(_main)
	await process_frame
	Lx.save.setup(true)
	Lx.save.delete_slot(1)
	_main.call("start_new_game", 1, false)
	if Lx.input != null:
		Lx.input.set_synthetic(true, Vector2.ZERO, Vector2.RIGHT)
	_force_play_flow()
	_main.set_physics_process(false)

	var abs_dir: String = ProjectSettings.globalize_path("res://" + _out_rel)
	if DirAccess.make_dir_recursive_absolute(abs_dir) != OK:
		push_error("UC QA CAPTURE: failed to create " + abs_dir)
		_cleanup_and_quit(1)
		return
	if not _setup_clip():
		push_error("UC QA CAPTURE: setup failed for " + _clip)
		_cleanup_and_quit(1)
		return

	var wick: LxWick = Lx.player as LxWick
	var world: LxRegionLoader = Lx.world as LxRegionLoader
	var saved: int = 0
	for f: int in range(_frames):
		_choreograph(f, wick, world)
		_step_sim(SUBSTEPS)
		_clear_narration()
		_force_play_flow()
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			if img.save_png("%s/frame_%04d.png" % [abs_dir, f + 1]) == OK:
				saved += 1
	print("UC QA CAPTURE %s: clip=%s frames=%d/%d dir=%s" % [
		"PASS" if saved == _frames else "FAIL", _clip, saved, _frames, _out_rel
	])
	_cleanup_and_quit(0 if saved == _frames else 1)


func _prepare_room(reg: String) -> bool:
	Lx.state.opened_doors.clear()
	Lx.state.broken_seals.clear()
	Lx.state.claimed_shrines.clear()
	Lx.state.defeated_bosses.clear()
	Lx.state.relit_islands.clear()
	Lx.state.interactable_states.clear()
	Lx.state.collected_keys.clear()
	Lx.state.story_flags.clear()
	Lx.state.unlocked_moves.clear()
	Lx.state.story_flags["lantern_picked_up"] = true
	Lx.state.story_flags["item_echo_clapper"] = true
	Lx.state.unlock_move("bolt")
	Lx.state.unlock_move("dash")
	Lx.state.unlock_move("throw")
	Lx.state.max_hearts = 5
	Lx.state.heal_full()
	if not bool(_main.call("load_island_region", 1, reg)):
		return false
	var wick: LxWick = Lx.player as LxWick
	if wick != null:
		wick.god = true
		wick.sync_unlocks_from_state()
	_step_sim(8)
	_clear_hud()
	return true


func _place_wick(pos: Vector2, aim: Vector2) -> void:
	var wick: LxWick = Lx.player as LxWick
	var a: Vector2 = aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
	if Lx.input != null:
		Lx.input.set_synthetic(true, Vector2.ZERO, a)
	if wick != null:
		wick.god = true
		wick.reset_for_room(pos)
		wick.facing = a
		wick.sync_unlocks_from_state()
	if Lx.camera != null and Lx.world != null:
		Lx.camera.set_bounds((Lx.world as LxRegionLoader).get_bounds(), false)
		Lx.camera.snap_to(pos)


func _setup_clip() -> bool:
	_phase_bumped = false
	_p3_bumped = false
	_dash_cd = 0
	if _clip == "r9_choir":
		if not _prepare_room("undercroft_r9"):
			return false
		var w: LxRegionLoader = Lx.world as LxRegionLoader
		# Place baffle already half-pushed so viewer sees final shove + Echo Clapper Dawn -> Dusk Freeze -> Dawn Echo -> crossing!
		var blk: LxInteractable = w.find_interactable("blk_r9_baffle")
		if blk != null:
			blk.pos = Vector2(104.0, 240.0)
			blk.position = blk.pos.round()
		_place_wick(Vector2(96.0, 152.0), Vector2.LEFT)
		return true
	if _clip == "r11_sexton":
		if not _prepare_room("undercroft_r11"):
			return false
		_place_wick(Vector2(152.0, 224.0), Vector2(0.7, -0.7))
		return true
	return false


func _choreograph(f: int, w: LxWick, world: LxRegionLoader) -> void:
	if w == null or world == null:
		return
	if _clip == "r9_choir":
		# f 0..10: aim at Dawn Bell (64, 152) and THROW lantern (arms 1.4s Echo Clapper!)
		if f < 8:
			_set_in(Vector2(96.0, 152.0) - w.global_position, Vector2(64.0, 152.0) - w.global_position)
		elif f == 8:
			_set_in(Vector2.ZERO, Vector2(64.0, 152.0) - w.global_position)
			w.press_throw()
		elif f == 16:
			# Recall lantern immediately while Echo countdown spins on Dawn Bell!
			w.press_throw()
		elif f > 18 and f < 34:
			# Hustle south to (104, 224) aimed at Center Dusk Bell (248, 224)
			_set_in(Vector2(104.0, 224.0) - w.global_position, Vector2(248.0, 224.0) - w.global_position)
		elif f == 34:
			# Bolt Dusk Bell -> cyan Dusk wave freezes F2 in bridge slot just before t=1.4s Dawn Echo!
			_set_in(Vector2.ZERO, Vector2(248.0, 224.0) - w.global_position)
			w.press_fire()
		elif f == 36:
			w.release_fire()
		elif f >= 38 and f < 58:
			# Hold & watch Dawn Echo fire at ~f=50 while F2 stays frozen and F1 slides into North Bridge!
			_set_in(Vector2(104.0, 296.0) - w.global_position, Vector2.RIGHT)
		elif f >= 58 and f < 110:
			# Run across South Catwalk to Center Pier (280, 296)
			_set_in(Vector2(280.0, 296.0) - w.global_position, Vector2.RIGHT)
		elif f >= 110 and f < 142:
			# Head north up Center Pier to F2 bridge lane (288, 200)
			_set_in(Vector2(288.0, 200.0) - w.global_position, Vector2.UP)
		elif f >= 142 and f < 185:
			# Cross F2 coffin bridge to East Reliquary Pier (456, 200)!
			_set_in(Vector2(456.0, 200.0) - w.global_position, Vector2.RIGHT)
		else:
			_set_in(Vector2.ZERO, Vector2.UP)
		return

	if _clip == "r11_sexton":
		var boss: LxEnemyBrain = _find_boss(world)
		if boss == null:
			_set_in(Vector2.ZERO, Vector2.UP)
			return
		# f 0..24: move toward West Dawn Bell & throw lantern to ring Sanctuary Bell!
		if f < 12:
			_set_in(Vector2(116.0, 176.0) - w.global_position, Vector2(64.0, 176.0) - w.global_position)
		elif f == 12:
			_set_in(Vector2.ZERO, Vector2(64.0, 176.0) - w.global_position)
			w.press_throw()
		elif f == 22:
			w.press_throw()
		elif f < 110:
			# Active combat duel around Sexton + trigger P2 cross-trench at f=55!
			if not _phase_bumped and f == 55:
				_phase_bumped = true
				boss.hp = boss.max_hp * 0.54
				if boss.has_method("_enter_phase"):
					boss.call("_enter_phase", 2)
			var to_b: Vector2 = boss.pos - w.global_position
			var dir_b: Vector2 = to_b.normalized() if to_b.length_squared() > 0.01 else Vector2.UP
			var strafe: Vector2 = Vector2(-dir_b.y, dir_b.x) * (1.0 if (f / 36) % 2 == 0 else -1.0)
			var mv: Vector2 = (strafe + dir_b * clampf((to_b.length() - 72.0) / 34.0, -0.8, 0.7)).normalized()
			_set_in(mv, dir_b)
			_dash_cd = maxi(0, _dash_cd - 1)
			if _dash_cd == 0 and (boss.state == LxEnemyBrain.State.COMMIT or (boss.state == LxEnemyBrain.State.TELL and boss.state_timer <= 0.16)):
				w.press_dash()
				_dash_cd = 26
			elif _dash_cd == 20:
				w.release_dash()
			if f % 12 == 4 and not w.is_dashing():
				w.press_fire()
			elif f % 12 == 6:
				w.release_fire()
		else:
			# f 110+: trigger P3 coffin shield & ring East War Sanctuary Bell (416, 176) to shatter it!
			if not _p3_bumped and f == 112:
				_p3_bumped = true
				boss.hp = boss.max_hp * 0.28
				if boss.has_method("_enter_phase"):
					boss.call("_enter_phase", 3)
			if f < 145:
				_set_in(Vector2(356.0, 176.0) - w.global_position, Vector2(416.0, 176.0) - w.global_position)
			elif f == 145:
				_set_in(Vector2.ZERO, Vector2(416.0, 176.0) - w.global_position)
				w.press_throw()
			elif f == 156:
				w.press_throw()
			else:
				var to_b2: Vector2 = boss.pos - w.global_position
				var dir_b2: Vector2 = to_b2.normalized() if to_b2.length_squared() > 0.01 else Vector2.LEFT
				_set_in(Vector2(-dir_b2.y, dir_b2.x) * 0.7, dir_b2)
				if f % 10 == 2:
					w.press_fire()
				elif f % 10 == 4:
					w.release_fire()


func _set_in(move_v: Vector2, aim_v: Vector2) -> void:
	var m: Vector2 = move_v.normalized() if move_v.length_squared() > 1.0 else move_v
	var a: Vector2 = aim_v.normalized() if aim_v.length_squared() > 0.001 else Vector2.RIGHT
	if Lx.input != null:
		Lx.input.set_synthetic(true, m, a)


func _find_boss(world: LxRegionLoader) -> LxEnemyBrain:
	for e: LxEnemyBrain in world.get_enemies():
		if is_instance_valid(e) and e.is_alive() and (e.is_boss or not e.boss_id.is_empty()):
			return e
	return null


func _step_sim(steps: int) -> void:
	for _k: int in range(steps):
		_force_play_flow()
		_main.call("step_sim", DT)
		if Lx.ui != null:
			var hud_n: Node = Lx.ui.get("hud") as Node
			if hud_n != null and hud_n.has_method("_process"):
				hud_n.call("_process", DT)


func _clear_hud() -> void:
	if Lx.ui == null:
		return
	var hud: Node = Lx.ui.get("hud") as Node
	if hud != null and hud.has_method("clear_cues"):
		hud.call("clear_cues")
	_clear_narration()


func _clear_narration() -> void:
	if Lx.ui == null:
		return
	var nar: Node = Lx.ui.get("narration") as Node
	if nar != null and nar.has_method("clear_all"):
		nar.call("clear_all")


func _cleanup_and_quit(code: int) -> void:
	if Lx.input != null:
		Lx.input.set_synthetic(false)
	if Lx.save != null:
		Lx.save.delete_slot(1)
	if _main != null and is_instance_valid(_main):
		_runner.remove_child(_main)
		_main.free()
		_main = null
	Lx.reset()
	quit(code)
