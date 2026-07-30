extends RefCounted

const CLASS_IDS: Array[StringName] = [
    &"fighter", &"ranger", &"mage", &"cleric", &"paladin",
    &"rogue", &"frost_mage", &"warlock", &"marksman",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    var experience := ExperienceSystem.new()
    experience.add_experience(20)
    TestAssertions.equal(experience.pending_levels, 1, "first threshold", failures)
    TestAssertions.equal(experience.experience_for_next_level(), 30, "second threshold", failures)
    experience.add_experience(70)
    TestAssertions.equal(experience.level, 4, "multiple thresholds", failures)
    TestAssertions.equal(experience.pending_levels, 3, "multiple pending levels", failures)
    TestAssertions.truthy(experience.consume_pending_level(), "pending level consumes", failures)
    TestAssertions.equal(experience.pending_levels, 2, "pending count decrements", failures)
    experience.free()

    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    for class_id: StringName in CLASS_IDS:
        var recruit_choice := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, class_id, "Recruit")
        TestAssertions.truthy(recruit_choice.is_valid_for(party), "%s recruit choice is valid with space" % class_id, failures)
    var early: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    var early_repeat: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    TestAssertions.equal(early.size(), 3, "three early choices", failures)
    TestAssertions.equal(_choice_keys(early), _choice_keys(early_repeat), "seed seven is deterministic early", failures)
    TestAssertions.equal(_unique_choice_count(early), 3, "early choices unique", failures)
    TestAssertions.truthy(early.any(func(choice: UpgradeChoice) -> bool: return choice.kind == UpgradeChoice.Kind.RECRUIT), "open party guarantees recruit", failures)
    TestAssertions.truthy(early.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(party)), "all early choices usable", failures)
    TestAssertions.truthy(early.all(func(choice: UpgradeChoice) -> bool: return choice.kind != UpgradeChoice.Kind.CLASS_RANK or choice.target_id == &"fighter"), "unowned class ranks excluded", failures)
    TestAssertions.truthy(early.all(func(choice: UpgradeChoice) -> bool: return choice.kind != UpgradeChoice.Kind.TRAIT), "inactive traits excluded", failures)
    party.recruit(catalog.class_by_id(&"ranger")); party.recruit(catalog.class_by_id(&"mage")); party.recruit(catalog.class_by_id(&"cleric"))
    var full: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    var full_repeat: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    TestAssertions.equal(full.size(), 3, "three full-party choices", failures)
    TestAssertions.equal(_choice_keys(full), _choice_keys(full_repeat), "seed seven is deterministic full", failures)
    TestAssertions.equal(_unique_choice_count(full), 3, "full choices unique", failures)
    TestAssertions.truthy(full.all(func(choice: UpgradeChoice) -> bool: return choice.kind != UpgradeChoice.Kind.RECRUIT), "full party excludes recruits", failures)
    TestAssertions.truthy(full.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(party)), "all full choices usable", failures)
    party.free()

    var empty_catalog := GameCatalog.new()
    var fallback_party := PartyManager.new()
    var empty_traits: Array[TraitDefinition] = []
    fallback_party.initialize(catalog.class_by_id(&"fighter"), empty_traits)
    var fallback: Array[UpgradeChoice] = LevelUpChoiceService.generate(fallback_party, empty_catalog, 7)
    TestAssertions.equal(fallback.size(), 3, "empty catalog still returns three choices", failures)
    TestAssertions.equal(_unique_choice_count(fallback), 3, "empty catalog choices unique", failures)
    TestAssertions.truthy(fallback.any(func(choice: UpgradeChoice) -> bool: return choice.kind == UpgradeChoice.Kind.RECRUIT and choice.target_id == &"fighter"), "empty catalog reuses owned class for recruit", failures)
    TestAssertions.truthy(fallback.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(fallback_party)), "empty catalog choices usable", failures)
    fallback_party.free()

    var empty_party := PartyManager.new()
    var stat_fallbacks: Array[UpgradeChoice] = LevelUpChoiceService.generate(empty_party, empty_catalog, 7)
    TestAssertions.equal(stat_fallbacks.size(), 3, "candidate shortage uses three fallbacks", failures)
    TestAssertions.equal(_unique_choice_count(stat_fallbacks), 3, "fallback choices unique", failures)
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
