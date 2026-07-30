extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var types := GameCatalog.load_defaults().damage_types
	var expected := {
		"res://data/attacks/fighter_cleave.tres": [&"physical", 18.0, [&"area", &"melee"]],
		"res://data/attacks/ranger_shot.tres": [&"physical", 11.0, [&"projectile", &"ranged"]],
		"res://data/attacks/mage_burst.tres": [&"fire", 24.0, [&"area", &"fire", &"projectile"]],
		"res://data/attacks/cleric_bolt.tres": [&"lightning", 8.0, [&"lightning", &"projectile"]],
	}
	for path: String in expected:
		var attack := load(path) as AttackDefinition
		TestAssertions.equal(attack.validate(types), PackedStringArray(), "%s validates" % path, failures)
		TestAssertions.equal(attack.damage_components.size(), 1, "%s one component" % path, failures)
		TestAssertions.equal(attack.damage_components[0].damage_type_id, expected[path][0], "%s type" % path, failures)
		TestAssertions.near(attack.damage_components[0].base_amount, expected[path][1], 0.001, "%s amount" % path, failures)
		TestAssertions.equal(attack.normalized_action_tags(), expected[path][2], "%s tags" % path, failures)
		TestAssertions.truthy(attack.can_crit, "%s can crit" % path, failures)
	var heal := load("res://data/attacks/cleric_heal.tres") as AttackDefinition
	TestAssertions.truthy(heal.is_healing() and heal.damage_components.is_empty() and not heal.can_crit, "heal stays positive-only", failures)
	TestAssertions.near(heal.power, 18.0, 0.001, "heal power preserved", failures)
	for path: String in ["res://data/attacks/swarmer_contact.tres", "res://data/attacks/spitter_projectile.tres", "res://data/attacks/guardian_charge.tres", "res://data/attacks/guardian_shockwave.tres"]:
		TestAssertions.equal((load(path) as AttackDefinition).validate(types), PackedStringArray(), "%s validates" % path, failures)
	return failures
