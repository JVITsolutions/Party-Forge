class_name PersonalLootTuning
extends Resource

@export var drop_basis_points := {&"ordinary_melee": 100, &"ordinary_specialist": 200, &"elite": 0, &"boss": 0}
@export var seconds_per_item_level := 12.0
@export var specialist_item_level_bonus := 1
@export var elite_item_level_bonus := 5
@export var boss_item_level_bonus := 10
@export var difficulty_item_level_bonus := {&"normal": 0}
@export var heat_item_levels_per_point := 0.25
@export var pickup_interaction_radius := 3.5
@export var controller_target_query_radius := 30.0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for category: StringName in EnemyDefeatEvent.SOURCE_CATEGORIES:
		if not drop_basis_points.has(category):
			errors.append(_error("drop_basis_points.%s" % category, "is required"))
	var drop_keys: Array = drop_basis_points.keys()
	drop_keys.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	for key: Variant in drop_keys:
		var category := StringName(key)
		var value: Variant = drop_basis_points[key]
		if category not in EnemyDefeatEvent.SOURCE_CATEGORIES:
			errors.append(_error("drop_basis_points.%s" % String(key), "unknown source category"))
		elif typeof(value) != TYPE_INT or int(value) < 0 or int(value) > 10000:
			errors.append(_error("drop_basis_points.%s" % category, "must be an integer from 0 to 10000"))
	if not is_finite(seconds_per_item_level) or seconds_per_item_level <= 0.0:
		errors.append(_error("seconds_per_item_level", "must be finite and greater than zero"))
	_validate_bonus("specialist_item_level_bonus", specialist_item_level_bonus, errors)
	_validate_bonus("elite_item_level_bonus", elite_item_level_bonus, errors)
	_validate_bonus("boss_item_level_bonus", boss_item_level_bonus, errors)
	if not difficulty_item_level_bonus.has(&"normal"):
		errors.append(_error("difficulty_item_level_bonus", "normal is required"))
	var keys: Array = difficulty_item_level_bonus.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	for key: Variant in keys:
		var label := String(key).strip_edges()
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] or label.is_empty():
			errors.append(_error("difficulty_item_level_bonus.<empty>", "key must not be empty"))
			continue
		_validate_bonus("difficulty_item_level_bonus.%s" % label, difficulty_item_level_bonus[key], errors)
	if not is_finite(heat_item_levels_per_point) or heat_item_levels_per_point < 0.0:
		errors.append(_error("heat_item_levels_per_point", "must be finite and nonnegative"))
	if not is_finite(pickup_interaction_radius) or pickup_interaction_radius <= 0.0:
		errors.append(_error("pickup_interaction_radius", "must be finite and greater than zero"))
	if not is_finite(controller_target_query_radius) or controller_target_query_radius < pickup_interaction_radius:
		errors.append(_error("controller_target_query_radius", "must be finite and at least pickup_interaction_radius"))
	return errors

func supports_difficulty(difficulty_id: StringName) -> bool:
	return not difficulty_id.is_empty() and difficulty_item_level_bonus.has(difficulty_id)

func _validate_bonus(field: String, value: Variant, errors: PackedStringArray) -> void:
	if typeof(value) != TYPE_INT or int(value) < -ItemGenerationRequest.MAX_ITEM_LEVEL or int(value) > ItemGenerationRequest.MAX_ITEM_LEVEL:
		errors.append(_error(field, "must be an integer from -1000 to 1000"))

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=%s reason=%s" % [field, reason]
