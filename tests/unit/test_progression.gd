extends RefCounted

const CLASS_IDS: Array[StringName] = [
    &"fighter", &"ranger", &"mage", &"cleric", &"paladin",
    &"rogue", &"frost_mage", &"warlock", &"marksman",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    var fighter := load("res://data/progression/class_growth/fighter.tres") as ClassGrowthDefinition
    var tuning := load("res://data/progression/default_experience.tres") as ExperienceTuning
    var initial := CharacterProgressionState.fresh(1, tuning)
    var first := CharacterProgressionService.preview_award(initial, fighter, tuning, 20, 100, 7, &"player_one", 1)
    TestAssertions.equal(first.next_state.level, 2, "first threshold", failures)
    TestAssertions.equal(first.next_state.experience_required, 30, "second threshold", failures)
    var second := CharacterProgressionService.preview_award(first.next_state, fighter, tuning, 74, 100, 7, &"player_one", 1)
    TestAssertions.equal(second.next_state.level, 4, "multiple thresholds", failures)
    TestAssertions.equal(second.next_state.experience, 0, "overflow is preserved after exact thresholds", failures)
    var earned_levels: Array[int] = []
    earned_levels.append_array(first.gained_levels)
    earned_levels.append_array(second.gained_levels)
    TestAssertions.equal(earned_levels, [2, 3, 4], "one ordered result per earned level", failures)

    var boosted_first := CharacterProgressionService.preview_award(initial, fighter, tuning, 1, 150, 7, &"player_one", 1)
    TestAssertions.equal(boosted_first.next_state.experience, 1, "first 150 percent award grants whole XP", failures)
    TestAssertions.near(boosted_first.next_state.fractional_experience, 0.5, 0.001, "first award carries half XP", failures)
    var boosted_second := CharacterProgressionService.preview_award(boosted_first.next_state, fighter, tuning, 1, 150, 7, &"player_one", 1)
    TestAssertions.equal(boosted_second.next_state.experience, 3, "second award consumes carried fraction", failures)
    TestAssertions.near(boosted_second.next_state.fractional_experience, 0.0, 0.001, "carry resets after whole conversion", failures)

    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    for class_id: StringName in CLASS_IDS:
        var recruit_choice := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, class_id, "Recruit")
        TestAssertions.truthy(recruit_choice.is_valid_for(party), "%s recruit choice is valid with space" % class_id, failures)
    var early: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    var early_repeat: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    TestAssertions.equal(early.size(), 5, "five early choices", failures)
    TestAssertions.equal(_choice_keys(early), _choice_keys(early_repeat), "seed seven is deterministic early", failures)
    TestAssertions.equal(_unique_choice_count(early), early.size(), "early choices unique", failures)
    var expected_early_recruits := mini(_policy_count_for_seed(7), party.capacity() - party.members.size())
    TestAssertions.equal(early.filter(func(choice: UpgradeChoice) -> bool: return choice.kind == UpgradeChoice.Kind.RECRUIT).size(), expected_early_recruits, "open party follows recruit policy", failures)
    TestAssertions.truthy(early.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(party)), "all early choices usable", failures)
    TestAssertions.truthy(early.all(func(choice: UpgradeChoice) -> bool: return choice.kind != UpgradeChoice.Kind.CLASS_RANK or choice.target_id == &"fighter"), "unowned class ranks excluded", failures)
    TestAssertions.truthy(early.all(func(choice: UpgradeChoice) -> bool: return choice.kind != UpgradeChoice.Kind.TRAIT), "inactive traits excluded", failures)
    party.recruit(catalog.class_by_id(&"ranger")); party.recruit(catalog.class_by_id(&"mage")); party.recruit(catalog.class_by_id(&"cleric"))
    var full: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    var full_repeat: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    TestAssertions.equal(full.size(), 5, "five full-party choices", failures)
    TestAssertions.equal(_choice_keys(full), _choice_keys(full_repeat), "seed seven is deterministic full", failures)
    TestAssertions.equal(_unique_choice_count(full), full.size(), "full choices unique", failures)
    TestAssertions.truthy(full.all(func(choice: UpgradeChoice) -> bool: return choice.kind != UpgradeChoice.Kind.RECRUIT), "full party excludes recruits", failures)
    TestAssertions.truthy(full.all(func(choice: UpgradeChoice) -> bool: return choice.kind != UpgradeChoice.Kind.PARTY_STAT), "full party uses upgrade candidates before legacy stat fallbacks", failures)
    TestAssertions.truthy(full.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(party)), "all full choices usable", failures)
    party.free()

    var empty_catalog := GameCatalog.new()
    var fallback_party := PartyManager.new()
    var empty_traits: Array[TraitDefinition] = []
    fallback_party.initialize(catalog.class_by_id(&"fighter"), empty_traits)
    var fallback: Array[UpgradeChoice] = LevelUpChoiceService.generate(fallback_party, empty_catalog, 7)
    TestAssertions.equal(fallback.size(), 5, "empty catalog still returns five choices", failures)
    TestAssertions.equal(_unique_choice_count(fallback), fallback.size(), "empty catalog choices unique", failures)
    TestAssertions.equal(fallback.filter(func(choice: UpgradeChoice) -> bool: return choice.kind == UpgradeChoice.Kind.RECRUIT and choice.target_id == &"fighter").size(), mini(_policy_count_for_seed(7), 1), "empty catalog clamps recruits to its owned-class candidate", failures)
    TestAssertions.truthy(fallback.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(fallback_party)), "empty catalog choices usable", failures)
    fallback_party.free()

    var empty_party := PartyManager.new()
    var stat_fallbacks: Array[UpgradeChoice] = LevelUpChoiceService.generate(empty_party, empty_catalog, 7)
    TestAssertions.equal(stat_fallbacks.size(), 5, "candidate shortage uses five fallbacks", failures)
    TestAssertions.equal(_unique_choice_count(stat_fallbacks), stat_fallbacks.size(), "fallback choices unique", failures)
    TestAssertions.truthy(stat_fallbacks.all(func(choice: UpgradeChoice) -> bool: return choice.kind == UpgradeChoice.Kind.PARTY_STAT), "no-class fallback choices are shared stats", failures)
    TestAssertions.truthy(stat_fallbacks.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(empty_party)), "shared-stat fallbacks usable", failures)
    empty_party.free()
    return failures

func _choice_keys(choices: Array[UpgradeChoice]) -> PackedStringArray:
    var keys: PackedStringArray = []
    for choice: UpgradeChoice in choices:
        keys.append(choice.key())
    return keys

func _unique_choice_count(choices: Array[UpgradeChoice]) -> int:
    var keys: Dictionary = {}
    for choice: UpgradeChoice in choices:
        keys[choice.key()] = true
    return keys.size()

func _policy_count_for_seed(seed: int) -> int:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    return RecruitOfferPolicy.count_for_roll(rng.randf(), 0)
