extends RefCounted


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_all_five_choice_kinds_are_typed(failures)
	_test_authored_rarity_and_targeted_summary_are_truthful(failures)
	_test_recruitment_uses_complete_catalog_backed_sentences(failures)
	_test_missing_or_mismatched_authority_fails_closed(failures)
	_test_build_all_is_deterministic_ordered_and_independent(failures)
	return failures


func _test_all_five_choice_kinds_are_typed(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := _active_vanguard_party(catalog)
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger"),
		UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"fighter", "Train Fighter"),
		UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, &"vanguard", "Strengthen Vanguard"),
		UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
	]
	var expected_categories: Array[StringName] = [&"recruit", &"class_rank", &"trait", &"party_stat", &"character"]
	var service := UpgradeOfferProjectionService.new()
	for index: int in choices.size():
		var projection := service.build(choices[index], party, catalog)
		TestAssertions.equal(projection.choice_key, choices[index].key(), "kind %d keeps stable choice identity" % index, failures)
		TestAssertions.equal(projection.target_id, choices[index].target_id, "kind %d keeps stable target identity" % index, failures)
		TestAssertions.equal(projection.category_id, expected_categories[index], "kind %d has typed category" % index, failures)
		TestAssertions.truthy(projection.enabled(), "kind %d is enabled with current authority" % index, failures)
		TestAssertions.equal(projection.rarity_label, "Common" if choices[index].kind == UpgradeChoice.Kind.AUTHORED else "", "kind %d rarity follows its authority" % index, failures)

	var original := service.build(choices[1], party, catalog)
	var copy := original.copy()
	copy.recipient_tags.append(&"mutated")
	copy.class_tags.append(&"mutated")
	TestAssertions.truthy(not (&"mutated" in original.recipient_tags), "projection recipient tags are copy-owned", failures)
	TestAssertions.truthy(not (&"mutated" in original.class_tags), "projection class tags are copy-owned", failures)
	party.free()


func _test_authored_rarity_and_targeted_summary_are_truthful(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"marksman"))
	var deadeye := catalog.upgrade_by_id(&"deadeye")
	var projection := UpgradeOfferProjectionService.new().build(UpgradeChoice.authored(deadeye), party, catalog)
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
	var rare_projection := UpgradeOfferProjectionService.new().build(UpgradeChoice.authored(rare_deadeye), party, catalog)
	TestAssertions.equal(rare_projection.rarity_label, "Rare", "authored rarity follows the exact current schema object", failures)
	party.free()


func _test_recruitment_uses_complete_catalog_backed_sentences(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var ranger := catalog.class_by_id(&"ranger")
	var projection := UpgradeOfferProjectionService.new().build(
		UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, ranger.id, "Recruit Ranger"),
		party,
		catalog,
	)
	TestAssertions.equal(projection.class_tags, [&"ranger"], "recruit projection names only its catalog class", failures)
	TestAssertions.equal(projection.recipient_tags, ranger.traits, "recruit projection exposes only catalog trait consequences", failures)
	TestAssertions.equal(projection.rank_text, "", "recruit projection does not invent a rank", failures)
	TestAssertions.equal(projection.effect_text, "Recruit Ranger, a Midline class with the Martial and Ranged traits.", "recruit effect is one complete catalog-backed sentence", failures)
	TestAssertions.equal(projection.scope_text, "Adds Ranger as a new party member after confirmation.", "recruit scope is one complete confirmation sentence", failures)
	TestAssertions.truthy("•" not in projection.scope_text and projection.scope_text.ends_with("."), "recruit scope avoids bullet fragments", failures)
	for unsupported_claim: String in ["Damage", "Health", "Equipment", "Synergy"]:
		TestAssertions.truthy(unsupported_claim not in projection.effect_text, "recruit projection omits unsupported %s claims" % unsupported_claim, failures)
	TestAssertions.truthy(projection.recipient_tags.all(func(tag: StringName) -> bool: return catalog.trait_by_id(tag) != null), "every recruit consequence resolves in the current catalog", failures)
	party.free()


func _test_missing_or_mismatched_authority_fails_closed(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var service := UpgradeOfferProjectionService.new()
	var stable := UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"fighter", "Train Fighter")
	for projection: UpgradeOfferProjection in [service.build(stable, null, catalog), service.build(stable, party, null)]:
		TestAssertions.truthy(not projection.enabled(), "missing required authority disables projection", failures)
		TestAssertions.truthy(not projection.disabled_reason.is_empty() and projection.disabled_reason.ends_with("."), "missing authority has a complete readable reason", failures)
		TestAssertions.equal(projection.choice_key, stable.key(), "missing authority preserves safe stable choice identity", failures)

	var missing_choices: Array[UpgradeChoice] = [
		UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"missing_class", "Missing Recruit"),
		UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"missing_class", "Missing Class"),
		UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"ranger", "Unrepresented Class"),
		UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, &"missing_trait", "Missing Trait"),
		UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, &"arcane", "Inactive Trait"),
		UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"missing_stat", "Missing Stat"),
	]
	for choice: UpgradeChoice in missing_choices:
		var projection := service.build(choice, party, catalog)
		TestAssertions.truthy(not projection.enabled(), "%s fails closed" % choice.key(), failures)
		TestAssertions.truthy(not projection.disabled_reason.is_empty(), "%s explains unavailability" % choice.key(), failures)
		TestAssertions.equal(projection.choice_key, choice.key(), "%s preserves stable identity" % choice.key(), failures)

	var current := catalog.upgrade_by_id(&"deadeye")
	var same_id_stale := current.duplicate(true) as UpgradeDefinition
	var stale_projection := service.build(UpgradeChoice.authored(same_id_stale), party, catalog)
	TestAssertions.truthy(not stale_projection.enabled(), "same-id stale authored definition fails closed", failures)
	TestAssertions.equal(stale_projection.disabled_reason, "This offer is no longer available.", "same-id stale authored reason is exact and readable", failures)
	var missing_definition := UpgradeChoice.new(UpgradeChoice.Kind.AUTHORED, current.id, current.display_name)
	var missing_projection := service.build(missing_definition, party, catalog)
	TestAssertions.truthy(not missing_projection.enabled(), "authored choice without exact definition fails closed", failures)
	TestAssertions.equal(missing_projection.disabled_reason, "This offer is no longer available.", "missing authored definition uses offer wording", failures)
	party.free()


func _test_build_all_is_deterministic_ordered_and_independent(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := _active_vanguard_party(catalog)
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger"),
		UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"fighter", "Train Fighter"),
		UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, &"vanguard", "Strengthen Vanguard"),
		UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage"),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
	]
	var service := UpgradeOfferProjectionService.new()
	var first := service.build_all(choices, party, catalog)
	var repeat := service.build_all(choices, party, catalog)
	TestAssertions.equal(_projection_snapshots(repeat), _projection_snapshots(first), "repeated build all is deterministic", failures)
	TestAssertions.equal(_projection_keys(first), _choice_keys(choices), "build all preserves input order and identity", failures)

	var reversed: Array[UpgradeChoice] = choices.duplicate()
	reversed.reverse()
	TestAssertions.equal(_projection_keys(service.build_all(reversed, party, catalog)), _choice_keys(reversed), "reversed input preserves reversed order and identity", failures)
	var permuted: Array[UpgradeChoice] = [choices[2], choices[4], choices[0], choices[3], choices[1]]
	TestAssertions.equal(_projection_keys(service.build_all(permuted, party, catalog)), _choice_keys(permuted), "permuted input preserves exact order and identity", failures)

	first[0].recipient_tags.append(&"mutated")
	first[0].class_tags.append(&"mutated")
	TestAssertions.truthy(&"mutated" not in first[1].recipient_tags and &"mutated" not in first[1].class_tags, "build all projections do not share arrays", failures)
	TestAssertions.equal(_projection_snapshots(service.build_all(choices, party, catalog)), _projection_snapshots(repeat), "mutating one returned projection cannot change later builds", failures)
	var disabled := service.build_all(choices, party, catalog, "Temporarily unavailable.")
	TestAssertions.truthy(disabled.all(func(item: UpgradeOfferProjection) -> bool: return not item.enabled() and item.disabled_reason == "Temporarily unavailable."), "build all independently applies caller disabled reason", failures)
	party.free()


func _active_vanguard_party(catalog: GameCatalog) -> PartyManager:
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"fighter"))
	return party


func _projection_keys(projections: Array[UpgradeOfferProjection]) -> PackedStringArray:
	var result := PackedStringArray()
	for projection: UpgradeOfferProjection in projections:
		result.append(projection.choice_key)
	return result


func _choice_keys(choices: Array[UpgradeChoice]) -> PackedStringArray:
	var result := PackedStringArray()
	for choice: UpgradeChoice in choices:
		result.append(choice.key())
	return result


func _projection_snapshots(projections: Array[UpgradeOfferProjection]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for projection: UpgradeOfferProjection in projections:
		result.append({
			"choice_key": projection.choice_key, "target_id": projection.target_id,
			"category_id": projection.category_id, "icon_id": projection.icon_id,
			"display_name": projection.display_name, "rarity_label": projection.rarity_label,
			"effect_text": projection.effect_text, "scope_text": projection.scope_text,
			"rank_text": projection.rank_text, "eligibility_text": projection.eligibility_text,
			"recipient_tags": projection.recipient_tags.duplicate(), "class_tags": projection.class_tags.duplicate(),
			"disabled_reason": projection.disabled_reason,
		})
	return result
