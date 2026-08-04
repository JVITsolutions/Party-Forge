class_name EnemyProjectile
extends Node3D

var target: Node3D
var packet: DamagePacket
var combat_rng: CombatRng
var damage_types: DamageTypeCatalog
var movement := EnemyProjectileProfile.Movement.LINEAR
var speed := 0.01
var maximum_range := 0.01
var area_radius := 0.0
var hit_radius := 0.45
var lifetime := 0.1
var elapsed := 0.0
var distance_travelled := 0.0
var direction := Vector3.FORWARD

func configure(
	target_actor: Node3D,
	prepared_packet: DamagePacket,
	shared_combat_rng: CombatRng,
	shared_damage_types: DamageTypeCatalog,
	attack: AttackDefinition,
	profile: EnemyProjectileProfile,
	aim_position: Vector3
) -> void:
	target = target_actor
	packet = prepared_packet
	combat_rng = shared_combat_rng
	damage_types = shared_damage_types
	movement = profile.movement
	speed = maxf(attack.projectile_speed, 0.01)
	maximum_range = maxf(attack.range, 0.01)
	area_radius = maxf(attack.area_radius, 0.0)
	hit_radius = maxf(profile.hit_radius, 0.01)
	lifetime = minf(profile.max_lifetime, maximum_range / speed + 0.5)
	elapsed = 0.0
	distance_travelled = 0.0
	direction = (aim_position - _position()).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	_apply_color(profile.color)

func _process(delta: float) -> void:
	advance_projectile(delta)

func advance_projectile(delta: float) -> void:
	var step_delta := maxf(delta, 0.0)
	elapsed += step_delta
	if elapsed >= lifetime or distance_travelled >= maximum_range:
		queue_free()
		return
	if movement == EnemyProjectileProfile.Movement.HOMING:
		if target == null or not is_instance_valid(target):
			queue_free()
			return
		var next_direction := (_actor_position(target) - _position()).normalized()
		if not next_direction.is_zero_approx():
			direction = next_direction
	var step := minf(speed * step_delta, maximum_range - distance_travelled)
	var start_position := _position()
	var next_position := start_position + direction * step
	var hit_actor := _first_living_party_actor_on_segment(start_position, next_position)
	if hit_actor != null:
		var hit_position := _closest_point_on_segment(_actor_position(hit_actor), start_position, next_position)
		distance_travelled += start_position.distance_to(hit_position)
		_set_position(hit_position)
		_resolve_impact(hit_actor)
		return
	_set_position(next_position)
	distance_travelled += step
	if distance_travelled >= maximum_range:
		queue_free()

func _position() -> Vector3:
	return global_position if is_inside_tree() else position

func _actor_position(actor: Node3D) -> Vector3:
	return actor.global_position if actor.is_inside_tree() else actor.position

func _first_living_party_actor_on_segment(start_position: Vector3, next_position: Vector3) -> Node3D:
	var selected: Node3D = null
	var selected_progression := INF
	var selected_tie_break := ""
	for actor: Node3D in _party_actors():
		if not _actor_is_available(actor):
			continue
		var actor_position := _actor_position(actor)
		if _distance_squared_to_segment(actor_position, start_position, next_position) > hit_radius * hit_radius:
			continue
		var progression := _segment_hit_progression(actor_position, start_position, next_position)
		var tie_break := _actor_tie_break(actor)
		var should_select := selected == null
		if selected != null:
			should_select = tie_break < selected_tie_break if is_equal_approx(progression, selected_progression) else progression < selected_progression
		if should_select:
			selected = actor
			selected_progression = progression
			selected_tie_break = tie_break
	return selected

func _segment_hit_progression(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var segment := finish - start
	var segment_length := segment.length()
	if is_zero_approx(segment_length) or point.distance_squared_to(start) <= hit_radius * hit_radius:
		return 0.0
	var segment_direction := segment / segment_length
	var offset := point - start
	var projected_distance := offset.dot(segment_direction)
	var perpendicular_squared := maxf(0.0, offset.length_squared() - projected_distance * projected_distance)
	var entry_offset := sqrt(maxf(0.0, hit_radius * hit_radius - perpendicular_squared))
	return clampf(projected_distance - entry_offset, 0.0, segment_length)

func _actor_tie_break(actor: Node3D) -> String:
	var adapter := _adapter_for(actor)
	if adapter != null and not adapter.combatant_id.is_empty():
		return String(adapter.combatant_id)
	return "%020d" % actor.get_instance_id()

func _actor_is_available(actor: Node3D) -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.has_method("get_combat_target"):
		return false
	var combat_target := actor.call("get_combat_target") as CombatTarget
	return combat_target != null and combat_target.is_available and (packet == null or combat_target.team_id != packet.source_team_id)

func _resolve_impact(hit_actor: Node3D) -> void:
	if packet != null:
		if area_radius > 0.0:
			_resolve_area()
		else:
			var adapter := _adapter_for(hit_actor)
			if adapter != null:
				DamageResolver.resolve(packet, adapter, combat_rng, damage_types)
	queue_free()

func _resolve_area() -> void:
	var resolved_ids: Dictionary = {}
	for actor: Node3D in _available_party_actors():
		if _actor_position(actor).distance_squared_to(_position()) > area_radius * area_radius:
			continue
		var adapter := _adapter_for(actor)
		if adapter == null or not adapter.available:
			continue
		var resolution_id: Variant = actor.get_instance_id()
		if not adapter.combatant_id.is_empty():
			resolution_id = adapter.combatant_id
		if resolved_ids.has(resolution_id):
			continue
		resolved_ids[resolution_id] = true
		DamageResolver.resolve(packet, adapter, combat_rng, damage_types)

func _available_party_actors() -> Array[Node3D]:
	var actors: Array[Node3D] = []
	for actor: Node3D in _party_actors():
		if _actor_is_available(actor):
			actors.append(actor)
	return actors

func _party_actors() -> Array[Node3D]:
	var actors: Array[Node3D] = []
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("party_actors"):
			if node is Node3D:
				actors.append(node as Node3D)
		return actors
	var local_root: Node = self
	while local_root.get_parent() != null:
		local_root = local_root.get_parent()
	_collect_local_party_actors(local_root, actors)
	return actors

func _collect_local_party_actors(node: Node, actors: Array[Node3D]) -> void:
	if node is Node3D and node.is_in_group("party_actors"):
		actors.append(node as Node3D)
	for child: Node in node.get_children():
		_collect_local_party_actors(child, actors)

func _adapter_for(actor: Node3D) -> CombatantAdapter:
	if actor == null or not actor.has_method("get_combat_adapter"):
		return null
	return actor.call("get_combat_adapter", packet.action_tags if packet != null else []) as CombatantAdapter

func _distance_squared_to_segment(point: Vector3, start: Vector3, finish: Vector3) -> float:
	return point.distance_squared_to(_closest_point_on_segment(point, start, finish))

func _closest_point_on_segment(point: Vector3, start: Vector3, finish: Vector3) -> Vector3:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if is_zero_approx(length_squared):
		return start
	var offset := point - start
	var interpolation := clampf(offset.dot(segment) / length_squared, 0.0, 1.0)
	return start + segment * interpolation

func _set_position(value: Vector3) -> void:
	if is_inside_tree():
		global_position = value
	else:
		position = value

func _apply_color(color: Color) -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	var material := mesh.material_override as StandardMaterial3D
	if material == null:
		material = mesh.get_active_material(0) as StandardMaterial3D
	if material == null:
		return
	material = material.duplicate() as StandardMaterial3D
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	mesh.material_override = material
