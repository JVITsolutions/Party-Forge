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

	var duplicate := StatCatalog.new()
	duplicate.definitions = [catalog.definition(&"armor"), catalog.definition(&"armor")]
	TestAssertions.truthy(
		duplicate.validate().has("PARTY_FORGE_STAT_ERROR id=armor reason=duplicate id"),
		"duplicate stat IDs are grep-friendly",
		failures,
	)
	return failures
