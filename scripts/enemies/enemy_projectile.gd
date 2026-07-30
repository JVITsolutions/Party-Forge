class_name EnemyProjectile
extends Node3D

const SPEED := 6.0
const HIT_RANGE := 0.45
const MAX_LIFETIME := 3.0

var target: Node3D
var damage := 0.0
var elapsed := 0.0

func configure(target_actor: Node3D, damage_amount: float) -> void:
	target = target_actor
	damage = maxf(damage_amount, 0.0)
	elapsed = 0.0

func _process(delta: float) -> void:
	advance_projectile(delta)

func advance_projectile(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	elapsed += maxf(delta, 0.0)
	if elapsed >= MAX_LIFETIME:
		queue_free()
		return
	var origin := global_position if is_inside_tree() else position
	var target_position := target.global_position if target.is_inside_tree() else target.position
	var offset := target_position - origin
	var step := SPEED * maxf(delta, 0.0)
	if offset.length() <= maxf(step, HIT_RANGE):
		if target.has_method("receive_damage"):
			target.call("receive_damage", damage)
		queue_free()
		return
	var next_position := origin + offset.normalized() * step
	if is_inside_tree():
		global_position = next_position
	else:
		position = next_position
