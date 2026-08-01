class_name Boltcaster
extends "res://scripts/enemies/enemy_actor.gd"

enum State { MOVING, TELLING }

const ENEMY_PROJECTILE_SCENE := preload("res://scenes/enemies/enemy_projectile.tscn")
const PREFERRED_DISTANCE := 9.0
const RETREAT_DISTANCE := 5.5
const FIRE_INTERVAL := 2.4

var state := State.MOVING
var leader: Node3D
var projectile_parent: Node
var fire_cooldown := FIRE_INTERVAL
var tell_remaining := 0.0
var sampled_aim_position := Vector3.ZERO

func configure_target(target_leader: Node3D, effects_parent: Node = null) -> void:
	leader = target_leader
	projectile_parent = effects_parent

func _physics_process(delta: float) -> void:
	advance_behavior(delta)

func advance_behavior(delta: float) -> void:
	if is_dead or definition == null:
		velocity = Vector3.ZERO
		return
	if not _leader_is_living():
		leader = nearest_living_party_actor()
	if leader == null:
		velocity = Vector3.ZERO
		return
	if state == State.TELLING:
		velocity = Vector3.ZERO
		tell_remaining = maxf(0.0, tell_remaining - maxf(delta, 0.0))
		if tell_remaining <= 0.0:
			_fire_projectile()
			state = State.MOVING
			var attack := definition.attack_by_id(&"boltcaster_bolt")
			fire_cooldown = attack.cooldown if attack != null else FIRE_INTERVAL
		return
	var origin := global_position if is_inside_tree() else position
	var target_position := leader.global_position if leader.is_inside_tree() else leader.position
	var away := origin - target_position
	away.y = 0.0
	var distance := away.length()
	if distance < RETREAT_DISTANCE:
		velocity = away.normalized() * definition.move_speed if not away.is_zero_approx() else Vector3.RIGHT * definition.move_speed
	elif distance > PREFERRED_DISTANCE:
		velocity = -away.normalized() * definition.move_speed
	else:
		velocity = Vector3.ZERO
	_move_for_delta(delta)
	fire_cooldown -= maxf(delta, 0.0)
	if fire_cooldown <= 0.0 and distance <= attack_geometry(&"boltcaster_bolt").range:
		state = State.TELLING
		velocity = Vector3.ZERO
		sampled_aim_position = target_position
		tell_remaining = definition.projectile_profile.tell_duration

func _fire_projectile() -> void:
	if leader == null or not is_instance_valid(leader):
		return
	var parent := projectile_parent if projectile_parent != null and is_instance_valid(projectile_parent) else get_parent()
	if parent == null:
		return
	var attack := definition.attack_by_id(&"boltcaster_bolt")
	var packet := prepare_attack(&"boltcaster_bolt")
	if attack == null or definition.projectile_profile == null or packet == null or not packet.valid:
		return
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate() as Node3D
	parent.add_child(projectile)
	projectile.name = "EnemyProjectile"
	if is_inside_tree() and projectile.is_inside_tree():
		projectile.global_position = global_position
	else:
		projectile.position = position
	projectile.call(
		"configure",
		leader,
		packet,
		combat_rng,
		damage_types,
		attack,
		definition.projectile_profile,
		sampled_aim_position
	)

func _leader_is_living() -> bool:
	if leader == null or not is_instance_valid(leader):
		return false
	if not leader.has_method("get_combat_target"):
		return true
	var target: CombatTarget = leader.call("get_combat_target") as CombatTarget
	return target != null and target.is_available and target.team_id != HOSTILE_TEAM_ID
