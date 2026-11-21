class_name LxEnemyData
extends Resource
## Reusable enemy stats resource for Luxel 1.0 brains.

@export var kind: String = "warden"
@export var max_hp: float = 4.0
@export var body_radius: float = 5.0
@export var routine_speed: float = 36.0
@export var leash_radius: float = 158.0
@export var notice_radius: float = 120.0
@export var tell_time: float = 0.48
@export var recover_time: float = 1.15
@export var shield_hp: float = 0.0
@export var shield_gone_time: float = 4.8
@export var shard_drop: int = 2
@export var attack_damage: float = 1.0
@export var is_boss: bool = false


static func from_dict(d: Dictionary) -> LxEnemyData:
	var res := LxEnemyData.new()
	res.kind = str(d.get("kind", res.kind))
	res.max_hp = float(d.get("max_hp", res.max_hp))
	res.body_radius = float(d.get("body_radius", res.body_radius))
	res.routine_speed = float(d.get("routine_speed", res.routine_speed))
	res.leash_radius = float(d.get("leash_radius", res.leash_radius))
	res.notice_radius = float(d.get("notice_radius", res.notice_radius))
	res.tell_time = float(d.get("tell_time", res.tell_time))
	res.recover_time = float(d.get("recover_time", res.recover_time))
	res.shield_hp = float(d.get("shield_hp", res.shield_hp))
	res.shield_gone_time = float(d.get("shield_gone_time", res.shield_gone_time))
	res.shard_drop = int(d.get("shard_drop", res.shard_drop))
	res.attack_damage = float(d.get("attack_damage", res.attack_damage))
	res.is_boss = bool(d.get("is_boss", res.is_boss))
	return res


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"max_hp": max_hp,
		"body_radius": body_radius,
		"routine_speed": routine_speed,
		"leash_radius": leash_radius,
		"notice_radius": notice_radius,
		"tell_time": tell_time,
		"recover_time": recover_time,
		"shield_hp": shield_hp,
		"shield_gone_time": shield_gone_time,
		"shard_drop": shard_drop,
		"attack_damage": attack_damage,
		"is_boss": is_boss,
	}
