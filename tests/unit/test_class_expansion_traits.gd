extends RefCounted

const EXPECTED: Array[Dictionary] = [
	{"id": &"fire", "name": "Fire", "stat": &"fire_damage", "tiers": {2: 0.15, 4: 0.35}, "resolved": 1.15},
	{"id": &"cold", "name": "Cold", "stat": &"cold_damage", "tiers": {2: 0.15, 4: 0.35}, "resolved": 1.15},
	{"id": &"skirmisher", "name": "Skirmisher", "stat": &"dodge_chance", "tiers": {2: 0.08, 4: 0.18}, "resolved": 0.08},
	{"id": &"occult", "name": "Occult", "stat": &"life_steal", "tiers": {2: 0.04, 4: 0.10}, "resolved": 0.04},
	{"id": &"chaos", "name": "Chaos", "stat": &"chaos_damage", "tiers": {2: 0.15, 4: 0.35}, "resolved": 1.15},
	{"id": &"bow", "name": "Bow", "stat": &"attack_range", "tiers": {2: 0.12, 4: 0.28}, "resolved": 1.12},
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	for row: Dictionary in EXPECTED:
		var trait_definition := load("res://data/traits/%s.tres" % row["id"]) as TraitDefinition
		TestAssertions.truthy(trait_definition != null, "%s trait loads" % row["id"], failures)
		if trait_definition == null:
			continue
		TestAssertions.equal(trait_definition.id, row["id"], "%s id" % row["id"], failures)
		TestAssertions.equal(trait_definition.display_name, row["name"], "%s name" % row["id"], failures)
		TestAssertions.equal(trait_definition.stat_id, row["stat"], "%s stat" % row["id"], failures)
		TestAssertions.equal(trait_definition.tiers, row["tiers"], "%s tiers" % row["id"], failures)
		TestAssertions.equal(trait_definition.validate(), PackedStringArray(), "%s validates" % row["id"], failures)
		var definition := ClassDefinition.new()
		definition.id = StringName("trait_test_%s" % row["id"])
		definition.display_name = "Trait Test"
		definition.traits = [row["id"]]
		definition.primary_attack = catalog.class_by_id(&"fighter").primary_attack
		var party := PartyManager.new()
		party.initialize(definition, catalog.traits)
		party.recruit(definition)
		TestAssertions.near(
			party.stats_for(party.members[0].member_id).value(row["stat"]),
			row["resolved"],
			0.001,
			"%s tier two changes resolved stat" % row["id"],
			failures,
		)
		party.free()
	TestAssertions.equal(
		catalog.class_by_id(&"mage").traits,
		[&"arcane", &"caster", &"fire"],
		"Mage matches approved Arcane Caster Fire identity",
		failures,
	)
	return failures
