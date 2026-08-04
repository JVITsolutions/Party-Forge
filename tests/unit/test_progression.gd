extends RefCounted

const CLASS_IDS: Array[StringName] = [
    &"fighter", &"ranger", &"mage", &"cleric", &"paladin",
    &"rogue", &"frost_mage", &"warlock", &"marksman",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    _test_experience_system_context_facade(failures)
    _test_experience_system_rejects_non_leader_bindings(failures)
    _test_experience_system_multiplier_ownership(failures)
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

func _test_experience_system_context_facade(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    party.recruit(catalog.class_by_id(&"ranger"))
    var context := PlayerRunContext.new()
    var profile := ProfileState.new_profile("profile-facade01", "Facade Player", 1000)
    TestAssertions.equal(
        context.configure(&"player_facade", 0, profile, 1337, party, 100),
        PackedStringArray(),
        "facade fixture context configures",
        failures,
    )
    var facade := ExperienceSystem.new()
    var emitted_levels: Array[int] = []
    facade.level_ready.connect(func(level_value: int) -> void: emitted_levels.append(level_value))
    TestAssertions.equal(facade.level, 1, "unconfigured facade has safe level", failures)
    TestAssertions.equal(facade.experience, 0, "unconfigured facade has safe experience", failures)
    TestAssertions.equal(facade.pending_levels, 0, "unconfigured facade has no pending levels", failures)
    TestAssertions.equal(facade.pending_level_numbers, [], "unconfigured facade has a safe queue", failures)
    TestAssertions.equal(facade.experience_for_next_level(), 20, "unconfigured facade uses default tuning", failures)
    TestAssertions.equal(facade.current_pending_level(), 0, "unconfigured facade has no current pending level", failures)
    TestAssertions.truthy(not facade.consume_pending_level(), "unconfigured facade cannot consume a level", failures)

    facade.configure_context(context, 1)
    facade.add_experience(20)
    var leader_state := context.progression_for(1)
    TestAssertions.equal(facade.level, leader_state.level, "facade mirrors leader level", failures)
    TestAssertions.equal(facade.experience, leader_state.experience, "facade mirrors leader experience", failures)
    TestAssertions.equal(facade.experience_for_next_level(), leader_state.experience_required, "facade mirrors leader requirement", failures)
    TestAssertions.equal(facade.pending_levels, 1, "facade mirrors leader queue count", failures)
    TestAssertions.equal(facade.pending_level_numbers, [2], "facade mirrors leader queue order", failures)
    TestAssertions.equal(facade.current_pending_level(), 2, "facade exposes leader queue front", failures)
    TestAssertions.equal(emitted_levels, [2], "facade proxies the configured leader level only", failures)
    context.award_experience(2, 20)
    TestAssertions.equal(emitted_levels, [2], "follower level does not proxy through facade", failures)
    TestAssertions.truthy(facade.consume_pending_level(), "facade consumes one leader queue entry", failures)
    TestAssertions.equal(facade.pending_level_numbers, [], "facade consumption is FIFO", failures)
    facade.free()
    party.free()

func _test_experience_system_rejects_non_leader_bindings(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    party.recruit(catalog.class_by_id(&"ranger"))
    var context := PlayerRunContext.new()
    var profile := ProfileState.new_profile("profile-invalid01", "Invalid Binding", 1000)
    TestAssertions.equal(
        context.configure(&"player_invalid", 0, profile, 1337, party, 150),
        PackedStringArray(),
        "invalid-binding fixture context configures",
        failures,
    )
    context.award_experience(1, 14)
    TestAssertions.equal(context.pending_leader_levels(), [2], "invalid-binding fixture has a real leader queue", failures)

    var facade := ExperienceSystem.new()
    var emitted_levels: Array[int] = []
    facade.level_ready.connect(func(level_value: int) -> void: emitted_levels.append(level_value))
    var invalid_bindings: Array[Dictionary] = [
        {"context": context, "member_id": 2, "label": "follower"},
        {"context": context, "member_id": 99, "label": "nonexistent positive member"},
        {"context": context, "member_id": 0, "label": "nonpositive member"},
        {"context": null, "member_id": 1, "label": "null context"},
        {"context": PlayerRunContext.new(), "member_id": 1, "label": "unconfigured context"},
    ]
    for binding: Dictionary in invalid_bindings:
        var label := String(binding.label)
        facade.configure_multiplier(250)
        facade.configure_context(binding.context as PlayerRunContext, int(binding.member_id))
        TestAssertions.equal(facade.run_context, null, "%s leaves no facade context" % label, failures)
        TestAssertions.equal(facade.leader_member_id, 0, "%s leaves no facade leader" % label, failures)
        TestAssertions.equal(facade.level, 1, "%s keeps safe level" % label, failures)
        TestAssertions.equal(facade.experience, 0, "%s keeps safe experience" % label, failures)
        TestAssertions.equal(facade.pending_levels, 0, "%s keeps safe pending count" % label, failures)
        TestAssertions.equal(facade.pending_level_numbers, [], "%s keeps safe pending queue" % label, failures)
        TestAssertions.equal(facade.experience_for_next_level(), 20, "%s keeps safe requirement" % label, failures)
        TestAssertions.equal(facade.current_pending_level(), 0, "%s keeps safe queue front" % label, failures)
        TestAssertions.near(facade.fractional_experience, 0.0, 0.001, "%s keeps safe fractional XP" % label, failures)
        TestAssertions.near(facade.experience_multiplier, 1.0, 0.001, "%s keeps safe multiplier" % label, failures)
        var leader_before := context.progression_for(1).to_snapshot()
        var follower_before := context.progression_for(2).to_snapshot()
        facade.add_experience(20)
        TestAssertions.equal(context.progression_for(1).to_snapshot(), leader_before, "%s cannot award leader XP" % label, failures)
        TestAssertions.equal(context.progression_for(2).to_snapshot(), follower_before, "%s cannot award follower XP" % label, failures)
        TestAssertions.truthy(not facade.consume_pending_level(), "%s cannot consume a level" % label, failures)
        TestAssertions.equal(context.pending_leader_levels(), [2], "%s cannot consume the real leader queue" % label, failures)
        context.member_level_ready.emit(1, 77)
        context.member_level_ready.emit(2, 77)
        TestAssertions.equal(emitted_levels, [], "%s binds no level-ready effects" % label, failures)
    facade.free()
    party.free()

func _test_experience_system_multiplier_ownership(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var context := PlayerRunContext.new()
    var profile := ProfileState.new_profile("profile-scale001", "Scale Owner", 1000)
    TestAssertions.equal(
        context.configure(&"player_scale", 0, profile, 7331, party, 150),
        PackedStringArray(),
        "multiplier fixture context configures",
        failures,
    )
    var facade := ExperienceSystem.new()
    facade.configure_multiplier(700)
    TestAssertions.equal(facade.configured_multiplier_percent, 700, "pre-bind multiplier remains a temporary compatibility value", failures)
    TestAssertions.near(facade.experience_multiplier, 7.0, 0.001, "pre-bind float multiplier mirrors compatibility value", failures)

    facade.configure_context(context, 1)
    TestAssertions.equal(facade.configured_multiplier_percent, 150, "bound facade proxies context multiplier percent", failures)
    TestAssertions.near(facade.experience_multiplier, 1.5, 0.001, "bound facade proxies context float multiplier", failures)
    facade.configure_multiplier(900)
    TestAssertions.equal(facade.configured_multiplier_percent, 150, "bound compatibility configuration cannot drift from context", failures)
    facade.add_experience(1)
    facade.add_experience(1)
    TestAssertions.equal(context.progression_for(1).experience, 3, "facade delegates two awards for exactly one 150 percent scaling pass", failures)
    TestAssertions.near(context.progression_for(1).fractional_experience, 0.0, 0.001, "authoritative context owns fractional scaling carry", failures)

    facade.configure_context(null, 0)
    TestAssertions.equal(facade.configured_multiplier_percent, 100, "unconfigure clears the temporary multiplier", failures)
    TestAssertions.near(facade.experience_multiplier, 1.0, 0.001, "unconfigured facade returns safe multiplier", failures)
    facade.configure_multiplier(250)
    TestAssertions.equal(facade.configured_multiplier_percent, 250, "temporary multiplier can be configured again after unconfigure", failures)
    facade.configure_context(PlayerRunContext.new(), 1)
    TestAssertions.equal(facade.configured_multiplier_percent, 100, "rejected reconfiguration clears temporary multiplier", failures)
    TestAssertions.equal(facade.run_context, null, "rejected reconfiguration leaves facade unbound", failures)
    facade.free()
    party.free()

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
