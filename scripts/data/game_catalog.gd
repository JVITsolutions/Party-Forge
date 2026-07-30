class_name GameCatalog
extends RefCounted

const CLASS_PATHS: PackedStringArray = [
	"res://data/classes/fighter.tres",
	"res://data/classes/ranger.tres",
	"res://data/classes/mage.tres",
	"res://data/classes/cleric.tres",
	"res://data/classes/paladin.tres",
	"res://data/classes/rogue.tres",
	"res://data/classes/frost_mage.tres",
	"res://data/classes/warlock.tres",
	"res://data/classes/marksman.tres",
]
const TRAIT_PATHS: PackedStringArray = [
	"res://data/traits/martial.tres", "res://data/traits/vanguard.tres",
	"res://data/traits/ranged.tres", "res://data/traits/arcane.tres",
	"res://data/traits/caster.tres", "res://data/traits/divine.tres",
	"res://data/traits/support.tres", "res://data/traits/fire.tres",
	"res://data/traits/cold.tres", "res://data/traits/skirmisher.tres",
	"res://data/traits/occult.tres", "res://data/traits/chaos.tres",
	"res://data/traits/bow.tres",
]
const ENEMY_PATHS: PackedStringArray = [
	"res://data/enemies/swarmer.tres", "res://data/enemies/spitter.tres",
	"res://data/enemies/forge_guardian.tres",
]
const REQUIRED_UPGRADE_PATHS: PackedStringArray = [
	"res://data/upgrades/cards/hold_the_line.tres",
	"res://data/upgrades/cards/quickdraw.tres",
	"res://data/upgrades/cards/living_flame.tres",
	"res://data/upgrades/cards/sacred_conduit.tres",
	"res://data/upgrades/cards/consecrated_bulwark.tres",
	"res://data/upgrades/cards/cutthroat_instinct.tres",
	"res://data/upgrades/cards/heart_of_winter.tres",
	"res://data/upgrades/cards/blood_covenant.tres",
	"res://data/upgrades/cards/deadeye.tres",
	"res://data/upgrades/cards/martial_training.tres",
	"res://data/upgrades/cards/ranged_calibration.tres",
	"res://data/upgrades/cards/caster_discipline.tres",
	"res://data/upgrades/cards/skirmishers_rhythm.tres",
	"res://data/upgrades/cards/projectile_mastery.tres",
	"res://data/upgrades/cards/expanding_power.tres",
	"res://data/upgrades/cards/elemental_attunement.tres",
	"res://data/upgrades/cards/vanguard_wall.tres",
	"res://data/upgrades/cards/arcane_convergence.tres",
	"res://data/upgrades/cards/divine_covenant.tres",
	"res://data/upgrades/cards/vitality.tres",
	"res://data/upgrades/cards/tempered_armor.tres",
	"res://data/upgrades/cards/ferocity.tres",
	"res://data/upgrades/cards/alacrity.tres",
	"res://data/upgrades/cards/fleetfoot.tres",
	"res://data/upgrades/cards/precision.tres",
]
const OPTIONAL_UPGRADE_PATHS: PackedStringArray = []
const STAT_CATALOG: StatCatalog = preload("res://data/stats/core_stats.tres")
const DAMAGE_TYPES: DamageTypeCatalog = preload("res://data/damage_types/core_damage_types.tres")
const KEYWORD_CATALOG: KeywordCatalog = preload("res://data/keywords/core_keywords.tres")
const GENERIC_NAME_POOL: CharacterNamePool = preload("res://data/names/generic.tres")

var damage_types: DamageTypeCatalog = DAMAGE_TYPES
var classes: Array[ClassDefinition] = []
var traits: Array[TraitDefinition] = []
var enemies: Array[EnemyDefinition] = []
var upgrades: Array[UpgradeDefinition] = []
var keywords: KeywordCatalog = KEYWORD_CATALOG
var generic_name_pool: CharacterNamePool = GENERIC_NAME_POOL
var _upgrade_load_errors := PackedStringArray()

static func load_defaults() -> GameCatalog:
	return load_with_upgrade_paths(REQUIRED_UPGRADE_PATHS, OPTIONAL_UPGRADE_PATHS)

static func load_with_upgrade_paths(required_paths: PackedStringArray, optional_paths: PackedStringArray) -> GameCatalog:
	var catalog := GameCatalog.new()
	for path: String in CLASS_PATHS:
		catalog.classes.append(load(path) as ClassDefinition)
	for path: String in TRAIT_PATHS:
		catalog.traits.append(load(path) as TraitDefinition)
	for path: String in ENEMY_PATHS:
		catalog.enemies.append(load(path) as EnemyDefinition)
	catalog._load_upgrades(required_paths, true)
	catalog._load_upgrades(optional_paths, false)
	return catalog

func _load_upgrades(paths: PackedStringArray, required: bool) -> void:
	for path: String in paths:
		if not ResourceLoader.exists(path):
			if required:
				_upgrade_load_errors.append(_upgrade_error(&"<missing>", path, "required resource failed to load"))
			continue
		var definition := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as UpgradeDefinition
		if definition == null:
			if required:
				_upgrade_load_errors.append(_upgrade_error(&"<missing>", path, "required resource failed to load"))
			continue
		upgrades.append(definition)

func class_by_id(id: StringName) -> ClassDefinition:
	for definition: ClassDefinition in classes:
		if definition != null and definition.id == id:
			return definition
	return null

func trait_by_id(id: StringName) -> TraitDefinition:
	for definition: TraitDefinition in traits:
		if definition != null and definition.id == id:
			return definition
	return null

func upgrade_by_id(id: StringName) -> UpgradeDefinition:
	for definition: UpgradeDefinition in upgrades:
		if definition != null and definition.id == id:
			return definition
	return null

func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	_validate_foundation(errors)
	_validate_resources(errors)
	_validate_trait_links(errors)
	errors.append_array(_upgrade_load_errors)
	_validate_upgrades(errors)
	return errors

func _validate_foundation(errors: PackedStringArray) -> void:
	if damage_types == null:
		errors.append("PARTY_FORGE_DAMAGE_ERROR path=<missing> type=<catalog> reason=resource failed to load")
	else:
		for reason: String in damage_types.validate(STAT_CATALOG):
			errors.append(_damage_error_with_path(reason, damage_types.resource_path))
	if keywords == null:
		errors.append("PARTY_FORGE_RESOURCE_ERROR reason=keyword catalog failed to load")
	else:
		for reason: String in keywords.validate():
			errors.append("PARTY_FORGE_RESOURCE_ERROR path=%s reason=%s" % [keywords.resource_path, reason])
	if generic_name_pool == null:
		errors.append("PARTY_FORGE_RESOURCE_ERROR reason=generic name pool failed to load")
	else:
		for reason: String in generic_name_pool.validate(12):
			errors.append("PARTY_FORGE_RESOURCE_ERROR path=%s reason=%s" % [generic_name_pool.resource_path, reason])

func _validate_resources(errors: PackedStringArray) -> void:
	var seen: Dictionary = {}
	var resources: Array[Resource] = []
	for definition: ClassDefinition in classes:
		resources.append(definition)
	for definition: TraitDefinition in traits:
		resources.append(definition)
	for definition: EnemyDefinition in enemies:
		resources.append(definition)
	for definition: Resource in resources:
		if definition == null:
			errors.append("PARTY_FORGE_RESOURCE_ERROR reason=resource failed to load")
			continue
		var id: StringName = definition.get("id")
		if seen.has(id):
			errors.append("PARTY_FORGE_RESOURCE_ERROR reason=duplicate id %s" % id)
		seen[id] = true
		var validation: PackedStringArray
		if definition is EnemyDefinition:
			validation = (definition as EnemyDefinition).validate(damage_types, STAT_CATALOG)
		elif definition is ClassDefinition:
			validation = (definition as ClassDefinition).validate(damage_types)
		else:
			validation = definition.call("validate")
		for reason: String in validation:
			var damage_reason := _structured_damage_reason(reason)
			if not damage_reason.is_empty():
				errors.append(_damage_error_with_path(damage_reason, _damage_error_resource_path(definition, reason)))
			else:
				errors.append("PARTY_FORGE_RESOURCE_ERROR id=%s reason=%s" % [id, reason])

func _validate_trait_links(errors: PackedStringArray) -> void:
	for class_definition: ClassDefinition in classes:
		if class_definition == null:
			continue
		for trait_id: StringName in class_definition.traits:
			if trait_by_id(trait_id) == null:
				errors.append("PARTY_FORGE_RESOURCE_ERROR path=%s class=%s trait=%s reason=unknown trait reference" % [class_definition.resource_path, class_definition.id, trait_id])

func _validate_upgrades(errors: PackedStringArray) -> void:
	var seen := {}
	for definition: UpgradeDefinition in upgrades:
		if definition == null:
			errors.append(_upgrade_error(&"<null>", "<missing>", "resource failed to load"))
			continue
		var id_text := _upgrade_id(definition)
		var path := definition.resource_path if not definition.resource_path.is_empty() else "<memory>"
		if definition.id.is_empty():
			errors.append(_upgrade_error(id_text, path, "id is empty"))
		elif seen.has(definition.id):
			errors.append(_upgrade_error(id_text, path, "duplicate id"))
		else:
			seen[definition.id] = true
		_validate_upgrade_definition(definition, id_text, path, errors)

func _validate_upgrade_definition(definition: UpgradeDefinition, id: StringName, path: String, errors: PackedStringArray) -> void:
	if definition.display_name.strip_edges().is_empty():
		errors.append(_upgrade_error(id, path, "display name is empty"))
	if definition.summary.strip_edges().is_empty():
		errors.append(_upgrade_error(id, path, "summary is empty"))
	if definition.description.strip_edges().is_empty():
		errors.append(_upgrade_error(id, path, "description is empty"))
	if definition.tooltip_keyword_ids.is_empty():
		errors.append(_upgrade_error(id, path, "tooltip keywords are empty"))
	for keyword_id: StringName in definition.tooltip_keyword_ids:
		if keywords == null or not keywords.has_definition(keyword_id):
			errors.append(_upgrade_error(id, path, "unknown keyword %s" % keyword_id))
	if definition.max_rank <= 0:
		errors.append(_upgrade_error(id, path, "max rank must be positive"))
	if not is_finite(definition.selection_weight) or definition.selection_weight <= 0.0:
		errors.append(_upgrade_error(id, path, "selection weight must be finite and positive"))
	_validate_eligibility(definition, id, path, errors)
	if definition.effects.is_empty():
		errors.append(_upgrade_error(id, path, "effects are empty"))
	for effect_index: int in definition.effects.size():
		_validate_effect(definition.effects[effect_index], effect_index, id, path, errors)

func _validate_eligibility(definition: UpgradeDefinition, id: StringName, path: String, errors: PackedStringArray) -> void:
	var valid_tags := _known_eligibility_tags()
	for class_id: StringName in definition.allowed_class_ids:
		if class_by_id(class_id) == null:
			errors.append(_upgrade_error(id, path, "unknown class %s" % class_id))
	for tag: StringName in definition.required_all_tags + definition.required_any_tags + definition.excluded_tags:
		if tag.is_empty() or tag not in valid_tags:
			errors.append(_upgrade_error(id, path, "unknown eligibility tag %s" % tag))
	for tag: StringName in definition.required_all_tags + definition.required_any_tags:
		if tag in definition.excluded_tags:
			errors.append(_upgrade_error(id, path, "contradictory eligibility tag %s" % tag))
	if definition.scope == UpgradeDefinition.Scope.CLASS_SPECIFIC and definition.allowed_class_ids.is_empty():
		errors.append(_upgrade_error(id, path, "class-specific upgrade has no allowed class"))
	if definition.scope == UpgradeDefinition.Scope.TRAIT and definition.required_all_tags.is_empty() and definition.required_any_tags.is_empty():
		errors.append(_upgrade_error(id, path, "trait upgrade has empty eligibility"))
	if definition.scope == UpgradeDefinition.Scope.CLASS_SPECIFIC and not classes.any(func(class_definition: ClassDefinition) -> bool: return _class_is_eligible(class_definition, definition)):
		errors.append(_upgrade_error(id, path, "class-specific upgrade has no eligible class"))

func _validate_effect(effect_definition: UpgradeEffectDefinition, effect_index: int, id: StringName, path: String, errors: PackedStringArray) -> void:
	if effect_definition == null:
		errors.append(_upgrade_error(id, path, "effect %d is null" % effect_index))
		return
	if effect_definition.effect_type != UpgradeEffectDefinition.EffectType.STAT_MODIFIER:
		errors.append(_upgrade_error(id, path, "effect %d has unsupported effect type %d" % [effect_index, effect_definition.effect_type]))
		return
	var effect := effect_definition as StatUpgradeEffect
	if effect == null:
		errors.append(_upgrade_error(id, path, "effect %d has unsupported implementation" % effect_index))
		return
	if STAT_CATALOG.definition(effect.stat_id) == null:
		errors.append(_upgrade_error(id, path, "effect %d references unknown stat %s" % [effect_index, effect.stat_id]))
	if effect.operation not in [StatModifier.Operation.FLAT, StatModifier.Operation.INCREASED, StatModifier.Operation.REDUCED, StatModifier.Operation.MORE, StatModifier.Operation.LESS]:
		errors.append(_upgrade_error(id, path, "effect %d has unsupported operation %d" % [effect_index, effect.operation]))
	if not is_finite(effect.value_per_rank):
		errors.append(_upgrade_error(id, path, "effect %d value per rank must be finite" % effect_index))
	for rank_value: float in effect.rank_values:
		if not is_finite(rank_value):
			errors.append(_upgrade_error(id, path, "effect %d rank value must be finite" % effect_index))
	var known_capabilities := _known_capability_tags()
	var known_actions := _known_action_tags()
	for tag: StringName in effect.required_capability_tags + effect.excluded_capability_tags:
		if tag.is_empty() or tag not in known_capabilities:
			errors.append(_upgrade_error(id, path, "effect %d references unknown capability tag %s" % [effect_index, tag]))
	for tag: StringName in effect.required_action_tags + effect.excluded_action_tags:
		if tag.is_empty() or tag not in known_actions:
			errors.append(_upgrade_error(id, path, "effect %d references unknown action tag %s" % [effect_index, tag]))
	for tag: StringName in effect.required_capability_tags:
		if tag in effect.excluded_capability_tags:
			errors.append(_upgrade_error(id, path, "effect %d contradicts capability tag %s" % [effect_index, tag]))
	for tag: StringName in effect.required_action_tags:
		if tag in effect.excluded_action_tags:
			errors.append(_upgrade_error(id, path, "effect %d contradicts action tag %s" % [effect_index, tag]))

func _known_eligibility_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: TraitDefinition in traits:
		if definition != null and definition.id not in result:
			result.append(definition.id)
	for definition: ClassDefinition in classes:
		if definition != null:
			for tag: StringName in definition.normalized_eligibility_tags():
				if tag not in result:
					result.append(tag)
	return result

func _known_capability_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: ClassDefinition in classes:
		if definition == null:
			continue
		for tag: StringName in definition.capability_tags:
			if tag not in result:
				result.append(tag)
	return result

func _known_action_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: ClassDefinition in classes:
		if definition == null:
			continue
		for attack: AttackDefinition in [definition.primary_attack, definition.support_action]:
			if attack == null:
				continue
			for tag: StringName in attack.normalized_action_tags():
				if tag not in result:
					result.append(tag)
	return result

func _class_is_eligible(class_definition: ClassDefinition, upgrade: UpgradeDefinition) -> bool:
	if class_definition == null:
		return false
	if not upgrade.allowed_class_ids.is_empty() and class_definition.id not in upgrade.allowed_class_ids:
		return false
	var tags := class_definition.normalized_eligibility_tags()
	for tag: StringName in upgrade.required_all_tags:
		if tag not in tags:
			return false
	if not upgrade.required_any_tags.is_empty() and not upgrade.required_any_tags.any(func(tag: StringName) -> bool: return tag in tags):
		return false
	return not upgrade.excluded_tags.any(func(tag: StringName) -> bool: return tag in tags)

func _upgrade_id(definition: UpgradeDefinition) -> StringName:
	return definition.id if not definition.id.is_empty() else &"<empty>"

func _upgrade_error(id: StringName, path: String, reason: String) -> String:
	return "PARTY_FORGE_UPGRADE_ERROR id=%s path=%s reason=%s" % [id, path, reason]

func _structured_damage_reason(reason: String) -> String:
	var marker := reason.find("PARTY_FORGE_DAMAGE_ERROR")
	return reason.substr(marker) if marker >= 0 else ""

func _damage_error_resource_path(definition: Resource, reason: String) -> String:
	if definition is ClassDefinition:
		var class_definition := definition as ClassDefinition
		if reason.begins_with("class %s primary " % class_definition.id) and class_definition.primary_attack != null:
			return class_definition.primary_attack.resource_path
		if reason.begins_with("class %s support " % class_definition.id) and class_definition.support_action != null:
			return class_definition.support_action.resource_path
	return definition.resource_path

func _damage_error_with_path(reason: String, path: String) -> String:
	if path.is_empty() or not reason.begins_with("PARTY_FORGE_DAMAGE_ERROR"):
		return reason
	return "PARTY_FORGE_DAMAGE_ERROR path=%s %s" % [path, reason.trim_prefix("PARTY_FORGE_DAMAGE_ERROR ")]
