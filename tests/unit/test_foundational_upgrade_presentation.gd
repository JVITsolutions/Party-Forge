extends RefCounted


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_class_rank_uses_definition_step(failures)
	_test_other_foundational_choices_are_specific(failures)
	_test_fractional_trait_percentages(failures)
	_test_production_trait_keyword_mappings(failures)
	_test_level_up_panel_routes_foundational_and_authored_tooltips(failures)
	return failures


func _test_class_rank_uses_definition_step(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var choice := UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"fighter", "Train Fighter")

	var card := FoundationalUpgradePresentationService.card(choice, party, catalog)
	TestAssertions.equal(card.rank_text, "Rank 1 -> 2", "class rank shows transition", failures)
	TestAssertions.truthy("0%" in card.summary and "20%" in card.summary, "class rank shows exact damage change", failures)
	TestAssertions.truthy("current and future Fighters" in card.inheritance_text, "class rank explains inheritance", failures)
	TestAssertions.truthy("all current Fighters" in card.recipient_text, "class rank explains current ownership", failures)

	var tooltip := FoundationalUpgradePresentationService.tooltip(choice, party, catalog)
	TestAssertions.equal(tooltip.rank_text, "Rank 1 -> 2", "class rank tooltip shows transition", failures)
	TestAssertions.equal(tooltip.effect_lines, ["0% -> 20% increased Damage."], "class rank tooltip shows exact effect", failures)
	TestAssertions.truthy(
		(tooltip.keyword_lines as Array).any(func(line: String) -> bool: return line.begins_with("Damage:")),
		"class rank tooltip explains Damage",
		failures,
	)
	TestAssertions.truthy(
		(tooltip.keyword_lines as Array).any(func(line: String) -> bool: return line.begins_with("Increased:")),
		"class rank tooltip explains Increased",
		failures,
	)

	TestAssertions.truthy(party.rank_up(&"fighter"), "class rank fixture advances", failures)
	var next_card := FoundationalUpgradePresentationService.card(choice, party, catalog)
	TestAssertions.equal(next_card.rank_text, "Rank 2 -> 3", "next class rank shows transition", failures)
	TestAssertions.equal(next_card.summary, "20% -> 40% increased Damage.", "next class rank shows exact damage change", failures)
	party.free()

	var fixture_catalog := GameCatalog.load_defaults()
	var fighter_fixture := fixture_catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	fighter_fixture.class_rank_power_step = 0.15
	for index: int in fixture_catalog.classes.size():
		if fixture_catalog.classes[index].id == &"fighter":
			fixture_catalog.classes[index] = fighter_fixture
			break
	var fixture_party := PartyManager.new()
	fixture_party.initialize(fighter_fixture, fixture_catalog.traits)
	TestAssertions.truthy(fixture_party.rank_up(&"fighter"), "custom-step fixture advances", failures)
	var fixture_card := FoundationalUpgradePresentationService.card(choice, fixture_party, fixture_catalog)
	TestAssertions.equal(fixture_card.summary, "15% -> 30% increased Damage.", "class rank reads definition step", failures)
	fixture_party.free()


func _test_other_foundational_choices_are_specific(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)

	var recruit := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger")
	var recruit_card := FoundationalUpgradePresentationService.card(recruit, party, catalog)
	var recruit_tooltip := FoundationalUpgradePresentationService.tooltip(recruit, party, catalog)
	TestAssertions.truthy("Ranger" in recruit_card.summary, "recruit card names the recruited class", failures)
	TestAssertions.truthy("Ranger" in recruit_tooltip.description, "recruit tooltip describes the recruited class", failures)
	TestAssertions.truthy(
		(recruit_tooltip.keyword_lines as Array).any(func(line: String) -> bool: return line.begins_with("Ranged:")),
		"recruit tooltip explains a class trait",
		failures,
	)

	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "trait fixture activates Vanguard", failures)
	var trait_choice := UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, &"vanguard", "Strengthen Vanguard")
	var trait_card := FoundationalUpgradePresentationService.card(trait_choice, party, catalog)
	var trait_tooltip := FoundationalUpgradePresentationService.tooltip(trait_choice, party, catalog)
	TestAssertions.truthy("Vanguard" in trait_card.summary and "12%" in trait_card.summary and "15%" in trait_card.summary, "trait card shows its exact next benefit", failures)
	TestAssertions.truthy(
		(trait_tooltip.keyword_lines as Array).any(func(line: String) -> bool: return line.begins_with("Vanguard:")),
		"trait tooltip explains the trait",
		failures,
	)

	var party_stat := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage")
	var stat_card := FoundationalUpgradePresentationService.card(party_stat, party, catalog)
	var stat_tooltip := FoundationalUpgradePresentationService.tooltip(party_stat, party, catalog)
	TestAssertions.equal(stat_card.summary, "0% -> 5% increased Damage.", "party stat card shows exact next benefit", failures)
	TestAssertions.truthy("current and future party members" in stat_card.inheritance_text, "party stat card explains inheritance", failures)
	TestAssertions.truthy(
		(stat_tooltip.keyword_lines as Array).any(func(line: String) -> bool: return line.begins_with("Damage:")),
		"party stat tooltip explains its stat",
		failures,
	)
	party.free()


func _test_fractional_trait_percentages(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for fixture: Array in [
		[&"arcane", "Arcane: 18% -> 22.5% Area Size."],
		[&"chaos", "Chaos: 15% -> 18.75% Chaos Damage."],
	]:
		var trait_id: StringName = fixture[0]
		var definition := catalog.trait_by_id(trait_id)
		party.active_tiers[trait_id] = _lowest_tier(definition)
		var choice := UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, trait_id, "Strengthen %s" % definition.display_name)
		var card := FoundationalUpgradePresentationService.card(choice, party, catalog)
		var tooltip := FoundationalUpgradePresentationService.tooltip(choice, party, catalog)
		TestAssertions.equal(card.summary, fixture[1], "%s card preserves fractional percent" % trait_id, failures)
		TestAssertions.equal(tooltip.effect_lines, [fixture[1]], "%s tooltip preserves fractional percent" % trait_id, failures)
	party.free()


func _test_production_trait_keyword_mappings(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	TestAssertions.truthy(catalog.keywords.definition(&"less") != null, "Less keyword exists for multiplicative Vanguard reduction", failures)
	var compound_prefixes := {
		&"cooldown_reduction": ["Cooldown Rate:"],
		&"healing_and_revive": ["Healing Power:", "Healing:"],
		&"nearby_damage_reduction": ["Less:"],
		&"projectile_speed_and_range": ["Projectile Speed:", "Attack Range:"],
		&"support_power": ["Healing Power:"],
	}
	for definition: TraitDefinition in catalog.traits:
		party.active_tiers[definition.id] = _lowest_tier(definition)
		var choice := UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, definition.id, "Strengthen %s" % definition.display_name)
		var tooltip := FoundationalUpgradePresentationService.tooltip(choice, party, catalog)
		var keyword_lines: Array = tooltip.keyword_lines
		TestAssertions.truthy(
			not keyword_lines.any(func(line: String) -> bool: return line.begins_with("Missing definition:")),
			"%s production tooltip has no missing keyword diagnostics" % definition.id,
			failures,
		)
		TestAssertions.truthy(
			keyword_lines.any(func(line: String) -> bool: return line.begins_with("%s:" % definition.display_name)),
			"%s tooltip includes its trait keyword" % definition.id,
			failures,
		)
		var expected_prefixes: Array = compound_prefixes.get(definition.stat_id, [])
		if expected_prefixes.is_empty() and catalog.keywords.definition(definition.stat_id) != null:
			expected_prefixes = ["%s:" % catalog.keywords.definition(definition.stat_id).display_name]
		for prefix: String in expected_prefixes:
			TestAssertions.truthy(
				keyword_lines.any(func(line: String) -> bool: return line.begins_with(prefix)),
				"%s tooltip includes mapped %s meaning" % [definition.id, prefix.trim_suffix(":")],
				failures,
			)
	party.free()


func _test_level_up_panel_routes_foundational_and_authored_tooltips(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var foundational := UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"fighter", "Train Fighter")
	var authored := UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality"))
	var panel := (load("res://scenes/ui/level_up_panel.tscn") as PackedScene).instantiate() as LevelUpPanel
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	panel.configure(catalog, UpgradeApplicationService.new(), Callable())
	panel.show_choices([
		foundational,
		authored,
		UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"),
	], party)

	var cards := panel.get_node("ContentPanel/OfferView/Content/Cards").get_children()
	panel.call("_on_card_detail_requested", foundational, cards[0] as Control)
	var tooltip := panel.get_node("TooltipPanel") as UpgradeTooltipPanel
	TestAssertions.truthy(tooltip.visible, "foundational detail request opens the shared tooltip", failures)
	TestAssertions.equal((tooltip.get_node("Content/Header/Title") as Label).text, "Train Fighter", "foundational tooltip uses service content", failures)
	panel.call("_on_card_detail_dismissed", foundational)

	panel.call("_on_card_detail_requested", authored, cards[1] as Control)
	TestAssertions.equal((tooltip.get_node("Content/Header/Title") as Label).text, "Vitality", "authored tooltip routing remains intact", failures)
	panel.free()
	party.free()


func _lowest_tier(definition: TraitDefinition) -> int:
	var result := 0
	for threshold: Variant in definition.tiers.keys():
		if result == 0 or int(threshold) < result:
			result = int(threshold)
	return result
