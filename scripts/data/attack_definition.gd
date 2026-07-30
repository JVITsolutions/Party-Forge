class_name AttackDefinition
extends Resource

enum Kind { MELEE_CLEAVE, PROJECTILE, AREA_PROJECTILE, HEAL, DIRECT, AREA }
const DEFAULT_TYPES: DamageTypeCatalog = preload("res://data/damage_types/core_damage_types.tres")

@export var id: StringName
@export var kind: Kind
@export var power := 0.0
@export var cooldown: float = 1.0
@export var range: float = 1.0
@export var projectile_speed: float = 0.0
@export var area_radius: float = 0.0
@export var damage_components: Array[AttackDamageComponent] = []
@export var action_tags: Array[StringName] = []
@export var can_crit := false

func is_healing() -> bool:
	return kind == Kind.HEAL

func normalized_action_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for tag: StringName in action_tags:
		if not tag.is_empty() and tag not in result:
			result.append(tag)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result

func validate(types: DamageTypeCatalog = null) -> PackedStringArray:
	var damage_types := types if types != null else DEFAULT_TYPES
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=<empty> reason=missing id")
	if int(kind) < 0 or int(kind) >= Kind.size():
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s kind=%d reason=invalid attack kind" % [id, kind])
	if not is_finite(cooldown) or cooldown <= 0.0:
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=cooldown must be finite and positive" % id)
	if not is_finite(range) or range <= 0.0:
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=range must be finite and positive" % id)
	if kind in [Kind.PROJECTILE, Kind.AREA_PROJECTILE] and (not is_finite(projectile_speed) or projectile_speed <= 0.0):
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=projectile speed must be finite and positive" % id)
	if not is_finite(area_radius) or area_radius < 0.0:
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=area radius must be finite and nonnegative" % id)
	if normalized_action_tags().size() != action_tags.size():
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=empty or duplicate action tag" % id)
	if is_healing():
		if not is_finite(power) or power <= 0.0:
			errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=heal power must be finite and positive" % id)
		if not damage_components.is_empty():
			errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=heal has damage components" % id)
		if can_crit:
			errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=heal cannot crit" % id)
		return errors
	if damage_components.is_empty():
		errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=damaging attack has no components" % id)
	var seen: Dictionary = {}
	for component: AttackDamageComponent in damage_components:
		if component == null:
			errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=<null> reason=null component" % id)
			continue
		if seen.has(component.damage_type_id):
			errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=%s reason=duplicate component type" % [id, component.damage_type_id])
		seen[component.damage_type_id] = true
		errors.append_array(component.validate(id, damage_types))
	return errors
