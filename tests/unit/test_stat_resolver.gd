extends RefCounted

const CATALOG: StatCatalog = preload("res://data/stats/core_stats.tres")

func run() -> Array[String]:
	var failures: Array[String] = []
	var source := StatModifierSource.create(&"test_source", &"character", "Test Source", 7, [
		StatModifier.create(&"damage", StatModifier.Operation.FLAT, 20.0, &"flat", "Flat"),
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.30, &"increased", "Increased"),
		StatModifier.create(&"damage", StatModifier.Operation.MORE, 0.10, &"more", "More", [&"projectile"]),
	])
	var plain := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, [], [source], [], 1)
	var projectile := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, [], [source], [&"projectile"], 2)
	TestAssertions.near(plain.value(&"damage"), 156.0, 0.001, "flat and increased order", failures)
	TestAssertions.near(projectile.value(&"damage"), 171.6, 0.001, "approved flat increased more order", failures)
	TestAssertions.equal(projectile.revision, 2, "snapshot carries revision", failures)
	TestAssertions.equal(projectile.breakdown(&"damage").size(), 4, "breakdown contains base and three sources", failures)
	TestAssertions.equal(projectile.breakdown(&"damage")[3]["source_label"], "More", "breakdown preserves source label", failures)

	var tag_source := StatModifierSource.create(&"tag_source", &"character", "Tag Source", 7, [
		StatModifier.create(&"projectile_speed", StatModifier.Operation.INCREASED, 0.25, &"projectile_training", "Projectile Training", [&"projectile"], [&"melee"]),
	])
	var untagged := StatResolver.resolve(7, CATALOG, {}, [], [tag_source], [], 3)
	var tagged := StatResolver.resolve(7, CATALOG, {}, [], [tag_source], [&"projectile"], 4)
	var excluded := StatResolver.resolve(7, CATALOG, {}, [], [tag_source], [&"projectile", &"melee"], 5)
	TestAssertions.near(untagged.value(&"projectile_speed"), 1.0, 0.001, "required tag excludes untagged modifier", failures)
	TestAssertions.near(tagged.value(&"projectile_speed"), 1.25, 0.001, "required tag includes matching modifier", failures)
	TestAssertions.near(excluded.value(&"projectile_speed"), 1.0, 0.001, "excluded tag rejects otherwise matching modifier", failures)

	var capped_source := StatModifierSource.create(&"caps", &"character", "Caps", 7, [
		StatModifier.create(&"crit_chance", StatModifier.Operation.FLAT, 2.0, &"crit", "Crit"),
	])
	var capped := StatResolver.resolve(7, CATALOG, {}, [], [capped_source], [], 6)
	TestAssertions.near(capped.value(&"crit_chance"), 0.75, 0.001, "definition cap applies after arithmetic", failures)

	var mutable_breakdown := projectile.breakdown(&"damage")
	mutable_breakdown[3]["source_label"] = "Changed"
	TestAssertions.equal(projectile.breakdown(&"damage")[3]["source_label"], "More", "breakdown returns defensive copies", failures)
	var capabilities: Array[StringName] = [&"ranged"]
	StatResolver.resolve(7, CATALOG, {}, capabilities, [tag_source], [&"projectile"], 7)
	TestAssertions.equal(capabilities, [&"ranged"], "resolution preserves source capability tags", failures)
	TestAssertions.equal(tag_source.modifiers.size(), 1, "resolution preserves source modifiers", failures)
	return failures
