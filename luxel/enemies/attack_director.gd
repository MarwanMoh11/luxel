class_name LxAttackDirector
extends RefCounted
## Shared encounter attack-token & light-claim coordinator.
## Guarantees peak simultaneous committing attackers <= 1 across all enemies and boss adds.

const DEFAULT_ATTACK_GAP: float = 0.35

var enemies: Array[LxEnemyBrain] = []
var token_holder: LxEnemyBrain = null
var light_claimer: LxEnemyBrain = null
var lead_enemy: LxEnemyBrain = null
var attack_gap: float = 0.0
var attack_gap_duration: float = DEFAULT_ATTACK_GAP
var peak_attackers: int = 0
var peak_claims: int = 0


func register(e: LxEnemyBrain) -> void:
	if e == null:
		return
	if not enemies.has(e):
		e.slot = enemies.size()
		enemies.append(e)


func unregister(e: LxEnemyBrain) -> void:
	if e == null:
		return
	if token_holder == e:
		token_holder = null
		attack_gap = attack_gap_duration
	if light_claimer == e:
		light_claimer = null
	if lead_enemy == e:
		lead_enemy = null
	enemies.erase(e)


func clear() -> void:
	enemies.clear()
	token_holder = null
	light_claimer = null
	lead_enemy = null
	attack_gap = 0.0


func reset_stats() -> void:
	peak_attackers = 0
	peak_claims = 0


func can_claim_token(e: LxEnemyBrain, ignore_gap: bool = false) -> bool:
	if e == null or not is_instance_valid(e) or not e.is_alive():
		return false
	_sanitize_holders()
	if token_holder == e:
		return true
	if token_holder != null:
		return false
	return ignore_gap or attack_gap <= 0.001


func claim_token(e: LxEnemyBrain, ignore_gap: bool = false) -> bool:
	if not can_claim_token(e, ignore_gap):
		return false
	token_holder = e
	lead_enemy = e
	peak_attackers = maxi(peak_attackers, maxi(1, active_attackers()))
	return true


func release_token(e: LxEnemyBrain) -> void:
	if e == null:
		if token_holder != null:
			token_holder = null
			attack_gap = attack_gap_duration
		return
	if token_holder == e:
		token_holder = null
		attack_gap = attack_gap_duration


func claim_light(e: LxEnemyBrain) -> bool:
	if e == null or not is_instance_valid(e) or not e.is_alive():
		return false
	_sanitize_holders()
	if light_claimer != null and light_claimer != e:
		return false
	light_claimer = e
	peak_claims = maxi(peak_claims, active_claims())
	return true


func release_light(e: LxEnemyBrain) -> void:
	if e == null:
		light_claimer = null
		return
	if light_claimer == e:
		light_claimer = null


func active_attackers() -> int:
	var count: int = 0
	for e: LxEnemyBrain in enemies:
		if is_instance_valid(e) and e.is_alive():
			if e.state == LxEnemyBrain.State.TELL or e.state == LxEnemyBrain.State.COMMIT:
				count += 1
	return count


func active_claims() -> int:
	_sanitize_holders()
	return 1 if light_claimer != null else 0


func tick(dt: float) -> void:
	attack_gap = maxf(0.0, attack_gap - dt)
	_prune_invalid()
	_sanitize_holders()

	if token_holder != null:
		var st: int = token_holder.state
		if st == LxEnemyBrain.State.ROUTINE or st == LxEnemyBrain.State.RETURN \
				or st == LxEnemyBrain.State.DEAD or st == LxEnemyBrain.State.STAGGER:
			token_holder = null
			attack_gap = attack_gap_duration

	lead_enemy = token_holder
	if lead_enemy == null:
		var best_score: float = INF
		for e: LxEnemyBrain in enemies:
			if not e.is_alive() or not e.wants_token():
				continue
			var dist: float = e.distance_to_attention_target()
			if dist <= e.leash_radius + 60.0:
				var score: float = dist + (60.0 if e.cooldown > 0.0 else 0.0)
				if score < best_score:
					best_score = score
					lead_enemy = e

	peak_attackers = maxi(peak_attackers, active_attackers())
	peak_claims = maxi(peak_claims, active_claims())
	separate_ground_enemies()


func rally_nearby(source: LxEnemyBrain, radius: float, delay: float) -> void:
	if source == null:
		return
	for o: LxEnemyBrain in enemies:
		if o == source or not is_instance_valid(o) or not o.is_alive():
			continue
		if o.state != LxEnemyBrain.State.ROUTINE and o.state != LxEnemyBrain.State.RETURN:
			continue
		if o.rally_t >= 0.0:
			continue
		if source.zone != "" and o.zone != "" and o.zone != source.zone:
			continue
		if o.pos.distance_to(source.pos) < radius:
			o.rally_t = delay


func separate_ground_enemies() -> void:
	var n: int = enemies.size()
	for i: int in range(n):
		var a: LxEnemyBrain = enemies[i]
		if not is_instance_valid(a) or not a.is_alive() or a.is_flying():
			continue
		for j: int in range(i + 1, n):
			var b: LxEnemyBrain = enemies[j]
			if not is_instance_valid(b) or not b.is_alive() or b.is_flying():
				continue
			var d: Vector2 = b.pos - a.pos
			var min_sep: float = a.body_radius + b.body_radius + 3.0
			var dist: float = d.length()
			var overlap: float = min_sep - dist
			if overlap > 0.0:
				var push: Vector2 = (d / dist if dist > 0.01 else Vector2.RIGHT) * overlap * 0.5
				a.apply_separation_push(-push)
				b.apply_separation_push(push)


func _prune_invalid() -> void:
	var i: int = enemies.size() - 1
	while i >= 0:
		var e: LxEnemyBrain = enemies[i]
		if e == null or not is_instance_valid(e) or e.state == LxEnemyBrain.State.DEAD:
			if token_holder == e:
				token_holder = null
				attack_gap = attack_gap_duration
			if light_claimer == e:
				light_claimer = null
			if lead_enemy == e:
				lead_enemy = null
			enemies.remove_at(i)
		i -= 1


func _sanitize_holders() -> void:
	if token_holder != null and (not is_instance_valid(token_holder) or not token_holder.is_alive()):
		token_holder = null
		attack_gap = attack_gap_duration
	if light_claimer != null and (not is_instance_valid(light_claimer) or not light_claimer.is_alive()):
		light_claimer = null
	if lead_enemy != null and (not is_instance_valid(lead_enemy) or not lead_enemy.is_alive()):
		lead_enemy = null
