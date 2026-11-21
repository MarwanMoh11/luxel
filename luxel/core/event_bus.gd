class_name LxEventBus
extends Node
## Central event bus decoupling AI, player, world, audio, and UI.

signal player_damaged(amount: float, from_pos: Vector2, knock_dir: Vector2, source: String)
signal player_healed(amount: float)
signal player_died()

signal enemy_hit(enemy: Object, hit: Object, result: int)
signal enemy_killed(enemy: Object, kind: String, pos: Vector2, opened_kill: bool)
signal enemy_attack_started(enemy: Object, kind: String, pos: Vector2)
signal enemy_attack_landed(enemy: Object, kind: String, pos: Vector2, dir: Vector2, damage: float)

signal boss_phase_changed(boss_id: String, phase: int)
signal boss_defeated(boss_id: String, island_id: int)

signal lantern_thrown(pos: Vector2, dir: Vector2)
signal lantern_hung(pos: Vector2)
signal lantern_recalled(pos: Vector2)
signal lantern_caught(pos: Vector2)
signal lantern_stolen(thief: Object, pos: Vector2)
signal lantern_dropped(pos: Vector2)
signal lantern_perched_loss(pos: Vector2)
signal lantern_struck(pos: Vector2)

signal move_unlocked(move_id: String)
signal shrine_claimed(shrine_id: String, move_id: String)
signal beacon_lit(island_id: int, beacon_id: String)
signal waystone_lit(island_id: int, waystone_id: String)
signal seal_broken(island_id: int, seal_id: String)
signal great_lamp_relit(island_id: int)
signal region_entered(island_id: int, region_id: String)
signal room_changed(island_id: int, room_id: String)

signal narration_requested(string_id: String, style: String, duration: float)
signal prompt_requested(string_id: String, action_id: String, duration: float)

signal shard_collected(amount: int)
signal ember_piece_collected(total_pieces: int)
signal upgrade_purchased(upgrade_id: String, new_rank: int)

signal pause_toggled(paused: bool)
signal music_mode_requested(mode: String)
signal sfx_requested(sfx_id: String, pos: Vector2, spatial: bool)
signal hitstop_requested(duration: float)
signal shake_requested(intensity: float)
signal save_requested(reason: String)
signal ending_requested(mode: String)
