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
	var capability_snapshot := StatResolver.resolve(7, CATALOG, {}, capabilities, [tag_source], [&"projectile"], 7)
	TestAssertions.equal(capabilities, [&"ranged"], "resolution preserves source capability tags", failures)
	var retrieved_capabilities := capability_snapshot.capabilities
	retrieved_capabilities.append(&"mutated")
	TestAssertions.equal(capability_snapshot.capabilities, [&"ranged"], "snapshot capabilities return defensive copies", failures)
	TestAssertions.equal(tag_source.modifiers.size(), 1, "resolution preserves source modifiers", failures)

	var action_only_modifier := StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.25, &"action_only", "Action Only")
	action_only_modifier.required_action_tags = [&"projectile"]
	var action_only_source := StatModifierSource.create(&"action_only", &"character", "Action Only", 7, [action_only_modifier])
	var projectile_capabilities: Array[StringName] = [&"projectile"]
	var capability_only := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, projectile_capabilities, [action_only_source], [], 8)
	var projectile_action := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, projectile_capabilities, [action_only_source], [&"projectile"], 9)
	TestAssertions.near(capability_only.value(&"damage"), 100.0, 0.001, "action-only tag ignores matching member capability", failures)
	TestAssertions.near(projectile_action.value(&"damage"), 125.0, 0.001, "action-only tag accepts matching action", failures)
	var split_modifier := StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.50, &"split_tags", "Split Tags")
	split_modifier.required_capability_tags = [&"projectile"]
	split_modifier.excluded_capability_tags = [&"caster"]
	split_modifier.required_action_tags = [&"projectile"]
	split_modifier.excluded_action_tags = [&"melee"]
	var split_source := StatModifierSource.create(&"split_tags", &"character", "Split Tags", 7, [split_modifier])
	var split_matching := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, projectile_capabilities, [split_source], [&"projectile"], 10)
	var split_excluded_capability := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, [&"projectile", &"caster"], [split_source], [&"projectile"], 11)
	var split_excluded_action := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, projectile_capabilities, [split_source], [&"projectile", &"melee"], 12)
	TestAssertions.near(split_matching.value(&"damage"), 150.0, 0.001, "split capability and action constraints both match", failures)
	TestAssertions.near(split_excluded_capability.value(&"damage"), 100.0, 0.001, "excluded capability rejects modifier", failures)
	TestAssertions.near(split_excluded_action.value(&"damage"), 100.0, 0.001, "excluded action rejects modifier", failures)

	var global_source := StatModifierSource.create(&"global", &"party", "Global", 0, [
		StatModifier.create(&"damage", StatModifier.Operation.FLAT, 10.0, &"global", "Global"),
	])
	var matching_source := StatModifierSource.create(&"matching", &"character", "Matching", 7, [
		StatModifier.create(&"damage", StatModifier.Operation.FLAT, 20.0, &"matching", "Matching"),
	])
	var foreign_source := StatModifierSource.create(&"foreign", &"character", "Foreign", 8, [
		StatModifier.create(&"damage", StatModifier.Operation.FLAT, 1000.0, &"foreign", "Foreign"),
	])
	var owned := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, [], [global_source, matching_source, foreign_source], [], 8)
	TestAssertions.near(owned.value(&"damage"), 130.0, 0.001, "global and matching owners apply while foreign owner does not", failures)

	var reductions := StatModifierSource.create(&"reductions", &"character", "Reductions", 7, [
		StatModifier.create(&"damage", StatModifier.Operation.REDUCED, 0.20, &"reduced", "Reduced"),
		StatModifier.create(&"damage", StatModifier.Operation.LESS, 0.25, &"less", "Less"),
	])
	var reduced := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, [], [reductions], [], 9)
	TestAssertions.near(reduced.value(&"damage"), 60.0, 0.001, "reduced applies before multiplicative less", failures)

	var required_input: Array[StringName] = [&"projectile"]
	var excluded_input: Array[StringName] = [&"melee"]
	var isolated_modifier := StatModifier.create(&"projectile_speed", StatModifier.Operation.INCREASED, 0.25, &"isolated", "Isolated", required_input, excluded_input)
	required_input.append(&"mutated")
	excluded_input.clear()
	TestAssertions.equal(isolated_modifier.required_tags, [&"projectile"], "modifier copies required tag input", failures)
	TestAssertions.equal(isolated_modifier.excluded_tags, [&"melee"], "modifier copies excluded tag input", failures)
	var modifier_entries: Array[StatModifier] = [isolated_modifier]
	var isolated_source := StatModifierSource.create(&"isolated", &"character", "Isolated", 7, modifier_entries)
	modifier_entries.clear()
	TestAssertions.equal(isolated_source.modifiers.size(), 1, "source copies modifier entry input", failures)
	TestAssertions.equal(isolated_source.modifiers[0], isolated_modifier, "source preserves copied modifier entry", failures)

	TestAssertions.equal(StatResolver.validate_sources(CATALOG, [source]), PackedStringArray(), "valid modifier sources validate", failures)
	var broken_modifiers: Array[StatModifier] = [
		null,
		StatModifier.create(&"missing_stat", StatModifier.Operation.FLAT, 1.0, &"missing", "Missing"),
	]
	var broken_source := StatModifierSource.create(&"broken_source", &"character", "Broken Source", 0, broken_modifiers)
	var invalid_sources: Array[StatModifierSource] = [null, broken_source]
	TestAssertions.equal(StatResolver.validate_sources(CATALOG, invalid_sources), PackedStringArray([
		"PARTY_FORGE_STAT_ERROR source=<null> stat=<unknown> reason=null source",
		"PARTY_FORGE_STAT_ERROR source=broken_source stat=<null> reason=null modifier",
		"PARTY_FORGE_STAT_ERROR source=broken_source stat=missing_stat reason=unknown stat id",
	]), "invalid modifier sources report exact diagnostics", failures)
	return failures
