extends SceneTree

const ExpansionRows := preload("res://tools/class_expansion_rows.gd")

var _failures := 0

func _initialize() -> void:
	for path: String in ["res://data/attacks", "res://data/classes"]:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
		if error != OK:
			_record_error(path, "directory creation failed error=%d" % error)
	if _failures > 0:
		_finish()
		return

	for row: Dictionary in ExpansionRows.ATTACK_ROWS:
		var attack := load(row["path"]) as AttackDefinition if ResourceLoader.exists(row["path"]) else AttackDefinition.new()
		attack.id = row["id"]
		attack.kind = row["kind"]
		attack.power = 0.0
		attack.cooldown = row["cooldown"]
		attack.range = row["range"]
		attack.projectile_speed = row["speed"]
		attack.area_radius = row["area"]
		attack.action_tags.assign(row["tags"])
		attack.can_crit = row["crit"]
		attack.damage_components.clear()
		var component := AttackDamageComponent.new()
		component.damage_type_id = row["type"]
		component.base_amount = row["amount"]
		attack.damage_components.append(component)
		_save_checked(attack, row["path"])
	if _failures > 0:
		_finish()
		return

	var types := GameCatalog.load_defaults().damage_types
	var saved_attacks: Dictionary = {}
	for row: Dictionary in ExpansionRows.ATTACK_ROWS:
		var attack := ResourceLoader.load(row["path"], "", ResourceLoader.CACHE_MODE_REPLACE) as AttackDefinition
		if attack == null:
			_record_error(row["path"], "saved attack failed to reload")
			continue
		saved_attacks[row["id"]] = attack
		_validate_checked(attack.validate(types), row["path"])
	if _failures > 0:
		_finish()
		return

	for row: Dictionary in ExpansionRows.CLASS_ROWS:
		var definition := load(row["path"]) as ClassDefinition if ResourceLoader.exists(row["path"]) else ClassDefinition.new()
		var primary_attack := saved_attacks[row["attack"]] as AttackDefinition
		var already_canonical := class_matches_row(definition, row, primary_attack)
		definition.id = row["id"]
		definition.display_name = row["name"]
		definition.role = row["role"]
		definition.color = row["color"]
		definition.traits.assign(row["traits"])
		definition.capability_tags.assign(row["tags"])
		definition.base_stat_overrides = row["overrides"].duplicate(true)
		definition.max_health = row["health"]
		definition.armor = row["armor"]
		definition.move_speed = row["speed"]
		definition.class_rank_power_step = 0.2
		definition.revive_delay = 8.0
		definition.revive_health_fraction = 0.5
		definition.preferred_distance = row["preferred"]
		definition.engagement_distance = row["engagement"]
		definition.tether_distance = row["tether"]
		definition.primary_attack = primary_attack
		definition.support_action = null
		if not already_canonical:
			_save_checked(definition, row["path"])
	if _failures > 0:
		_finish()
		return

	for row: Dictionary in ExpansionRows.CLASS_ROWS:
		var definition := ResourceLoader.load(row["path"], "", ResourceLoader.CACHE_MODE_REPLACE) as ClassDefinition
		if definition == null:
			_record_error(row["path"], "saved class failed to reload")
			continue
		_validate_checked(definition.validate(types), row["path"])
	_finish()

static func class_matches_row(definition: ClassDefinition, row: Dictionary, primary_attack: AttackDefinition) -> bool:
	if definition == null or primary_attack == null:
		return false
	var row_traits: Array[StringName] = []
	row_traits.assign(row.get("traits", []))
	var row_tags: Array[StringName] = []
	row_tags.assign(row.get("tags", []))
	return (
		definition.id == StringName(row.get("id", &""))
		and definition.display_name == String(row.get("name", ""))
		and definition.role == int(row.get("role", -1))
		and definition.color == row.get("color", Color.WHITE)
		and definition.traits == row_traits
		and definition.capability_tags == row_tags
		and definition.base_stat_overrides == row.get("overrides", {})
		and definition.max_health == float(row.get("health", 0.0))
		and definition.armor == float(row.get("armor", 0.0))
		and definition.move_speed == float(row.get("speed", 0.0))
		and definition.class_rank_power_step == 0.2
		and definition.revive_delay == 8.0
		and definition.revive_health_fraction == 0.5
		and definition.preferred_distance == float(row.get("preferred", 0.0))
		and definition.engagement_distance == float(row.get("engagement", 0.0))
		and definition.tether_distance == float(row.get("tether", 0.0))
		and definition.primary_attack != null
		and definition.primary_attack.resource_path == primary_attack.resource_path
		and definition.support_action == null
	)

func _save_checked(resource: Resource, path: String) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		_record_error(path, "save failed error=%d" % error)

func _validate_checked(errors: PackedStringArray, path: String) -> void:
	for reason: String in errors:
		_record_error(path, reason)

func _record_error(path: String, reason: String) -> void:
	_failures += 1
	push_error("PARTY_FORGE_CLASS_EXPANSION_ERROR path=%s reason=%s" % [path, reason])

func _finish() -> void:
	if _failures > 0:
		quit(1)
		return
	print("PARTY_FORGE_CLASS_EXPANSION_SAVED attacks=5 classes=5")
	quit(0)
