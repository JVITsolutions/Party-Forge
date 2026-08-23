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
	var crit_chance := catalog.definition(&"crit_chance")
	TestAssertions.near(crit_chance.default_value, 0.05, 0.0001, "crit chance defaults to five percent", failures)
	TestAssertions.equal(crit_chance.precision, 0, "crit chance displays whole percentage points", failures)
	TestAssertions.truthy(crit_chance.has_minimum, "crit chance has a minimum", failures)
	TestAssertions.near(crit_chance.minimum, 0.0, 0.0001, "crit chance minimum is zero", failures)
	TestAssertions.truthy(not crit_chance.has_maximum, "crit chance has no maximum", failures)
	TestAssertions.near(crit_chance.finalize_value(0.0111), 0.01, 0.0001, "crit chance snaps to whole percentage points", failures)
	TestAssertions.near(crit_chance.finalize_value(1.11), 1.11, 0.0001, "crit chance remains uncapped for multi-crit", failures)
	TestAssertions.near(catalog.definition(&"armor").finalize_value(-12.0), 0.0, 0.0001, "armor clamps at zero", failures)
	TestAssertions.equal(catalog.definition(&"life_steal").format_value(0.125), "12.5%", "ratio formatting", failures)
	TestAssertions.truthy(crit_chance.has_method(&"format_modifier_value"), "stat definitions expose unbounded modifier formatting", failures)
	if crit_chance.has_method(&"format_modifier_value"):
		TestAssertions.equal(crit_chance.call(&"format_modifier_value", 0.0111), "1%", "critical modifier formatting uses whole percentage points", failures)
		TestAssertions.equal(catalog.definition(&"crit_multiplier").call(&"format_modifier_value", 0.10), "10%", "modifier formatting ignores absolute stat minimums", failures)
		TestAssertions.equal(catalog.definition(&"health_regeneration").call(&"format_modifier_value", 0.30), "0.30/s", "modifier formatting preserves other definition value formats", failures)
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		var attribute := catalog.definition(attribute_id)
		TestAssertions.truthy(attribute != null, "%s core attribute exists" % attribute_id, failures)
		if attribute == null:
			continue
		TestAssertions.equal(attribute.visibility, StatDefinition.Visibility.UNIVERSAL, "%s is universal" % attribute_id, failures)
		TestAssertions.near(attribute.default_value, 0.0, 0.0001, "%s defaults to zero" % attribute_id, failures)
		TestAssertions.equal(attribute.value_format, StatDefinition.ValueFormat.INTEGER, "%s uses integer formatting" % attribute_id, failures)
		TestAssertions.truthy(GameCatalog.KEYWORD_CATALOG.has_definition(attribute.keyword_id), "%s has a keyword" % attribute_id, failures)
	_assert_archetype_stat(catalog, &"melee_damage", "Melee Damage", &"melee", failures)
	_assert_archetype_stat(catalog, &"ranged_damage", "Ranged Damage", &"ranged", failures)
	_assert_archetype_stat(catalog, &"caster_damage", "Caster Damage", &"caster", failures)
	_assert_keyword(&"melee_damage", "Melee Damage", "Modifies damage dealt by actions whose primary archetype is Melee.", failures)
	_assert_keyword(&"ranged_damage", "Ranged Damage", "Modifies damage dealt by actions whose primary archetype is Ranged.", failures)
	_assert_keyword(&"caster_damage", "Caster Damage", "Modifies damage dealt by actions whose primary archetype is Caster.", failures)
	_assert_keyword(&"party_influence", "Party Influence", "Measures the character's presence and influence within the party.", failures)
	_assert_keyword(&"crit_chance", "Critical Strike Chance", "Each full 100% Critical Strike Chance guarantees another critical damage instance, and the remaining chance is rolled independently.", failures)
	_assert_keyword(&"multi_crit", "Multi-Crit", "Critical Strike Chance above 100% can produce multiple critical damage instances.", failures)
	var influence := catalog.definition(&"party_influence")
	TestAssertions.truthy(influence != null, "party influence stat exists", failures)
	if influence != null:
		TestAssertions.equal(influence.display_name, "Party Influence", "party influence display name", failures)
		TestAssertions.equal(influence.ui_group, &"utility", "party influence UI group", failures)
		TestAssertions.equal(influence.value_format, StatDefinition.ValueFormat.NUMBER, "party influence number format", failures)
		TestAssertions.near(influence.default_value, 0.0, 0.0001, "party influence defaults to zero", failures)
		TestAssertions.truthy(influence.has_minimum, "party influence has minimum", failures)
		TestAssertions.near(influence.minimum, 0.0, 0.0001, "party influence minimum is zero", failures)
		TestAssertions.equal(influence.visibility, StatDefinition.Visibility.NON_DEFAULT, "party influence hides at default", failures)
		TestAssertions.equal(influence.keyword_id, &"party_influence", "party influence keyword identity", failures)
		_assert_default_comparison_direction(influence, "party influence", failures)
		TestAssertions.truthy(GameCatalog.KEYWORD_CATALOG.has_definition(influence.keyword_id), "party influence has a keyword", failures)

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

func _assert_archetype_stat(
	catalog: StatCatalog,
	stat_id: StringName,
	display_name: String,
	capability_tag: StringName,
	failures: Array[String],
) -> void:
	var definition := catalog.definition(stat_id)
	TestAssertions.truthy(definition != null, "%s stat exists" % stat_id, failures)
	if definition == null:
		return
	TestAssertions.equal(definition.display_name, display_name, "%s display name" % stat_id, failures)
	TestAssertions.equal(definition.ui_group, &"offense", "%s UI group" % stat_id, failures)
	TestAssertions.equal(definition.value_format, StatDefinition.ValueFormat.MULTIPLIER, "%s multiplier format" % stat_id, failures)
	TestAssertions.near(definition.default_value, 1.0, 0.0001, "%s defaults to one" % stat_id, failures)
	TestAssertions.truthy(definition.has_minimum, "%s has minimum" % stat_id, failures)
	TestAssertions.near(definition.minimum, 0.0, 0.0001, "%s minimum is zero" % stat_id, failures)
	TestAssertions.equal(definition.visibility, StatDefinition.Visibility.CAPABILITY, "%s has capability visibility" % stat_id, failures)
	TestAssertions.equal(definition.capability_tags, [capability_tag], "%s capability tag" % stat_id, failures)
	TestAssertions.equal(definition.keyword_id, stat_id, "%s keyword identity" % stat_id, failures)
	_assert_default_comparison_direction(definition, String(stat_id), failures)
	TestAssertions.truthy(GameCatalog.KEYWORD_CATALOG.has_definition(definition.keyword_id), "%s has a keyword" % stat_id, failures)

func _assert_default_comparison_direction(definition: StatDefinition, label: String, failures: Array[String]) -> void:
	var found := false
	var value: Variant = null
	for property: Dictionary in definition.get_property_list():
		if StringName(String(property.get("name", ""))) == &"comparison_direction":
			found = true
			value = definition.get(&"comparison_direction")
			break
	TestAssertions.truthy(found, "%s has comparison direction metadata" % label, failures)
	if found:
		TestAssertions.equal(int(value), 0, "%s comparison defaults higher-is-better" % label, failures)

func _assert_keyword(id: StringName, display_name: String, explanation: String, failures: Array[String]) -> void:
	var keyword := GameCatalog.KEYWORD_CATALOG.definition(id)
	TestAssertions.truthy(keyword != null, "%s keyword exists" % id, failures)
	if keyword == null:
		return
	TestAssertions.equal(keyword.display_name, display_name, "%s keyword display name" % id, failures)
	TestAssertions.equal(keyword.explanation, explanation, "%s keyword explanation" % id, failures)
