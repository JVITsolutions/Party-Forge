extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_choice_contract(failures)
	_test_offer_shape_and_determinism(failures)
	_test_catalog_order_and_rarity_are_inert(failures)
	_test_capped_and_unusable_cards_are_excluded(failures)
	_test_foundational_choices_complete_a_short_offer(failures)
	_test_recipient_independent_key(failures)
	_test_universal_before_legacy_stat_fallback(failures)
	return failures

func _test_authored_choice_contract(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var personal := UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality"))
	var shared := UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall"))
	TestAssertions.equal(personal.kind, UpgradeChoice.Kind.AUTHORED, "authored factory marks the choice kind", failures)
	TestAssertions.equal(personal.target_id, &"vitality", "authored factory keeps the card id", failures)
	TestAssertions.equal(personal.definition, catalog.upgrade_by_id(&"vitality"), "authored factory keeps the definition", failures)
	TestAssertions.truthy(personal.requires_recipient(), "character card requires a recipient", failures)
	TestAssertions.truthy(not shared.requires_recipient(), "party card does not require a recipient", failures)
	TestAssertions.equal(personal.key(), "%d:vitality" % UpgradeChoice.Kind.AUTHORED, "authored key contains no recipient id", failures)

func _test_offer_shape_and_determinism(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var first := LevelUpChoiceService.generate(party, catalog, 771)
	var repeat := LevelUpChoiceService.generate(party, catalog, 771)
	TestAssertions.equal(first.size(), 3, "open-party offer contains exactly three choices", failures)
	TestAssertions.equal(_keys(first), _keys(repeat), "same seed preserves ordered choice keys", failures)
	TestAssertions.equal(_kind_count(first, UpgradeChoice.Kind.RECRUIT), 1, "open party receives exactly one recruit", failures)
	TestAssertions.equal(_kind_count(first, UpgradeChoice.Kind.AUTHORED), 2, "authored upgrades fill every non-recruit slot", failures)
	TestAssertions.equal(_unique_count(first), 3, "offer has no duplicate keys", failures)
	TestAssertions.truthy(first.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(party)), "every open-party choice is usable", failures)

	party.recruit(catalog.class_by_id(&"ranger"))
	party.recruit(catalog.class_by_id(&"mage"))
	party.recruit(catalog.class_by_id(&"cleric"))
	var full := LevelUpChoiceService.generate(party, catalog, 771)
	TestAssertions.equal(full.size(), 3, "full-party offer contains exactly three choices", failures)
	TestAssertions.equal(_kind_count(full, UpgradeChoice.Kind.RECRUIT), 0, "full party receives no recruit", failures)
	TestAssertions.equal(_kind_count(full, UpgradeChoice.Kind.AUTHORED), 3, "full party receives authored upgrades first", failures)
	TestAssertions.equal(_unique_count(full), 3, "full-party offer has no duplicate keys", failures)
	party.free()

func _test_catalog_order_and_rarity_are_inert(failures: Array[String]) -> void:
	var defaults := GameCatalog.load_defaults()
	var forward := _catalog_with_upgrades(defaults, defaults.upgrades)
	var reversed_cards: Array[UpgradeDefinition] = defaults.upgrades.duplicate()
	reversed_cards.reverse()
	var reversed := _catalog_with_upgrades(defaults, reversed_cards)
	var rarity_only_cards: Array[UpgradeDefinition] = []
	for source: UpgradeDefinition in reversed_cards:
		var copy := source.duplicate(true) as UpgradeDefinition
		copy.rarity = UpgradeDefinition.Rarity.RARE if source.rarity != UpgradeDefinition.Rarity.RARE else UpgradeDefinition.Rarity.UNCOMMON
		rarity_only_cards.append(copy)
	var rarity_only := _catalog_with_upgrades(defaults, rarity_only_cards)
	var party := PartyManager.new()
	party.initialize(defaults.class_by_id(&"fighter"), defaults.traits)
	party.recruit(defaults.class_by_id(&"ranger"))
	party.recruit(defaults.class_by_id(&"mage"))
	party.recruit(defaults.class_by_id(&"cleric"))
	var expected := _keys(LevelUpChoiceService.generate(party, forward, 9102))
	TestAssertions.equal(_keys(LevelUpChoiceService.generate(party, reversed, 9102)), expected, "stable card id order removes catalog-order influence", failures)
	TestAssertions.equal(_keys(LevelUpChoiceService.generate(party, rarity_only, 9102)), expected, "inactive rarity metadata does not change ordered keys", failures)
	party.free()

func _test_capped_and_unusable_cards_are_excluded(failures: Array[String]) -> void:
	var defaults := GameCatalog.load_defaults()
	var party := PartyManager.new()
	var no_traits: Array[TraitDefinition] = []
	party.initialize(defaults.class_by_id(&"fighter"), no_traits)
	party.recruit(defaults.class_by_id(&"fighter"))
	party.recruit(defaults.class_by_id(&"fighter"))
	party.recruit(defaults.class_by_id(&"fighter"))
	for member: PartyMemberState in party.members:
		for rank_index: int in range(defaults.upgrade_by_id(&"vitality").max_rank):
			UpgradeApplicationService.apply(&"vitality", defaults, party, member.member_id)
	UpgradeApplicationService.apply(&"vanguard_wall", defaults, party)
	var cards: Array[UpgradeDefinition] = [
		defaults.upgrade_by_id(&"vitality"),
		defaults.upgrade_by_id(&"vanguard_wall"),
		defaults.upgrade_by_id(&"deadeye"),
		defaults.upgrade_by_id(&"ferocity"),
	]
	var offer := LevelUpChoiceService.generate(party, _catalog_with_upgrades(defaults, cards), 44)
	TestAssertions.equal(offer.size(), 3, "unusable-card shortage still returns exactly three", failures)
	TestAssertions.truthy(_has_target(offer, &"ferocity"), "usable authored card remains available", failures)
	TestAssertions.truthy(not _has_target(offer, &"vitality"), "personal card capped for every recipient is excluded", failures)
	TestAssertions.truthy(not _has_target(offer, &"vanguard_wall"), "capped party card is excluded", failures)
	TestAssertions.truthy(not _has_target(offer, &"deadeye"), "card with no eligible recipient is excluded", failures)
	party.free()

func _test_foundational_choices_complete_a_short_offer(failures: Array[String]) -> void:
	var defaults := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(defaults.class_by_id(&"fighter"), defaults.traits)
	party.recruit(defaults.class_by_id(&"fighter"))
	party.recruit(defaults.class_by_id(&"fighter"))
	party.recruit(defaults.class_by_id(&"fighter"))
	for stat_id: StringName in PartyManager.PARTY_STAT_IDS:
		for rank_index: int in range(party.upgrade_tuning.party_stat_max_rank):
			party.upgrade_party_stat(stat_id)
	var no_authored_cards := _catalog_with_upgrades(defaults, [])
	var offer := LevelUpChoiceService.generate(party, no_authored_cards, 5150)
	TestAssertions.equal(offer.size(), 3, "foundational choices complete an authored-and-stat shortage", failures)
	TestAssertions.truthy(offer.all(func(choice: UpgradeChoice) -> bool: return choice.kind in [UpgradeChoice.Kind.CLASS_RANK, UpgradeChoice.Kind.TRAIT]), "shortage offer contains only valid foundational kinds", failures)
	TestAssertions.truthy(_kind_count(offer, UpgradeChoice.Kind.CLASS_RANK) > 0, "owned class rank is directly offered during shortage", failures)
	TestAssertions.truthy(_kind_count(offer, UpgradeChoice.Kind.TRAIT) > 0, "active trait is directly offered during shortage", failures)
	TestAssertions.truthy(offer.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(party)), "every foundational shortage choice is usable", failures)
	TestAssertions.equal(_unique_count(offer), 3, "foundational shortage choices keep unique keys", failures)
	party.free()

func _test_recipient_independent_key(failures: Array[String]) -> void:
	var defaults := GameCatalog.load_defaults()
	var party := PartyManager.new()
	var no_traits: Array[TraitDefinition] = []
	party.initialize(defaults.class_by_id(&"fighter"), no_traits)
	party.recruit(defaults.class_by_id(&"fighter"))
	var catalog := _catalog_with_upgrades(defaults, [defaults.upgrade_by_id(&"vitality")])
	var offer := LevelUpChoiceService.generate(party, catalog, 18)
	TestAssertions.equal(offer.filter(func(choice: UpgradeChoice) -> bool: return choice.target_id == &"vitality").size(), 1, "one card produces one choice for multiple eligible recipients", failures)
	TestAssertions.equal(_unique_count(offer), 3, "recipient-independent authored card does not duplicate its key", failures)
	party.free()

func _test_universal_before_legacy_stat_fallback(failures: Array[String]) -> void:
	var defaults := GameCatalog.load_defaults()
	var party := PartyManager.new()
	var no_traits: Array[TraitDefinition] = []
	party.initialize(defaults.class_by_id(&"fighter"), no_traits)
	party.recruit(defaults.class_by_id(&"fighter"))
	party.recruit(defaults.class_by_id(&"fighter"))
	party.recruit(defaults.class_by_id(&"fighter"))
	for rank_index: int in range(party.upgrade_tuning.party_stat_max_rank):
		party.upgrade_party_stat(&"max_health")
	var catalog := _catalog_with_upgrades(defaults, [defaults.upgrade_by_id(&"vitality")])
	var offer := LevelUpChoiceService.generate(party, catalog, 99)
	TestAssertions.equal(offer.size(), 3, "universal fallback plus legacy stats completes the offer", failures)
	TestAssertions.equal(offer[0].kind, UpgradeChoice.Kind.CLASS_RANK, "foundational normal pool is exhausted before fallbacks", failures)
	TestAssertions.equal(offer[1].kind, UpgradeChoice.Kind.AUTHORED, "universal authored fallback precedes legacy party stats", failures)
	TestAssertions.equal(offer[1].target_id, &"vitality", "universal authored fallback is retained", failures)
	TestAssertions.equal(_kind_count(offer, UpgradeChoice.Kind.PARTY_STAT), 1, "legacy party stats only fill the final remaining slot", failures)
	TestAssertions.truthy(not _has_target(offer, &"max_health"), "capped legacy party stat is excluded", failures)
	party.free()

func _catalog_with_upgrades(source: GameCatalog, cards: Array[UpgradeDefinition]) -> GameCatalog:
	var catalog := GameCatalog.new()
	catalog.classes = source.classes.duplicate()
	catalog.traits = source.traits.duplicate()
	catalog.upgrades = cards.duplicate()
	return catalog

func _keys(choices: Array[UpgradeChoice]) -> PackedStringArray:
	var result := PackedStringArray()
	for choice: UpgradeChoice in choices:
		result.append(choice.key())
	return result

func _kind_count(choices: Array[UpgradeChoice], kind: UpgradeChoice.Kind) -> int:
	return choices.filter(func(choice: UpgradeChoice) -> bool: return choice.kind == kind).size()

func _unique_count(choices: Array[UpgradeChoice]) -> int:
	var keys: Dictionary = {}
	for choice: UpgradeChoice in choices:
		keys[choice.key()] = true
	return keys.size()

func _has_target(choices: Array[UpgradeChoice], target_id: StringName) -> bool:
	return choices.any(func(choice: UpgradeChoice) -> bool: return choice.target_id == target_id)
