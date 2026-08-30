extends RefCounted


func run() -> Array[String]:
	var failures: Array[String] = []
	if not FileAccess.file_exists("res://scripts/ui/level_up/upgrade_offer_projection.gd"):
		failures.append("typed UpgradeOfferProjection script is missing")
		return failures
	if not FileAccess.file_exists("res://scripts/ui/level_up/upgrade_offer_projection_service.gd"):
		failures.append("typed UpgradeOfferProjectionService script is missing")
		return failures
	_test_foundational_projection_is_typed_and_copy_owned(failures)
	_test_authored_rarity_and_targeted_summary_are_truthful(failures)
	_test_recruitment_consequences_are_catalog_backed(failures)
	_test_build_all_preserves_choice_order_and_disabled_reason(failures)
	return failures


func _test_foundational_projection_is_typed_and_copy_owned(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var choice := UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"fighter", "Train Fighter")
	var service: RefCounted = (load("res://scripts/ui/level_up/upgrade_offer_projection_service.gd") as Script).new()
	var projection: RefCounted = service.call("build", choice, party, catalog)
	TestAssertions.equal(projection.choice_key, choice.key(), "projection retains stable choice identity", failures)
	TestAssertions.equal(projection.target_id, &"fighter", "projection retains stable target identity", failures)
	TestAssertions.equal(projection.category_id, &"class_rank", "foundational category is explicit", failures)
	TestAssertions.equal(projection.icon_id, &"", "missing optional icon stays empty", failures)
	TestAssertions.equal(projection.rarity_label, "", "foundational choices omit unsupported rarity", failures)
	TestAssertions.truthy(projection.enabled(), "projection without a reason is enabled", failures)
	var copy: RefCounted = projection.call("copy")
	copy.recipient_tags.append(&"mutated")
	copy.class_tags.append(&"mutated")
	TestAssertions.truthy(not (&"mutated" in projection.recipient_tags), "projection recipient tags are copy-owned", failures)
	TestAssertions.truthy(not (&"mutated" in projection.class_tags), "projection class tags are copy-owned", failures)
	party.free()


func _test_authored_rarity_and_targeted_summary_are_truthful(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	var deadeye := catalog.upgrade_by_id(&"deadeye")
	var service: RefCounted = (load("res://scripts/ui/level_up/upgrade_offer_projection_service.gd") as Script).new()
	var projection: RefCounted = service.call("build", UpgradeChoice.authored(deadeye), party, catalog)
	TestAssertions.equal(projection.rarity_label, "Common", "authored COMMON rarity remains visible", failures)
	TestAssertions.equal(projection.effect_text, deadeye.summary, "targeted offer uses the authored pre-recipient summary", failures)
	TestAssertions.truthy(not ("->" in projection.effect_text), "targeted offer omits an unproven exact pre-recipient delta", failures)
	var preview := UpgradeApplicationService.preview_values(deadeye, party, 2)
	TestAssertions.truthy(not preview.is_empty(), "selected recipient supplies exact preview values", failures)
	if not preview.is_empty():
		TestAssertions.truthy(float(preview[0].after) != float(preview[0].before), "selected recipient preview has exact before and after values", failures)

	var rare_deadeye := deadeye.duplicate(true) as UpgradeDefinition
	rare_deadeye.rarity = UpgradeDefinition.Rarity.RARE
	for index: int in catalog.upgrades.size():
		if catalog.upgrades[index].id == rare_deadeye.id:
			catalog.upgrades[index] = rare_deadeye
			break
	var rare_projection: RefCounted = service.call("build", UpgradeChoice.authored(rare_deadeye), party, catalog)
	TestAssertions.equal(rare_projection.rarity_label, "Rare", "authored rarity follows the current schema value", failures)
	party.free()


func _test_recruitment_consequences_are_catalog_backed(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var ranger := catalog.class_by_id(&"ranger")
	var service: RefCounted = (load("res://scripts/ui/level_up/upgrade_offer_projection_service.gd") as Script).new()
	var projection: RefCounted = service.call("build",
		UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, ranger.id, "Recruit Ranger"),
		party,
		catalog,
	)
	TestAssertions.equal(projection.class_tags, [&"ranger"], "recruit projection names only its catalog class", failures)
	TestAssertions.equal(projection.recipient_tags, ranger.traits, "recruit projection exposes only catalog trait consequences", failures)
	TestAssertions.truthy("Midline" in projection.scope_text, "recruit projection uses the catalog role", failures)
	TestAssertions.equal(projection.rank_text, "", "recruit projection does not invent a rank", failures)
	TestAssertions.equal(projection.effect_text, "Recruit a Midline Ranger. Traits: Martial, Ranged.", "recruit consequences are limited to catalog class, role, and trait names", failures)
	for unsupported_claim: String in ["Damage", "Health", "Equipment", "Synergy"]:
		TestAssertions.truthy(unsupported_claim not in projection.effect_text, "recruit projection omits unsupported %s claims" % unsupported_claim, failures)
	TestAssertions.truthy(projection.recipient_tags.all(func(tag: StringName) -> bool: return catalog.trait_by_id(tag) != null), "every recruit consequence resolves in the current catalog", failures)
	party.free()


func _test_build_all_preserves_choice_order_and_disabled_reason(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
	]
	var service: RefCounted = (load("res://scripts/ui/level_up/upgrade_offer_projection_service.gd") as Script).new()
	var projections: Array = service.call("build_all", choices, party, catalog, "Temporarily unavailable.")
	TestAssertions.equal(projections.size(), 2, "build all keeps every offer", failures)
	TestAssertions.equal(projections[0].choice_key, choices[0].key(), "build all preserves authoritative order", failures)
	TestAssertions.equal(projections[1].choice_key, choices[1].key(), "build all preserves later choice identity", failures)
	TestAssertions.truthy(projections.all(func(item: RefCounted) -> bool: return not bool(item.call("enabled"))), "build all copies the disabled reason", failures)
	TestAssertions.equal(choices[0].call("application_route"), 0, "projection disabled state does not alter direct application route", failures)
	party.free()
