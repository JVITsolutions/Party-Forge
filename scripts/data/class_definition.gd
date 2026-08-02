class_name ClassDefinition
extends Resource

enum Role { FRONTLINE, MIDLINE, BACKLINE, SUPPORT }

@export var id: StringName
@export var display_name: String
@export var role: Role
@export var color: Color = Color.WHITE
@export var traits: Array[StringName] = []
@export var capability_tags: Array[StringName] = []
@export var name_pool: CharacterNamePool
@export var visual_profile: CharacterVisualProfile
@export var base_stat_overrides: Dictionary = {}
@export var max_health: float = 100.0
@export var armor: float = 0.0
@export var move_speed: float = 6.0
@export var class_rank_power_step: float = 0.2
@export var revive_delay: float = 8.0
@export var revive_health_fraction: float = 0.5
@export var preferred_distance: float = 2.0
@export var engagement_distance: float = 8.0
@export var tether_distance: float = 10.0
@export var primary_attack: AttackDefinition
@export var support_action: AttackDefinition

func stat_base_values() -> Dictionary:
	var values := base_stat_overrides.duplicate(true)
	values[&"max_health"] = float(values.get(&"max_health", max_health))
	values[&"armor"] = float(values.get(&"armor", armor))
	values[&"move_speed"] = float(values.get(&"move_speed", move_speed))
	return values

func normalized_eligibility_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for tag: StringName in traits + capability_tags:
		if not tag.is_empty() and tag not in result:
			result.append(tag)
	result.sort()
	return result

func validate(types: DamageTypeCatalog = null) -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty(): errors.append("class id is empty")
	if display_name.is_empty(): errors.append("class %s display name is empty" % id)
	if traits.is_empty(): errors.append("class %s has no traits" % id)
	if max_health <= 0.0: errors.append("class %s health must be positive" % id)
	if class_rank_power_step < 0.0: errors.append("class %s rank power step cannot be negative" % id)
	if revive_delay <= 0.0: errors.append("class %s revive delay must be positive" % id)
	if revive_health_fraction <= 0.0 or revive_health_fraction > 1.0: errors.append("class %s revive health fraction must be between zero and one" % id)
	if primary_attack == null: errors.append("class %s primary attack is missing" % id)
	if primary_attack != null:
		_validate_party_attack(primary_attack, "primary", types, errors)
	if support_action != null:
		_validate_party_attack(support_action, "support", types, errors)
	if visual_profile != null:
		for reason: String in visual_profile.validate():
			errors.append("class %s visual profile %s" % [id, reason])
		_validate_starter_loadout(errors)
	return errors

func _validate_starter_loadout(errors: PackedStringArray) -> void:
	var loadout: Dictionary = {}
	for entry: EquipmentLoadoutEntry in visual_profile.default_equipment:
		if entry == null or entry.item == null:
			continue
		for reason: String in EquipmentEligibility.validate_equip(entry.item, self, entry.slot_id, loadout):
			errors.append("class %s starter loadout %s" % [id, reason])
		loadout[entry.slot_id] = entry.item

func _validate_party_attack(attack: AttackDefinition, slot: String, types: DamageTypeCatalog, errors: PackedStringArray) -> void:
	for reason: String in attack.validate(types):
		errors.append("class %s %s %s" % [id, slot, reason])
	var kind_value := int(attack.kind)
	if kind_value >= 0 and kind_value < AttackDefinition.Kind.size() and kind_value not in [AttackDefinition.Kind.MELEE_CLEAVE, AttackDefinition.Kind.PROJECTILE, AttackDefinition.Kind.AREA_PROJECTILE, AttackDefinition.Kind.HEAL]:
		errors.append("class %s %s PARTY_FORGE_DAMAGE_ERROR attack=%s kind=%d reason=unsupported party attack kind" % [id, slot, attack.id, kind_value])
