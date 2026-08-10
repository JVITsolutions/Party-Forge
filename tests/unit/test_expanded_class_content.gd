extends RefCounted

const ATTACKS: Array[Dictionary] = [
	{"id": &"paladin_smite", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "type": &"physical", "amount": 16.0, "cooldown": 1.05, "range": 2.1, "speed": 0.0, "area": 1.4, "tags": [&"area", &"melee", &"physical"], "crit": true},
	{"id": &"rogue_flurry", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "type": &"physical", "amount": 8.0, "cooldown": 0.32, "range": 2.0, "speed": 0.0, "area": 0.9, "tags": [&"area", &"melee", &"physical", &"skirmisher"], "crit": true},
	{"id": &"frost_shard", "kind": AttackDefinition.Kind.AREA_PROJECTILE, "type": &"cold", "amount": 20.0, "cooldown": 1.35, "range": 12.5, "speed": 10.0, "area": 3.0, "tags": [&"area", &"caster", &"cold", &"projectile"], "crit": true},
	{"id": &"warlock_bolt", "kind": AttackDefinition.Kind.PROJECTILE, "type": &"chaos", "amount": 30.0, "cooldown": 1.75, "range": 12.5, "speed": 9.0, "area": 0.0, "tags": [&"caster", &"chaos", &"projectile"], "crit": true},
	{"id": &"marksman_heavy_shot", "kind": AttackDefinition.Kind.PROJECTILE, "type": &"physical", "amount": 42.0, "cooldown": 2.2, "range": 16.0, "speed": 22.0, "area": 0.0, "tags": [&"bow", &"physical", &"projectile", &"ranged"], "crit": true},
]

const CLASSES: Array[Dictionary] = [
	{"id": &"paladin", "name": "Paladin", "role": ClassDefinition.Role.FRONTLINE, "color": Color("e6c85f"), "traits": [&"divine", &"vanguard", &"martial"], "tags": [&"area", &"block", &"melee", &"physical", &"regeneration", &"armour_heavy", &"one_hand_hammer", &"shield"], "health": 220.0, "armor": 18.0, "speed": 5.6, "preferred": 2.0, "engagement": 4.5, "tether": 8.5, "attack": &"paladin_smite", "overrides": {&"block_chance": 0.18, &"block_effectiveness": 0.55, &"health_regeneration": 1.5}},
	{"id": &"rogue", "name": "Rogue", "role": ClassDefinition.Role.MIDLINE, "color": Color("a95be8"), "traits": [&"martial", &"skirmisher"], "tags": [&"area", &"crit", &"dodge", &"life_steal", &"melee", &"physical", &"armour_light", &"dagger", &"dual_wield"], "health": 72.0, "armor": 0.0, "speed": 7.4, "preferred": 1.4, "engagement": 3.0, "tether": 8.0, "attack": &"rogue_flurry", "overrides": {&"crit_chance": 0.20, &"crit_multiplier": 1.75, &"dodge_chance": 0.18, &"life_steal": 0.05}},
	{"id": &"frost_mage", "name": "Frost Mage", "role": ClassDefinition.Role.BACKLINE, "color": Color("70c8ff"), "traits": [&"arcane", &"caster", &"cold"], "tags": [&"area", &"cold", &"projectile", &"armour_light", &"caster_staff"], "health": 78.0, "armor": 0.0, "speed": 6.0, "preferred": 6.5, "engagement": 12.5, "tether": 12.5, "attack": &"frost_shard", "overrides": {}},
	{"id": &"warlock", "name": "Warlock", "role": ClassDefinition.Role.BACKLINE, "color": Color("7e4bc4"), "traits": [&"occult", &"caster", &"chaos"], "tags": [&"chaos", &"life_steal", &"projectile", &"armour_light", &"occult_wand", &"occult_grimoire"], "health": 82.0, "armor": 1.0, "speed": 5.8, "preferred": 6.0, "engagement": 12.5, "tether": 12.5, "attack": &"warlock_bolt", "overrides": {&"chaos_damage": 1.10, &"life_steal": 0.12}},
	{"id": &"marksman", "name": "Marksman", "role": ClassDefinition.Role.MIDLINE, "color": Color(0.27579924, 0.36415747, 0.056183092, 1.0), "traits": [&"martial", &"ranged", &"bow"], "tags": [&"bow", &"crit", &"physical", &"projectile", &"ranged", &"armour_light", &"armour_medium", &"bow_light_medium", &"greatbow"], "health": 80.0, "armor": 2.0, "speed": 5.8, "preferred": 8.0, "engagement": 16.0, "tether": 16.0, "attack": &"marksman_heavy_shot", "overrides": {&"crit_chance": 0.10, &"crit_multiplier": 2.0}},
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var types := GameCatalog.load_defaults().damage_types
	for row: Dictionary in ATTACKS:
		var path := "res://data/attacks/%s.tres" % row["id"]
		TestAssertions.truthy(ResourceLoader.exists(path), "%s attack path exists" % row["id"], failures)
		if not ResourceLoader.exists(path):
			continue
		var attack := load(path) as AttackDefinition
		TestAssertions.truthy(attack != null, "%s attack loads" % row["id"], failures)
		if attack == null:
			continue
		TestAssertions.equal(attack.validate(types), PackedStringArray(), "%s validates" % row["id"], failures)
		TestAssertions.equal(attack.kind, row["kind"], "%s kind" % row["id"], failures)
		TestAssertions.near(attack.power, 0.0, 0.001, "%s legacy power is zero" % row["id"], failures)
		TestAssertions.near(attack.cooldown, row["cooldown"], 0.001, "%s cooldown" % row["id"], failures)
		TestAssertions.near(attack.range, row["range"], 0.001, "%s range" % row["id"], failures)
		TestAssertions.near(attack.projectile_speed, row["speed"], 0.001, "%s speed" % row["id"], failures)
		TestAssertions.near(attack.area_radius, row["area"], 0.001, "%s area" % row["id"], failures)
		TestAssertions.equal(attack.normalized_action_tags(), row["tags"], "%s tags" % row["id"], failures)
		TestAssertions.equal(attack.can_crit, row["crit"], "%s crit" % row["id"], failures)
		TestAssertions.equal(attack.damage_components.size(), 1, "%s one component" % row["id"], failures)
		if attack.damage_components.size() == 1:
			TestAssertions.equal(attack.damage_components[0].damage_type_id, row["type"], "%s type" % row["id"], failures)
			TestAssertions.near(attack.damage_components[0].base_amount, row["amount"], 0.001, "%s amount" % row["id"], failures)
	for row: Dictionary in CLASSES:
		var path := "res://data/classes/%s.tres" % row["id"]
		TestAssertions.truthy(ResourceLoader.exists(path), "%s class path exists" % row["id"], failures)
		if not ResourceLoader.exists(path):
			continue
		var definition := load(path) as ClassDefinition
		TestAssertions.truthy(definition != null, "%s class loads" % row["id"], failures)
		if definition == null:
			continue
		TestAssertions.equal(definition.validate(types), PackedStringArray(), "%s validates" % row["id"], failures)
		TestAssertions.equal(definition.display_name, row["name"], "%s name" % row["id"], failures)
		TestAssertions.equal(definition.role, row["role"], "%s role" % row["id"], failures)
		TestAssertions.equal(definition.color, row["color"], "%s color" % row["id"], failures)
		TestAssertions.equal(definition.traits, row["traits"], "%s traits" % row["id"], failures)
		TestAssertions.equal(definition.capability_tags, row["tags"], "%s tags" % row["id"], failures)
		TestAssertions.near(definition.max_health, row["health"], 0.001, "%s health" % row["id"], failures)
		TestAssertions.near(definition.armor, row["armor"], 0.001, "%s armor" % row["id"], failures)
		TestAssertions.near(definition.move_speed, row["speed"], 0.001, "%s move speed" % row["id"], failures)
		TestAssertions.near(definition.preferred_distance, row["preferred"], 0.001, "%s preferred" % row["id"], failures)
		TestAssertions.near(definition.engagement_distance, row["engagement"], 0.001, "%s engagement" % row["id"], failures)
		TestAssertions.near(definition.tether_distance, row["tether"], 0.001, "%s tether" % row["id"], failures)
		TestAssertions.truthy(definition.primary_attack != null, "%s attack link exists" % row["id"], failures)
		if definition.primary_attack != null:
			TestAssertions.equal(definition.primary_attack.id, row["attack"], "%s attack link" % row["id"], failures)
		TestAssertions.equal(definition.base_stat_overrides, row["overrides"], "%s overrides" % row["id"], failures)
	return failures
