extends SceneTree

const ContentRows := preload("res://tools/character_upgrade_content_rows.gd")

func _initialize() -> void:
	var errors := generate()
	for error: String in errors:
		push_error(error)
	if not errors.is_empty():
		quit(1)
		return
	print("PARTY_FORGE_CHARACTER_UPGRADE_DATA_SAVED upgrades=25 names=10 keywords=%d" % ContentRows.KEYWORD_ROWS.size())
	quit(0)

static func generate() -> PackedStringArray:
	var errors := PackedStringArray()
	for path: String in ["res://data/keywords", "res://data/progression", "res://data/names", "res://data/upgrades/cards"]:
		var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
		if directory_error != OK:
			errors.append("PARTY_FORGE_CHARACTER_UPGRADE_DATA_ERROR path=%s reason=directory creation failed error=%d" % [path, directory_error])
	if not errors.is_empty():
		return errors

	_save_keywords(errors)
	_save_experience(errors)
	var pools := _save_name_pools(errors)
	_update_classes(pools, errors)
	_save_upgrades(errors)
	return errors

static func _save_keywords(errors: PackedStringArray) -> void:
	var catalog := KeywordCatalog.new()
	for row: Dictionary in ContentRows.KEYWORD_ROWS:
		var definition := KeywordDefinition.new()
		definition.id = row["id"]
		definition.display_name = row["name"]
		definition.explanation = row["explanation"]
		definition.is_capability_tag = row["capability"]
		catalog.definitions.append(definition)
	_save_checked(catalog, "res://data/keywords/core_keywords.tres", errors)

static func _save_experience(errors: PackedStringArray) -> void:
	_save_checked(ExperienceTuning.new(), "res://data/progression/default_experience.tres", errors)

static func _save_name_pools(errors: PackedStringArray) -> Dictionary:
	var pools := {}
	for row: Dictionary in ContentRows.NAME_ROWS:
		var pool := CharacterNamePool.new()
		pool.id = row["id"]
		pool.names = PackedStringArray(row["names"])
		var path := "res://data/names/%s.tres" % pool.id
		if _save_checked(pool, path, errors):
			var persisted := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as CharacterNamePool
			if persisted == null:
				errors.append("PARTY_FORGE_CHARACTER_UPGRADE_DATA_ERROR path=%s reason=name pool failed to reload" % path)
			else:
				pools[pool.id] = persisted
	return pools

static func _update_classes(pools: Dictionary, errors: PackedStringArray) -> void:
	for row: Dictionary in ContentRows.NAME_ROWS:
		var id: StringName = row["id"]
		if id == &"generic":
			continue
		var path := "res://data/classes/%s.tres" % id
		var definition := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as ClassDefinition
		if definition == null:
			errors.append("PARTY_FORGE_CHARACTER_UPGRADE_DATA_ERROR path=%s reason=class failed to load" % path)
			continue
		definition.name_pool = pools.get(id) as CharacterNamePool
		definition.capability_tags.assign(row["capabilities"])
		_save_checked(definition, path, errors)

static func _save_upgrades(errors: PackedStringArray) -> void:
	for row: Dictionary in ContentRows.CARD_ROWS:
		var definition := UpgradeDefinition.new()
		definition.id = row["id"]
		definition.display_name = row["name"]
		definition.summary = row["summary"]
		definition.description = row["summary"]
		definition.scope = row["scope"]
		definition.allowed_class_ids.assign(row.get("classes", []))
		definition.required_all_tags.assign(row.get("all", []))
		definition.required_any_tags.assign(row.get("any", []))
		definition.excluded_tags.assign(row.get("excluded", []))
		definition.max_rank = row["max"]
		definition.selection_weight = 1.0
		definition.rarity = UpgradeDefinition.Rarity.COMMON
		for effect_row: Dictionary in row["effects"]:
			var effect := StatUpgradeEffect.new()
			effect.stat_id = effect_row["stat"]
			effect.operation = effect_row["operation"]
			effect.value_per_rank = effect_row["value"]
			effect.required_capability_tags.assign(effect_row["capabilities"])
			effect.required_action_tags.assign(effect_row["actions"])
			effect.source_label = definition.display_name
			definition.effects.append(effect)
		definition.tooltip_keyword_ids = _tooltip_keywords(definition)
		_save_checked(definition, "res://data/upgrades/cards/%s.tres" % definition.id, errors)

static func _tooltip_keywords(definition: UpgradeDefinition) -> Array[StringName]:
	var result: Array[StringName] = []
	for tag: StringName in definition.required_all_tags + definition.required_any_tags + definition.excluded_tags:
		_append_unique(result, tag)
	for effect_definition: UpgradeEffectDefinition in definition.effects:
		var effect := effect_definition as StatUpgradeEffect
		if effect == null:
			continue
		_append_unique(result, effect.stat_id)
		var operation_keyword := _operation_keyword(effect.operation)
		_append_unique(result, operation_keyword)
		for tag: StringName in effect.required_capability_tags + effect.excluded_capability_tags + effect.required_action_tags + effect.excluded_action_tags:
			_append_unique(result, tag)
	result.sort()
	return result

static func _operation_keyword(operation: int) -> StringName:
	match operation:
		StatModifier.Operation.INCREASED:
			return &"increased"
		StatModifier.Operation.REDUCED:
			return &"reduced"
		StatModifier.Operation.MORE:
			return &"more"
		StatModifier.Operation.LESS:
			return &"less"
		_:
			return &""

static func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not value.is_empty() and value not in values:
		values.append(value)

static func _save_checked(resource: Resource, path: String, errors: PackedStringArray) -> bool:
	var save_error := ResourceSaver.save(resource, path)
	if save_error == OK:
		return true
	errors.append("PARTY_FORGE_CHARACTER_UPGRADE_DATA_ERROR path=%s reason=save failed error=%d" % [path, save_error])
	return false
