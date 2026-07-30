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
		definition.primary_attack = saved_attacks[row["attack"]]
		definition.support_action = null
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
