extends SceneTree

const OUTPUT := "res://data/stats/core_stats.tres"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/stats"))
	var catalog := StatCatalog.new()
	catalog.definitions = [
		_stat(&"max_health", "Maximum Health", &"overview", 100.0, StatDefinition.ValueFormat.INTEGER, 0, true, 1.0, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"armor", "Armor", &"defense", 0.0, StatDefinition.ValueFormat.NUMBER, 1, true, 0.0, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"move_speed", "Movement Speed", &"utility", 6.0, StatDefinition.ValueFormat.NUMBER, 2, true, 0.1, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"damage", "Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"attack_speed", "Attack Speed", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"crit_chance", "Critical Strike Chance", &"offense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 0.75, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"crit_multiplier", "Critical Strike Multiplier", &"offense", 1.5, StatDefinition.ValueFormat.RATIO_PERCENT, 0, true, 1.0, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"attack_range", "Attack Range", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"projectile_speed", "Projectile Speed", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"projectile"]),
		_stat(&"area_size", "Area Size", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"area"]),
		_stat(&"cooldown_rate", "Cooldown Rate", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"cooldown"]),
		_stat(&"healing_power", "Healing Power", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"healing"]),
		_stat(&"dodge_chance", "Dodge Chance", &"defense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 0.75, StatDefinition.Visibility.NON_DEFAULT),
		_stat(&"block_chance", "Block Chance", &"defense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 0.75, StatDefinition.Visibility.NON_DEFAULT),
		_stat(&"block_effectiveness", "Block Effectiveness", &"defense", 0.5, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 1.0, StatDefinition.Visibility.CAPABILITY, [&"block"]),
		_stat(&"health_regeneration", "Health Regeneration", &"defense", 0.0, StatDefinition.ValueFormat.PER_SECOND, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.NON_DEFAULT),
		_stat(&"life_steal", "Life Steal", &"defense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 1.0, StatDefinition.Visibility.NON_DEFAULT),
		_stat(&"pickup_radius", "Pickup Radius", &"utility", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.1, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"physical_damage", "Physical Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"physical"]),
		_stat(&"fire_damage", "Fire Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"fire"]),
		_stat(&"cold_damage", "Cold Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"cold"]),
		_stat(&"lightning_damage", "Lightning Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"lightning"]),
		_stat(&"chaos_damage", "Chaos Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"chaos"]),
		_resistance(&"fire_resistance", "Fire Resistance", &"fire"),
		_resistance(&"cold_resistance", "Cold Resistance", &"cold"),
		_resistance(&"lightning_resistance", "Lightning Resistance", &"lightning"),
		_resistance(&"chaos_resistance", "Chaos Resistance", &"chaos"),
	]
	var result := ResourceSaver.save(catalog, OUTPUT)
	if result != OK:
		push_error("PARTY_FORGE_STAT_ERROR id=catalog reason=save failed code=%d" % result)
	quit(result)

func _resistance(id: StringName, label: String, capability: StringName) -> StatDefinition:
	return _stat(id, label, &"defense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, -1.0, true, 0.75, StatDefinition.Visibility.CAPABILITY, [capability])

func _stat(id: StringName, label: String, group: StringName, base: float, format: StatDefinition.ValueFormat, precision: int, has_min: bool, min_value: float, has_max: bool, max_value: float, visibility: StatDefinition.Visibility, tags: Array[StringName] = []) -> StatDefinition:
	var definition := StatDefinition.new()
	definition.id = id
	definition.display_name = label
	definition.ui_group = group
	definition.default_value = base
	definition.value_format = format
	definition.precision = precision
	definition.has_minimum = has_min
	definition.minimum = min_value
	definition.has_maximum = has_max
	definition.maximum = max_value
	definition.visibility = visibility
	definition.capability_tags = tags
	definition.keyword_id = id
	return definition
