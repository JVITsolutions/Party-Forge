extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_exact_effect_and_keyword_text(failures)
	_test_card_rank_and_inheritance_text(failures)
	_test_capability_and_exclusion_eligibility_text(failures)
	_test_recipient_rows(failures)
	_test_matching_recipient_rows_use_party_rank(failures)
	_test_role_names(failures)
	_test_projection_metadata_is_schema_backed(failures)
	return failures

func _test_projection_metadata_is_schema_backed(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var definition := catalog.upgrade_by_id(&"vitality")
	var card := UpgradePresentationService.card(definition, party)
	TestAssertions.equal(card.get("category_id", &"missing"), &"character", "authored card exposes its schema scope category", failures)
	TestAssertions.equal(card.get("icon_id", &"missing"), &"", "authored card leaves unavailable optional icon empty", failures)
	TestAssertions.equal(card.get("rarity_label", "missing"), "Common", "authored card exposes COMMON rarity", failures)
	TestAssertions.equal(card.get("recipient_tags", []), definition.required_all_tags + definition.required_any_tags, "authored recipient tags follow eligibility schema", failures)
	TestAssertions.equal(card.get("class_tags", []), definition.allowed_class_ids, "authored class tags follow eligibility schema", failures)
	party.free()

func _test_exact_effect_and_keyword_text(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var deadeye := catalog.upgrade_by_id(&"deadeye")
	var content := UpgradePresentationService.tooltip(deadeye, 1, PartyManager.STAT_CATALOG, catalog.keywords)
	var lines: Array = content.get("effect_lines", [])
	TestAssertions.truthy("30% more Physical Damage." in lines, "Deadeye shows exact thirty percent more damage", failures)
	TestAssertions.truthy("20% increased Attack Range." in lines, "Deadeye shows increased attack range", failures)
	TestAssertions.truthy("+0.25 Critical Strike Multiplier." in lines, "Deadeye shows flat critical multiplier", failures)
	TestAssertions.truthy("15% less Attack Speed." in lines, "Deadeye shows its attack-speed trade-off", failures)

	var precision := UpgradePresentationService.tooltip(catalog.upgrade_by_id(&"precision"), 1, PartyManager.STAT_CATALOG, catalog.keywords)
	TestAssertions.truthy("+3 percentage points Critical Strike Chance." in (precision.get("effect_lines", []) as Array), "flat ratio uses percentage points", failures)

	var more_line := "More: A multiplicative modifier applied after increased and reduced values."
	TestAssertions.truthy(more_line in (content.get("keyword_lines", []) as Array), "tooltip explains More", failures)
	TestAssertions.equal((content.get("keyword_lines", []) as Array).size(), deadeye.tooltip_keyword_ids.size(), "tooltip explains every declared keyword", failures)

	for definition: UpgradeDefinition in catalog.upgrades:
		var tooltip := UpgradePresentationService.tooltip(definition, 1, PartyManager.STAT_CATALOG, catalog.keywords)
		var keyword_lines: Array = tooltip.get("keyword_lines", [])
		TestAssertions.equal(keyword_lines.size(), definition.tooltip_keyword_ids.size(), "%s has one explanation per keyword" % definition.id, failures)
		TestAssertions.truthy(not keyword_lines.any(func(line: String) -> bool: return line.begins_with("Missing definition:")), "%s resolves all known keyword definitions" % definition.id, failures)

	var missing_definition := deadeye.duplicate(true) as UpgradeDefinition
	missing_definition.tooltip_keyword_ids = [&"unexpected_keyword"]
	var missing := UpgradePresentationService.tooltip(missing_definition, 1, PartyManager.STAT_CATALOG, catalog.keywords)
	TestAssertions.equal(missing.get("keyword_lines", []), ["Missing definition: unexpected_keyword"], "missing keyword has visible development fallback", failures)

func _test_card_rank_and_inheritance_text(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	var fighter := catalog.class_by_id(&"fighter")
	party.initialize(fighter, catalog.traits)
	party.recruit(fighter)
	var vitality := catalog.upgrade_by_id(&"vitality")
	var even_card := UpgradePresentationService.card(vitality, party)
	TestAssertions.equal(even_card.get("rank_text", ""), "Rank 0 / 5", "shared eligible rank is exact", failures)
	UpgradeApplicationService.apply(&"vitality", catalog, party, 1)
	var varied_card := UpgradePresentationService.card(vitality, party)
	TestAssertions.equal(varied_card.get("rank_text", ""), "Rank varies / 5", "different recipient ranks are explicit", failures)

	var wall_card := UpgradePresentationService.card(catalog.upgrade_by_id(&"vanguard_wall"), party)
	TestAssertions.equal(
		wall_card.get("inheritance_text", ""),
		"Affects every matching current and future party member, including later recruits.",
		"matching-party card promises later recruits",
		failures,
	)
	party.free()

func _test_capability_and_exclusion_eligibility_text(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var projectile_card := UpgradePresentationService.card(
		catalog.upgrade_by_id(&"projectile_mastery"),
		party,
	)
	TestAssertions.equal(
		projectile_card.get("eligibility_text", ""),
		"Requires all traits or capabilities: Projectile",
		"capability-gated card uses neutral eligibility wording",
		failures,
	)

	var exclusion_only := catalog.upgrade_by_id(&"vitality").duplicate(true) as UpgradeDefinition
	exclusion_only.id = &"exclusion_only"
	exclusion_only.scope = UpgradeDefinition.Scope.PARTY
	exclusion_only.allowed_class_ids = []
	exclusion_only.required_all_tags = []
	exclusion_only.required_any_tags = []
	exclusion_only.excluded_tags = [&"projectile"]
	catalog.upgrades.append(exclusion_only)
	var exclusion_errors: Array[String] = []
	for error: String in catalog.validate():
		if "PARTY_FORGE_UPGRADE_ERROR id=exclusion_only" in error:
			exclusion_errors.append(error)
	TestAssertions.truthy(
		exclusion_errors.is_empty(),
		"exclusion-only presentation fixture is catalog-valid",
		failures,
	)
	var exclusion_card := UpgradePresentationService.card(exclusion_only, party)
	TestAssertions.equal(
		exclusion_card.get("eligibility_text", ""),
		"Excludes traits or capabilities: Projectile",
		"exclusion-only card discloses its matching restriction",
		failures,
	)
	TestAssertions.equal(
		exclusion_card.get("inheritance_text", ""),
		"Affects every matching current and future party member, including later recruits.",
		"exclusion-only party card discloses later-recruit matching",
		failures,
	)
	party.free()

func _test_recipient_rows(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	party.members[0].character_name = "Brann"
	party.members[1].character_name = "Hawke"
	var health_provider := func(member_id: int) -> Vector2:
		return Vector2(91.0, 260.0) if member_id == 1 else Vector2(63.0, 80.0)
	var rows := UpgradePresentationService.recipient_rows(catalog.upgrade_by_id(&"deadeye"), party, health_provider)
	TestAssertions.equal(rows.size(), 2, "recipient presentation keeps every party member visible", failures)
	var fighter_row: Dictionary = rows[0]
	var marksman_row: Dictionary = rows[1]
	TestAssertions.equal(fighter_row.get("character_name", ""), "Brann", "recipient uses stored fighter name", failures)
	TestAssertions.equal(marksman_row.get("character_name", ""), "Hawke", "recipient uses stored marksman name", failures)
	TestAssertions.equal(marksman_row.get("member_id", 0), 2, "recipient retains stable member id", failures)
	TestAssertions.equal(marksman_row.get("class_name", ""), "Marksman", "recipient includes class name", failures)
	TestAssertions.equal(marksman_row.get("role_name", ""), "Midline", "recipient includes role name", failures)
	TestAssertions.equal(marksman_row.get("health_current", 0.0), 63.0, "recipient uses provided current health", failures)
	TestAssertions.equal(marksman_row.get("health_maximum", 0.0), 80.0, "recipient uses provided maximum health", failures)
	TestAssertions.equal(marksman_row.get("class_rank", 0), 1, "recipient includes current class rank", failures)
	TestAssertions.truthy(not bool(fighter_row.get("eligible", true)), "ineligible member remains disabled", failures)
	TestAssertions.truthy(not String(fighter_row.get("disabled_reason", "")).is_empty(), "ineligible member explains why", failures)
	TestAssertions.truthy(bool(marksman_row.get("eligible", false)), "eligible member is enabled", failures)
	TestAssertions.equal(marksman_row.get("current_rank", -1), 0, "recipient includes current upgrade rank", failures)
	TestAssertions.equal(marksman_row.get("next_rank", -1), 1, "recipient includes offered next rank", failures)
	var preview_lines: Array = marksman_row.get("preview_lines", [])
	TestAssertions.truthy("Physical Damage: 1.00x -> 1.30x" in preview_lines, "recipient preview uses resolved stat formatting", failures)
	party.free()

func _test_matching_recipient_rows_use_party_rank(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var wall := catalog.upgrade_by_id(&"vanguard_wall")
	UpgradeApplicationService.apply(wall.id, catalog, party)
	var rows := UpgradePresentationService.recipient_rows(
		wall,
		party,
		func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0),
	)
	TestAssertions.equal(rows[0].get("current_rank", 0), 1, "matching recipient uses shared party upgrade rank", failures)
	party.free()

func _test_role_names(failures: Array[String]) -> void:
	TestAssertions.equal(UpgradePresentationService.role_name(ClassDefinition.Role.FRONTLINE), "Frontline", "frontline role name", failures)
	TestAssertions.equal(UpgradePresentationService.role_name(ClassDefinition.Role.MIDLINE), "Midline", "midline role name", failures)
	TestAssertions.equal(UpgradePresentationService.role_name(ClassDefinition.Role.BACKLINE), "Backline", "backline role name", failures)
	TestAssertions.equal(UpgradePresentationService.role_name(ClassDefinition.Role.SUPPORT), "Support", "support role name", failures)
