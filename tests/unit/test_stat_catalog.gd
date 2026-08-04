extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := load("res://data/stats/core_stats.tres") as StatCatalog
	TestAssertions.truthy(catalog != null, "core stat catalog loads", failures)
	if catalog == null:
		return failures
	TestAssertions.equal(catalog.validate(), PackedStringArray(), "core stat catalog validates", failures)
	TestAssertions.equal(catalog.definition(&"max_health").display_name, "Maximum Health", "max health metadata", failures)
	TestAssertions.equal(catalog.definition(&"fire_resistance").keyword_id, &"fire_resistance", "resistance keyword identity", failures)
	TestAssertions.near(catalog.definition(&"crit_chance").finalize_value(0.92), 0.75, 0.0001, "crit chance clamps to cap", failures)
	TestAssertions.near(catalog.definition(&"armor").finalize_value(-12.0), 0.0, 0.0001, "armor clamps at zero", failures)
	TestAssertions.equal(catalog.definition(&"life_steal").format_value(0.125), "12.5%", "ratio formatting", failures)
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		var attribute := catalog.definition(attribute_id)
		TestAssertions.truthy(attribute != null, "%s core attribute exists" % attribute_id, failures)
		if attribute == null:
			continue
		TestAssertions.equal(attribute.visibility, StatDefinition.Visibility.UNIVERSAL, "%s is universal" % attribute_id, failures)
		TestAssertions.near(attribute.default_value, 0.0, 0.0001, "%s defaults to zero" % attribute_id, failures)
		TestAssertions.equal(attribute.value_format, StatDefinition.ValueFormat.INTEGER, "%s uses integer formatting" % attribute_id, failures)
		TestAssertions.truthy(GameCatalog.KEYWORD_CATALOG.has_definition(attribute.keyword_id), "%s has a keyword" % attribute_id, failures)

	var duplicate := StatCatalog.new()
	duplicate.definitions = [catalog.definition(&"armor"), catalog.definition(&"armor")]
	TestAssertions.truthy(
		duplicate.validate().has("PARTY_FORGE_STAT_ERROR id=armor reason=duplicate id"),
		"duplicate stat IDs are grep-friendly",
		failures,
	)

	var mutable := StatCatalog.new()
	mutable.definitions = [catalog.definition(&"armor")]
	mutable.definition(&"armor")
	mutable.definitions[0] = catalog.definition(&"max_health")
	TestAssertions.truthy(mutable.definition(&"armor") == null, "replaced stat ID leaves the index", failures)
	TestAssertions.equal(mutable.definition(&"max_health"), catalog.definition(&"max_health"), "replacement stat enters the index", failures)
	return failures
