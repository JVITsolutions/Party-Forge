extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var types := GameCatalog.load_defaults().damage_types
	var rows: Array[Dictionary] = [
		{"path":"res://data/attacks/fighter_cleave.tres", "id":&"fighter_cleave", "kind":AttackDefinition.Kind.MELEE_CLEAVE, "type":&"physical", "amount":18.0, "cooldown":0.8, "range":2.2, "speed":0.0, "area":1.6, "tags":[&"area", &"melee"], "crit":true},
		{"path":"res://data/attacks/ranger_shot.tres", "id":&"ranger_shot", "kind":AttackDefinition.Kind.PROJECTILE, "type":&"physical", "amount":11.0, "cooldown":0.55, "range":11.0, "speed":16.0, "area":0.0, "tags":[&"projectile", &"ranged"], "crit":true},
		{"path":"res://data/attacks/mage_burst.tres", "id":&"mage_burst", "kind":AttackDefinition.Kind.AREA_PROJECTILE, "type":&"fire", "amount":24.0, "cooldown":1.5, "range":12.0, "speed":11.0, "area":2.5, "tags":[&"area", &"fire", &"projectile"], "crit":true},
		{"path":"res://data/attacks/cleric_bolt.tres", "id":&"cleric_bolt", "kind":AttackDefinition.Kind.PROJECTILE, "type":&"lightning", "amount":8.0, "cooldown":1.0, "range":10.0, "speed":13.0, "area":0.0, "tags":[&"lightning", &"projectile"], "crit":true},
		{"path":"res://data/attacks/cleric_heal.tres", "id":&"cleric_heal", "kind":AttackDefinition.Kind.HEAL, "type":&"", "power":18.0, "cooldown":3.0, "range":9.0, "speed":0.0, "area":0.0, "tags":[&"healing"], "crit":false},
		{"path":"res://data/attacks/swarmer_contact.tres", "id":&"swarmer_contact", "kind":AttackDefinition.Kind.DIRECT, "type":&"physical", "amount":8.0, "cooldown":0.8, "range":0.9, "speed":0.0, "area":0.0, "tags":[&"contact", &"melee"], "crit":false},
		{"path":"res://data/attacks/spitter_projectile.tres", "id":&"spitter_projectile", "kind":AttackDefinition.Kind.PROJECTILE, "type":&"physical", "amount":10.0, "cooldown":2.2, "range":18.0, "speed":6.0, "area":0.0, "tags":[&"projectile", &"ranged"], "crit":false},
		{"path":"res://data/attacks/guardian_charge.tres", "id":&"guardian_charge", "kind":AttackDefinition.Kind.DIRECT, "type":&"physical", "amount":22.0, "cooldown":1.0, "range":2.4, "speed":0.0, "area":0.0, "tags":[&"charge", &"melee"], "crit":false},
		{"path":"res://data/attacks/guardian_shockwave.tres", "id":&"guardian_shockwave", "kind":AttackDefinition.Kind.AREA, "type":&"physical", "amount":22.0, "cooldown":1.0, "range":6.0, "speed":0.0, "area":6.0, "tags":[&"area", &"shockwave"], "crit":false},
	]
	for row: Dictionary in rows:
		var path: String = row["path"]
		var attack := load(path) as AttackDefinition
		TestAssertions.truthy(attack != null, "%s loads" % path, failures)
		if attack == null:
			continue
		TestAssertions.equal(attack.validate(types), PackedStringArray(), "%s validates" % path, failures)
		TestAssertions.equal(attack.id, row["id"], "%s id" % path, failures)
		TestAssertions.equal(attack.kind, row["kind"], "%s kind" % path, failures)
		TestAssertions.near(attack.cooldown, row["cooldown"], 0.001, "%s cooldown" % path, failures)
		TestAssertions.near(attack.range, row["range"], 0.001, "%s range" % path, failures)
		TestAssertions.near(attack.projectile_speed, row["speed"], 0.001, "%s projectile speed" % path, failures)
		TestAssertions.near(attack.area_radius, row["area"], 0.001, "%s area radius" % path, failures)
		TestAssertions.equal(attack.normalized_action_tags(), row["tags"], "%s normalized tags" % path, failures)
		TestAssertions.equal(attack.can_crit, row["crit"], "%s can crit" % path, failures)
		if StringName(row["type"]).is_empty():
			TestAssertions.truthy(attack.is_healing(), "%s is healing" % path, failures)
			TestAssertions.equal(attack.damage_components.size(), 0, "%s has no damage components" % path, failures)
			TestAssertions.near(attack.power, row["power"], 0.001, "%s heal power" % path, failures)
		else:
			TestAssertions.truthy(not attack.is_healing(), "%s is damaging" % path, failures)
			TestAssertions.near(attack.power, 0.0, 0.001, "%s legacy power is zero" % path, failures)
			TestAssertions.equal(attack.damage_components.size(), 1, "%s one damage component" % path, failures)
			if attack.damage_components.size() == 1:
				TestAssertions.equal(attack.damage_components[0].damage_type_id, row["type"], "%s damage type" % path, failures)
				TestAssertions.near(attack.damage_components[0].base_amount, row["amount"], 0.001, "%s damage amount" % path, failures)
	return failures
