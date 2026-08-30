extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_choice_contract(failures)
	_test_offer_shape_and_determinism(failures)
	_test_recruit_policy_counts_and_drought(failures)
	_test_offer_count_bounds(failures)
	_test_catalog_order_and_rarity_are_inert(failures)
	_test_capped_and_unusable_cards_are_excluded(failures)
	_test_foundational_choices_complete_a_short_offer(failures)
	_test_recipient_independent_key(failures)
	_test_universal_before_legacy_stat_fallback(failures)
	_test_effective_capacity_recruit_choices(failures)
	_test_application_routes_are_authoritative(failures)
	return failures

func _test_application_routes_are_authoritative(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var simple_choice := UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Party Damage")
	var targeted_choice := UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality"))
	var recruit_choice := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"ranger", "Recruit Ranger")
	var shared_choice := UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall"))
	var class_choice := UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, &"fighter", "Train Fighter")
	var trait_choice := UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, &"vanguard", "Strengthen Vanguard")
	TestAssertions.truthy(simple_choice.has_method(&"application_route"), "choice exposes an authoritative application route", failures)
	if not simple_choice.has_method(&"application_route"):
		return
	var constants := (simple_choice.get_script() as Script).get_script_constant_map()
	TestAssertions.equal(constants.get("ApplicationRoute", {}), {"DIRECT": 0, "RECIPIENT_CONFIRMATION": 1, "CONTEXT_CONFIRMATION": 2}, "application route enum is exact", failures)
	TestAssertions.equal(simple_choice.call("application_route"), 0, "whole-party choice is direct", failures)
	TestAssertions.equal(targeted_choice.call("application_route"), 1, "targeted choice confirms recipient", failures)
	TestAssertions.equal(recruit_choice.call("application_route"), 2, "recruit confirms context", failures)
	TestAssertions.equal(shared_choice.call("application_route"), 0, "non-recipient authored choice is direct", failures)
	TestAssertions.equal(class_choice.call("application_route"), 0, "class rank choice is direct", failures)
	TestAssertions.equal(trait_choice.call("application_route"), 0, "trait choice is direct", failures)
	targeted_choice.label = "Recruit-looking visual text"
	TestAssertions.equal(targeted_choice.call("application_route"), 1, "visual text never determines route", failures)

func _test_effective_capacity_recruit_choices(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var recruit := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, &"fighter", "Recruit Fighter")
	var one_slot_party := PartyManager.new()
	if not one_slot_party.has_method(&"configure_capacity") or not one_slot_party.has_method(&"can_recruit"):
		TestAssertions.truthy(false, "capacity-aware recruit choices require PartyManager capacity APIs", failures)
		one_slot_party.free()
		return
	one_slot_party.call("configure_capacity", PartyCapacityPolicy.new(1))
	one_slot_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	TestAssertions.truthy(not recruit.is_valid_for(one_slot_party), "recruit choice is invalid at effective capacity one", failures)
	TestAssertions.equal(_kind_count(LevelUpChoiceService.generate(one_slot_party, catalog, 771), UpgradeChoice.Kind.RECRUIT), 0, "capacity-one offers contain no recruit", failures)
	one_slot_party.free()

	var developer_party := PartyManager.new()
	developer_party.call("configure_capacity", PartyCapacityPolicy.new(24))
	developer_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for index: int in range(3):
		developer_party.recruit(catalog.class_by_id(&"fighter"))
	TestAssertions.equal(developer_party.members.size(), PartyManager.MAX_PARTY_SIZE, "developer choice fixture crosses the production boundary", failures)
	TestAssertions.truthy(recruit.is_valid_for(developer_party), "recruit choice remains valid above production boundary", failures)
	var expected_recruits := RecruitOfferPolicy.count_for_roll(_policy_roll_for_seed(771), 0)
	TestAssertions.equal(_kind_count(LevelUpChoiceService.generate(developer_party, catalog, 771), UpgradeChoice.Kind.RECRUIT), expected_recruits, "developer-capacity offer follows recruit policy above production boundary", failures)
	developer_party.free()

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
	var state := LevelUpOfferState.new()
	state.offer_sequence = 4
	state.consecutive_eligible_without_recruit = 1
	var repeat_state := LevelUpOfferState.new()
	repeat_state.offer_sequence = state.offer_sequence
	repeat_state.consecutive_eligible_without_recruit = state.consecutive_eligible_without_recruit
	var first := LevelUpChoiceService.generate(party, catalog, 771, 5, state)
	var repeat := LevelUpChoiceService.generate(party, catalog, 771, 5, repeat_state)
	TestAssertions.equal(first.size(), 5, "production offer contains five cards", failures)
	TestAssertions.equal(_unique_count(first), first.size(), "offer keys are unique", failures)
	TestAssertions.equal(_keys(repeat), _keys(first), "same seed and equivalent pre-offer state reproduce offer", failures)
	TestAssertions.truthy(first.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(party)), "every open-party choice is usable", failures)

	party.recruit(catalog.class_by_id(&"ranger"))
	party.recruit(catalog.class_by_id(&"mage"))
	party.recruit(catalog.class_by_id(&"cleric"))
	var full := LevelUpChoiceService.generate(party, catalog, 771)
	TestAssertions.equal(full.size(), 5, "full-party offer contains five choices", failures)
	TestAssertions.equal(_kind_count(full, UpgradeChoice.Kind.RECRUIT), 0, "full party receives no recruit", failures)
	TestAssertions.equal(_kind_count(full, UpgradeChoice.Kind.PARTY_STAT), 0, "full party uses upgrade candidates before legacy stat fallbacks", failures)
	TestAssertions.equal(_unique_count(full), 5, "full-party offer has no duplicate keys", failures)
	party.free()

func _test_recruit_policy_counts_and_drought(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var developer_party := PartyManager.new()
	developer_party.configure_capacity(PartyCapacityPolicy.new(24))
	developer_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for expected_count: int in range(4):
		var seed := _seed_for_policy_count(expected_count)
		TestAssertions.truthy(seed >= 0, "deterministic seed exists for recruit band %d" % expected_count, failures)
		if seed < 0:
			continue
		var state := LevelUpOfferState.new()
		var offer := LevelUpChoiceService.generate(developer_party, catalog, seed, 5, state)
		TestAssertions.equal(_kind_count(offer, UpgradeChoice.Kind.RECRUIT), expected_count, "offer recruit count follows policy band %d" % expected_count, failures)
	developer_party.free()

	var three_seed := _seed_for_policy_count(3)
	var one_slot_party := PartyManager.new()
	one_slot_party.configure_capacity(PartyCapacityPolicy.new(2))
	one_slot_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var capacity_offer := LevelUpChoiceService.generate(one_slot_party, catalog, three_seed, 5, LevelUpOfferState.new())
	TestAssertions.equal(_kind_count(capacity_offer, UpgradeChoice.Kind.RECRUIT), 1, "recruit count clamps to remaining party capacity", failures)
	one_slot_party.free()

	var one_candidate_party := PartyManager.new()
	one_candidate_party.configure_capacity(PartyCapacityPolicy.new(24))
	one_candidate_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var one_candidate_offer := LevelUpChoiceService.generate(one_candidate_party, GameCatalog.new(), three_seed, 5, LevelUpOfferState.new())
	TestAssertions.equal(_kind_count(one_candidate_offer, UpgradeChoice.Kind.RECRUIT), 1, "recruit count clamps to unique candidate variety", failures)
	one_candidate_party.free()

	var zero_seed := _seed_for_policy_count(0)
	var drought_party := PartyManager.new()
	drought_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var drought_state := LevelUpOfferState.new()
	drought_state.consecutive_eligible_without_recruit = RecruitOfferPolicy.DROUGHT_LIMIT
	var drought_offer := LevelUpChoiceService.generate(drought_party, catalog, zero_seed, 5, drought_state)
	TestAssertions.truthy(_kind_count(drought_offer, UpgradeChoice.Kind.RECRUIT) >= 1, "recruit drought forces at least one recruit", failures)
	TestAssertions.equal(drought_state.consecutive_eligible_without_recruit, 0, "forced recruit clears drought", failures)
	drought_party.recruit(catalog.class_by_id(&"ranger"))
	drought_party.recruit(catalog.class_by_id(&"mage"))
	drought_party.recruit(catalog.class_by_id(&"cleric"))
	drought_state.consecutive_eligible_without_recruit = 2
	var full_offer := LevelUpChoiceService.generate(drought_party, catalog, zero_seed, 5, drought_state)
	TestAssertions.equal(_kind_count(full_offer, UpgradeChoice.Kind.RECRUIT), 0, "full party remains recruit-ineligible", failures)
	TestAssertions.equal(drought_state.consecutive_eligible_without_recruit, 2, "full party preserves recruit drought", failures)
	drought_party.free()

func _test_offer_count_bounds(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	TestAssertions.equal(LevelUpChoiceService.generate(party, catalog, 44, 0).size(), 1, "offer count clamps to one", failures)
	TestAssertions.equal(LevelUpChoiceService.generate(party, catalog, 44, 99).size(), 8, "offer count clamps to eight", failures)
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
	var offer := LevelUpChoiceService.generate(party, _catalog_with_upgrades(defaults, cards), 44, 3)
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
	var offer := LevelUpChoiceService.generate(party, no_authored_cards, 5150, 3)
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
	var offer := LevelUpChoiceService.generate(party, catalog, 18, 3)
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
	var offer := LevelUpChoiceService.generate(party, catalog, 99, 3)
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

func _policy_roll_for_seed(seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng.randf()

func _seed_for_policy_count(expected_count: int) -> int:
	for seed: int in range(10000):
		if RecruitOfferPolicy.count_for_roll(_policy_roll_for_seed(seed), 0) == expected_count:
			return seed
	return -1
