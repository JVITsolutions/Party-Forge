class_name AttackPresentationDefinition
extends Resource

@export var id: StringName
@export var attack_id: StringName
@export var action_id: StringName
@export var required_event_name: StringName = &"release"
@export var weapon_animation_family_id: StringName
@export var launch_socket_id: StringName
@export var projectile_scene: PackedScene
@export var projectile_rotation_degrees: Vector3
@export var projectile_scale := Vector3.ONE
@export var impact_scene: PackedScene
@export var impact_color := Color.WHITE
@export var action_duration := 1.0
@export var release_time := 0.5

func validate(attack: AttackDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or attack_id.is_empty() or action_id.is_empty() or required_event_name not in [&"release", &"impact"]:
		errors.append("attack presentation identity is invalid")
	if attack == null or attack.id != attack_id:
		errors.append("attack presentation %s attack link is invalid" % id)
	if not is_finite(action_duration) or not is_finite(release_time) or action_duration <= 0.0 or release_time < 0.0 or release_time > action_duration:
		errors.append("attack presentation %s timing is invalid" % id)
	if attack != null and action_duration > attack.cooldown:
		errors.append("attack presentation %s phases exceed cooldown" % id)
	return errors
