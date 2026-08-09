extends RefCounted

const EXPECTED_PRIMARY := {
	&"fighter": &"melee",
	&"ranger": &"ranged",
	&"marksman": &"ranged",
	&"rogue": &"melee",
	&"paladin": &"melee",
	&"mage": &"caster",
	&"frost_mage": &"caster",
	&"cleric": &"caster",
	&"warlock": &"caster",
}

var _action_archetype: Variant
var _damage_projection: Variant

func run() -> Array[String]:
	var failures: Array[String] = []
	_action_archetype = load("res://scripts/combat/action_archetype.gd")
	_damage_projection = load("res://scripts/combat/action_damage_projection.gd")
	TestAssertions.truthy(_action_archetype != null, "action archetype service exists", failures)
	TestAssertions.truthy(_damage_projection != null, "action damage projection service exists", failures)
	if _action_archetype == null or _damage_projection == null:
		return failures
	_test_primary_tag_contract(failures)
	_test_playable_class_validation(failures)
	_test_live_class_primaries(failures)
	_test_shared_component_projection(failures)
	return failures

func _test_primary_tag_contract(failures: Array[String]) -> void:
	var melee := _damage_attack(&"melee_fixture", [&"melee"])
	TestAssertions.equal(_action_archetype.primary_tag(melee), &"melee", "one primary tag resolves", failures)
	TestAssertions.equal(_action_archetype.stat_id(melee), &"melee_damage", "primary tag maps to canonical stat", failures)
	TestAssertions.equal(_action_archetype.primary_tag(_damage_attack(&"untagged", [])), &"", "missing primary tag does not guess", failures)
	TestAssertions.equal(_action_archetype.primary_tag(_damage_attack(&"conflicting", [&"melee", &"ranged"])), &"", "conflicting primary tags do not guess", failures)
	TestAssertions.equal(_action_archetype.stat_id(null), &"", "missing action has no archetype stat", failures)

func _test_playable_class_validation(failures: Array[String]) -> void:
	var fighter := GameCatalog.load_defaults().class_by_id(&"fighter").duplicate(true) as ClassDefinition
	var untagged := _damage_attack(&"untagged", [])
	fighter.primary_attack = untagged
	TestAssertions.truthy(
		fighter.validate().has("class fighter primary PARTY_FORGE_DAMAGE_ERROR attack=untagged reason=expected exactly one primary archetype"),
		"playable damage action rejects a missing primary archetype",
		failures,
	)

	var conflicting := _damage_attack(&"conflicting", [&"melee", &"ranged"])
	fighter.primary_attack = conflicting
	TestAssertions.truthy(
		fighter.validate().has("class fighter primary PARTY_FORGE_DAMAGE_ERROR attack=conflicting reason=expected exactly one primary archetype"),
		"playable damage action rejects conflicting primary archetypes",
		failures,
	)

	var heal := AttackDefinition.new()
	heal.id = &"archetype_free_heal"
	heal.kind = AttackDefinition.Kind.HEAL
	heal.power = 5.0
	heal.cooldown = 1.0
	heal.range = 1.0
	TestAssertions.equal(_action_archetype.validate_player_damage_action(heal), PackedStringArray(), "healing does not require a damage archetype", failures)

func _test_live_class_primaries(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	for class_id: StringName in EXPECTED_PRIMARY:
		var attack := catalog.class_by_id(class_id).primary_attack
		var expected: StringName = EXPECTED_PRIMARY[class_id]
		TestAssertions.equal(_action_archetype.primary_tag(attack), expected, "%s has exactly one primary archetype" % class_id, failures)
		TestAssertions.equal(_action_archetype.stat_id(attack), StringName("%s_damage" % expected), "%s maps to its archetype stat" % class_id, failures)
		TestAssertions.equal(_action_archetype.validate_player_damage_action(attack), PackedStringArray(), "%s primary validates" % class_id, failures)

func _test_shared_component_projection(failures: Array[String]) -> void:
	TestAssertions.near(_damage_projection.normal_component(10.0, 1.20, 1.30, 1.40), 21.84, 0.0001, "global, archetype, and type scaling multiply once", failures)
	TestAssertions.truthy(is_nan(_damage_projection.normal_component(-1.0, 1.0, 1.0, 1.0)), "negative projection input is rejected", failures)
	TestAssertions.truthy(is_nan(_damage_projection.normal_component(1.0, INF, 1.0, 1.0)), "non-finite projection input is rejected", failures)

func _damage_attack(id: StringName, tags: Array[StringName]) -> AttackDefinition:
	var component := AttackDamageComponent.new()
	component.damage_type_id = &"physical"
	component.base_amount = 1.0
	var attack := AttackDefinition.new()
	attack.id = id
	attack.kind = AttackDefinition.Kind.MELEE_CLEAVE
	attack.cooldown = 1.0
	attack.range = 1.0
	attack.damage_components = [component]
	attack.action_tags = tags
	return attack
