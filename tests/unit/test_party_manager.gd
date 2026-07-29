extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.equal(party.members.size(), 1, "leader occupies one slot", failures)
    TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "duplicate fighter recruits", failures)
    TestAssertions.equal(party.trait_count(&"martial"), 2, "duplicate counts for martial", failures)
    TestAssertions.equal(party.active_tier(&"vanguard"), 2, "vanguard tier two", failures)
    party.recruit(catalog.class_by_id(&"ranger"))
    party.recruit(catalog.class_by_id(&"mage"))
    TestAssertions.truthy(not party.recruit(catalog.class_by_id(&"cleric")), "fifth member rejected", failures)
    party.rank_up(&"fighter")
    TestAssertions.equal(party.get_class_rank(&"fighter"), 2, "shared fighter rank", failures)
    TestAssertions.equal(party.active_tier(&"ranged"), 2, "ranger and mage overlap", failures)
    party.free()

    var five_stack_trait := TraitDefinition.new()
    five_stack_trait.id = &"martial"
    five_stack_trait.tiers = {5: 0.5}
    var five_stack_traits: Array[TraitDefinition] = [five_stack_trait]
    var extended_party := PartyManager.new()
    var fighter: ClassDefinition = catalog.class_by_id(&"fighter")
    extended_party.initialize(fighter, five_stack_traits)
    for member_id: int in range(2, 6):
        extended_party.members.append(PartyMemberState.new(member_id, fighter, false))
    extended_party.call("_recalculate_traits")
    TestAssertions.equal(extended_party.trait_count(&"martial"), 5, "trait count iterates beyond ordinary cap", failures)
    TestAssertions.equal(extended_party.active_tier(&"martial"), 5, "trait tier supports threshold above four", failures)
    extended_party.free()
    return failures
