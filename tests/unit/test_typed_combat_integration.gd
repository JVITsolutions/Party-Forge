extends RefCounted

const DELIVERY_SCENES: PackedStringArray = [
	"res://scenes/combat/projectile.tscn",
	"res://scenes/combat/area_burst.tscn",
	"res://scenes/enemies/enemy_projectile.tscn",
]

const ENEMY_SCENES := {
	&"swarmer": "res://scenes/enemies/swarmer.tscn",
	&"boltcaster": "res://scenes/enemies/boltcaster.tscn",
	&"spitter": "res://scenes/enemies/spitter.tscn",
	&"forge_guardian": "res://scenes/enemies/forge_guardian.tscn",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_no_raw_damage_bypasses(failures)
	var catalog := GameCatalog.load_defaults()
	_test_baseline_catalogs(catalog, failures)
	_test_class_attack_packets(catalog, failures)
	_test_enemy_attack_packets(catalog, failures)
	_test_delivery_scenes(failures)
	return failures

func _test_no_raw_damage_bypasses(failures: Array[String]) -> void:
	var forbidden := {
		"res://scripts/combat/health_component.gd": ["var armor", "maxf(1.0", "func take_damage"],
		"res://scripts/characters/party_actor.gd": ["func receive_damage"],
		"res://scripts/enemies/enemy_actor.gd": ["func receive_damage"],
		"res://scripts/data/enemy_definition.gd": ["contact_damage"],
		"res://scripts/combat/projectile.gd": ["var damage :="],
		"res://scripts/combat/area_burst.gd": ["var damage :="],
		"res://scripts/enemies/enemy_projectile.gd": ["var damage :="],
	}
	for path: String in forbidden:
		var source := FileAccess.get_file_as_string(path)
		TestAssertions.truthy(not source.is_empty(), "typed combat audit reads %s" % path, failures)
		var markers: Array = forbidden[path] as Array
		for marker: String in markers:
			TestAssertions.truthy(not source.contains(marker), "%s removes forbidden marker %s" % [path, marker], failures)

func _test_baseline_catalogs(catalog: GameCatalog, failures: Array[String]) -> void:
	TestAssertions.equal(catalog.classes.size(), 9, "typed combat audit loads nine classes", failures)
	TestAssertions.equal(catalog.enemies.size(), 4, "typed combat audit loads four enemy definitions", failures)
	TestAssertions.equal(PartyManager.STAT_CATALOG.validate(), PackedStringArray(), "baseline stat catalog validates", failures)
	TestAssertions.equal(catalog.damage_types.validate(PartyManager.STAT_CATALOG), PackedStringArray(), "baseline damage type catalog validates", failures)
	TestAssertions.equal(catalog.validate(), PackedStringArray(), "complete baseline game catalog validates", failures)

func _test_class_attack_packets(catalog: GameCatalog, failures: Array[String]) -> void:
	for definition: ClassDefinition in catalog.classes:
		TestAssertions.truthy(definition != null and definition.primary_attack != null, "class primary attack exists", failures)
		if definition == null or definition.primary_attack == null:
			continue
		var party := PartyManager.new()
		party.initialize(definition, catalog.traits)
		var attack := definition.primary_attack
		var tags := DamageResolver.action_tags_for(attack)
		var stats := party.stats_for_action(party.members[0].member_id, tags)
		var source := CombatantAdapter.new(null, StringName("party:audit:%s" % definition.id), 1, null, stats)
		var packet := DamageResolver.prepare(attack, source, CombatRng.new(800 + party.members[0].member_id), catalog.damage_types)
		TestAssertions.truthy(packet.valid, "class %s primary reaches valid packet" % definition.id, failures)
		TestAssertions.equal(packet.attack_id, attack.id, "class %s packet preserves attack id" % definition.id, failures)
		party.free()

func _test_enemy_attack_packets(catalog: GameCatalog, failures: Array[String]) -> void:
	for definition: EnemyDefinition in catalog.enemies:
		TestAssertions.truthy(definition != null and ENEMY_SCENES.has(definition.id), "enemy definition maps to delivery actor", failures)
		if definition == null or not ENEMY_SCENES.has(definition.id):
			continue
		var scene := load(String(ENEMY_SCENES[definition.id])) as PackedScene
		TestAssertions.truthy(scene != null and scene.can_instantiate(), "enemy %s scene instantiates" % definition.id, failures)
		if scene == null or not scene.can_instantiate():
			continue
		var actor := scene.instantiate() as EnemyActor
		actor.configure(definition)
		actor.configure_combat(StringName("audit:%s" % definition.id), CombatRng.new(900), catalog.damage_types)
		for attack: AttackDefinition in definition.attacks:
			var packet := actor.prepare_attack(attack.id)
			TestAssertions.truthy(packet.valid, "enemy %s attack %s reaches valid packet" % [definition.id, attack.id], failures)
			TestAssertions.equal(packet.attack_id, attack.id, "enemy %s packet preserves attack id" % definition.id, failures)
		actor.free()

func _test_delivery_scenes(failures: Array[String]) -> void:
	for path: String in DELIVERY_SCENES:
		var scene := load(path) as PackedScene
		TestAssertions.truthy(scene != null and scene.can_instantiate(), "typed delivery scene instantiates: %s" % path, failures)
		if scene == null or not scene.can_instantiate():
			continue
		var delivery := scene.instantiate() as Node3D
		TestAssertions.truthy(_has_property(delivery, &"packet"), "typed delivery owns packet: %s" % path, failures)
		TestAssertions.truthy(_has_property(delivery, &"combat_rng"), "typed delivery owns combat RNG: %s" % path, failures)
		TestAssertions.truthy(_has_property(delivery, &"damage_types"), "typed delivery owns damage catalog: %s" % path, failures)
		TestAssertions.truthy(not _has_property(delivery, &"damage"), "typed delivery owns no scalar damage: %s" % path, failures)
		delivery.free()

func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false
