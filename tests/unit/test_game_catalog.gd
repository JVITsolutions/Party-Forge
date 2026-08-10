extends RefCounted

class TypedAttackErrorClass:
    extends ClassDefinition

    func validate(_types: DamageTypeCatalog = null) -> PackedStringArray:
        return PackedStringArray([
            "class %s primary PARTY_FORGE_DAMAGE_ERROR attack=%s type=void reason=unknown component type" % [id, primary_attack.id],
        ])

const EXPECTED_CAPABILITIES := {
    &"fighter": [&"area", &"melee", &"physical", &"armour_heavy", &"one_hand_sword", &"shield"],
    &"ranger": [&"physical", &"projectile", &"ranged", &"armour_light", &"armour_medium", &"bow_light_medium"],
    &"mage": [&"area", &"fire", &"projectile", &"armour_light", &"caster_wand", &"caster_focus"],
    &"cleric": [&"healing", &"lightning", &"projectile", &"armour_light", &"armour_medium", &"divine_sceptre", &"divine_tome"],
    &"paladin": [&"area", &"block", &"melee", &"physical", &"regeneration", &"armour_heavy", &"one_hand_hammer", &"shield"],
    &"rogue": [&"area", &"crit", &"dodge", &"life_steal", &"melee", &"physical", &"armour_light", &"dagger", &"dual_wield"],
    &"frost_mage": [&"area", &"cold", &"projectile", &"armour_light", &"caster_staff"],
    &"warlock": [&"chaos", &"life_steal", &"projectile", &"armour_light", &"occult_wand", &"occult_grimoire"],
    &"marksman": [&"bow", &"crit", &"physical", &"projectile", &"ranged", &"armour_light", &"armour_medium", &"bow_light_medium", &"greatbow"],
}

func run() -> Array[String]:
    var failures: Array[String] = []
    var catalog: GameCatalog = GameCatalog.load_defaults()
    TestAssertions.equal(catalog.classes.size(), 9, "nine classes", failures)
    TestAssertions.equal(catalog.traits.size(), 13, "thirteen traits", failures)
    TestAssertions.equal(catalog.enemies.size(), 4, "three enemies plus boss", failures)
    TestAssertions.equal(catalog.validate().size(), 0, "catalog validates", failures)
    TestAssertions.equal(catalog.class_by_id(&"fighter").traits, [&"martial", &"vanguard"], "fighter traits", failures)
    TestAssertions.equal(catalog.class_by_id(&"cleric").support_action.id, &"cleric_heal", "cleric heal", failures)
    _assert_owned_action_contract(catalog, failures)
    _assert_duplicate_action_id_validation(catalog, failures)
    _assert_class_names_and_eligibility(catalog, failures)
    _assert_primary_action_estimates(catalog, failures)
    _assert_item_foundation_reachability(catalog, failures)
    _assert_equipment_attribute_policy(catalog, failures)
    var fighter := catalog.class_by_id(&"fighter")
    fighter.growth_definition = null
    TestAssertions.truthy(
        catalog.validate().has("PARTY_FORGE_RESOURCE_ERROR id=fighter reason=class fighter growth definition is missing"),
        "missing fighter growth definition fails catalog validation",
        failures,
    )
    fighter.growth_definition = load("res://data/progression/class_growth/fighter.tres") as ClassGrowthDefinition
    var attack_links: Array[Array] = [
        [&"fighter", &"primary_attack", "res://data/attacks/fighter_cleave.tres"],
        [&"ranger", &"primary_attack", "res://data/attacks/ranger_shot.tres"],
        [&"mage", &"primary_attack", "res://data/attacks/mage_burst.tres"],
        [&"cleric", &"primary_attack", "res://data/attacks/cleric_bolt.tres"],
        [&"cleric", &"support_action", "res://data/attacks/cleric_heal.tres"],
        [&"paladin", &"primary_attack", "res://data/attacks/paladin_smite.tres"],
        [&"rogue", &"primary_attack", "res://data/attacks/rogue_flurry.tres"],
        [&"frost_mage", &"primary_attack", "res://data/attacks/frost_shard.tres"],
        [&"warlock", &"primary_attack", "res://data/attacks/warlock_bolt.tres"],
        [&"marksman", &"primary_attack", "res://data/attacks/marksman_heavy_shot.tres"],
    ]
    for link: Array in attack_links:
        var definition: ClassDefinition = catalog.class_by_id(link[0])
        var attack: AttackDefinition = definition.get(link[1]) as AttackDefinition
        TestAssertions.equal(attack.resource_path, link[2], "%s %s uses external attack" % [link[0], link[1]], failures)
    _assert_generated_values(failures)
    _assert_persisted_attack_damage_path(failures)
    return failures


func _assert_equipment_attribute_policy(catalog: GameCatalog, failures: Array[String]) -> void:
    var live_equipment := catalog.equipment_catalog
    var live_foundation := catalog.item_foundation_catalog
    var stats := GameCatalog.STAT_CATALOG
    var constants: Dictionary = EquipmentBaseDefinition.new().get_script().get_script_constant_map()
    TestAssertions.equal(
        constants.get("REQUIREMENT_ATTRIBUTE_IDS", []),
        [&"strength", &"dexterity", &"constitution", &"intelligence", &"wisdom", &"charisma"],
        "equipment requirements expose one canonical six-attribute schema",
        failures,
    )
    TestAssertions.equal(live_equipment.size(), 99, "attribute-policy audit covers all live equipment bases", failures)
    TestAssertions.equal(live_foundation.affixes.size(), 195, "attribute-policy audit covers all live affix definitions", failures)
    TestAssertions.equal(live_equipment.validate(), PackedStringArray(), "full live equipment requirement audit passes", failures)
    TestAssertions.equal(live_foundation.validate(stats, live_equipment), PackedStringArray(), "full live affix modifier audit passes", failures)
    var issued_count := 0
    for index: int in live_equipment.definitions.size():
        var base := live_equipment.definitions[index]
        if base == null:
            continue
        var issued := ItemInstanceIssuer.issue(
            "task10e:live-catalog-audit",
            index,
            "task10e_live_catalog_audit",
            10000 + index,
            {"affixes": [], "base_definition_id": String(base.id), "base_damage_components": [], "item_level": 1, "rarity_id": "common"},
            live_equipment,
            live_foundation,
        )
        TestAssertions.truthy(issued.ok(), "live base %s still issues an immutable item" % base.id, failures)
        if issued.ok():
            issued_count += 1
            TestAssertions.equal(
                ItemInstanceCodec.validate(issued.item, live_equipment, live_foundation),
                "",
                "live base %s issued item validates" % base.id,
                failures,
            )
    TestAssertions.equal(issued_count, 99, "all live equipment bases issue valid immutable items", failures)

    var malformed_cases: Array[Dictionary] = [
        {"requirements": {&"luck": 1.0}, "reason": "requirement attribute=luck value=1.0 reason=unknown core attribute"},
        {"requirements": {&"strength": "five"}, "reason": "requirement attribute=strength value=five reason=value must be numeric"},
        {"requirements": {&"strength": NAN}, "reason": "requirement attribute=strength value=nan reason=value must be finite"},
        {"requirements": {&"strength": INF}, "reason": "requirement attribute=strength value=inf reason=value must be finite"},
        {"requirements": {&"strength": -1.0}, "reason": "requirement attribute=strength value=-1.0 reason=value must be nonnegative"},
    ]
    for malformed: Dictionary in malformed_cases:
        var malformed_equipment := live_equipment.duplicate(true) as EquipmentCatalog
        var base_index := _equipment_index(malformed_equipment, &"greenwood_boots")
        malformed_equipment.definitions[base_index] = malformed_equipment.definitions[base_index].duplicate(true) as EquipmentBaseDefinition
        malformed_equipment.definitions[base_index].attribute_requirements = (malformed["requirements"] as Dictionary).duplicate(true)
        TestAssertions.truthy(
            malformed_equipment.validate().has(
                "PARTY_FORGE_EQUIPMENT_ERROR item=greenwood_boots reason=%s" % String(malformed["reason"])
            ),
            "malformed requirement is rejected with stable item and value context: %s" % String(malformed["reason"]),
            failures,
        )

    var all_zero := live_equipment.duplicate(true) as EquipmentCatalog
    var zero_index := _equipment_index(all_zero, &"greenwood_boots")
    all_zero.definitions[zero_index] = all_zero.definitions[zero_index].duplicate(true) as EquipmentBaseDefinition
    all_zero.definitions[zero_index].attribute_requirements = {
        &"strength": 0.0, &"dexterity": 0, &"constitution": 0.0,
        &"intelligence": 0, &"wisdom": 0.0, &"charisma": 0,
    }
    TestAssertions.equal(all_zero.validate(), PackedStringArray(), "zero requirements are valid and deterministic", failures)

    _assert_affix_policy_rejection(
        live_foundation, live_equipment, stats,
        StatModifier.Operation.FLAT, -1.0,
        "flat", "value must be nonnegative", failures,
    )
    _assert_affix_policy_rejection(
        live_foundation, live_equipment, stats,
        StatModifier.Operation.REDUCED, 0.25,
        "reduced", "operation can reduce a core requirement attribute", failures,
    )
    _assert_affix_policy_rejection(
        live_foundation, live_equipment, stats,
        StatModifier.Operation.LESS, 0.25,
        "less", "operation can reduce a core requirement attribute", failures,
    )
    for operation: int in [
        StatModifier.Operation.FLAT,
        StatModifier.Operation.INCREASED,
        StatModifier.Operation.REDUCED,
        StatModifier.Operation.MORE,
        StatModifier.Operation.LESS,
    ]:
        var neutral := _foundation_with_stout_policy(live_foundation, operation, 0.0)
        TestAssertions.equal(
            neutral.affix(&"stout").validate(
                stats,
                neutral.modifier_family_ids,
                ItemGenerationVocabulary.DOMAINS,
                neutral.known_source_ids,
                _rarity_ids(neutral),
                neutral.known_item_tags,
            ),
            PackedStringArray(),
            "zero core modifier is neutral for operation %d" % operation,
            failures,
        )


func _assert_affix_policy_rejection(
    live_foundation: ItemFoundationCatalog,
    live_equipment: EquipmentCatalog,
    stats: StatCatalog,
    operation: int,
    value: float,
    operation_name: String,
    policy_reason: String,
    failures: Array[String],
) -> void:
    var malformed := _foundation_with_stout_policy(live_foundation, operation, value)
    TestAssertions.truthy(
        malformed.validate(stats, live_equipment).has(
            "PARTY_FORGE_ITEM_AFFIX_ERROR id=stout reason=affix stout effect=0 stat=constitution operation=%s value=%s reason=%s" % [
                operation_name, str(value), policy_reason,
            ]
        ),
        "%s core modifier is rejected with affix/stat/operation/value context" % operation_name,
        failures,
    )


func _foundation_with_stout_policy(source: ItemFoundationCatalog, operation: int, value: float) -> ItemFoundationCatalog:
    var result := source.duplicate(true) as ItemFoundationCatalog
    var index := _affix_index(result, &"stout")
    var stout := result.affixes[index].duplicate(true) as ItemAffixDefinition
    stout.effects[0] = stout.effects[0].duplicate(true) as ItemModifierEffectDefinition
    stout.effects[0].operation = operation
    for tier_index: int in stout.tiers.size():
        stout.tiers[tier_index] = stout.tiers[tier_index].duplicate(true) as ItemAffixTierDefinition
        stout.tiers[tier_index].minimum_rolls = [value]
        stout.tiers[tier_index].maximum_rolls = [value]
    result.affixes[index] = stout
    return result


func _rarity_ids(foundation: ItemFoundationCatalog) -> Array[StringName]:
    var result: Array[StringName] = []
    for rarity: ItemRarityDefinition in foundation.rarities:
        if rarity != null:
            result.append(rarity.id)
    return result


func _assert_owned_action_contract(catalog: GameCatalog, failures: Array[String]) -> void:
    var definition := ClassDefinition.new()
    var primary := catalog.class_by_id(&"fighter").primary_attack
    var support := catalog.class_by_id(&"cleric").support_action
    definition.primary_attack = primary
    definition.support_action = support
    var has_interface := definition.has_method(&"owned_actions")
    TestAssertions.truthy(has_interface, "class definition exposes authoritative owned actions", failures)
    if not has_interface:
        return
    var first: Array = definition.call(&"owned_actions")
    TestAssertions.equal(first, [primary, support], "owned actions preserve deterministic primary then support order", failures)
    first.clear()
    TestAssertions.equal(definition.call(&"owned_actions"), [primary, support], "owned actions return a defensive array", failures)
    definition.support_action = primary
    TestAssertions.equal(definition.call(&"owned_actions"), [primary], "owned actions deduplicate identical resources", failures)
    definition.primary_attack = null
    definition.support_action = support
    TestAssertions.equal(definition.call(&"owned_actions"), [support], "owned actions filter null entries while preserving support actions", failures)


func _assert_duplicate_action_id_validation(catalog: GameCatalog, failures: Array[String]) -> void:
    var definition := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
    definition.support_action = definition.primary_attack.duplicate(true) as AttackDefinition
    TestAssertions.truthy(
        definition.validate(catalog.damage_types).has(
            "class fighter action id fighter_cleave is duplicated across owned action resources"
        ),
        "distinct owned action resources reject the same non-empty action ID",
        failures,
    )


func _assert_primary_action_estimates(catalog: GameCatalog, failures: Array[String]) -> void:
    var estimated_class_ids: Array[StringName] = []
    for definition: ClassDefinition in catalog.classes:
        var party := PartyManager.new()
        party.initialize(definition, catalog.traits)
        var first := ActionCombatEstimateService.estimate(
            definition.primary_attack,
            1,
            party,
            GameCatalog.DAMAGE_TYPES,
        )
        var repeated := ActionCombatEstimateService.estimate(
            definition.primary_attack,
            1,
            party,
            GameCatalog.DAMAGE_TYPES,
        )
        TestAssertions.truthy(first.available, "%s primary action estimate is available" % definition.id, failures)
        TestAssertions.truthy(first.normal_hit > 0.0, "%s primary action estimate has positive normal damage" % definition.id, failures)
        TestAssertions.truthy(first.estimated_dps > 0.0, "%s primary action estimate has positive DPS" % definition.id, failures)
        TestAssertions.equal(_estimate_values(repeated), _estimate_values(first), "%s primary action estimate is deterministic" % definition.id, failures)
        if first.available:
            estimated_class_ids.append(definition.id)
        party.free()
    estimated_class_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
    TestAssertions.equal(estimated_class_ids.size(), 9, "all nine playable classes expose primary action estimates", failures)


func _estimate_values(estimate: ActionCombatEstimate) -> Dictionary:
    return {
        "action_id": String(estimate.action_id),
        "available": estimate.available,
        "normal_hit": estimate.normal_hit,
        "critical_hit": estimate.critical_hit,
        "average_hit": estimate.average_hit,
        "attacks_per_second": estimate.attacks_per_second,
        "estimated_dps": estimate.estimated_dps,
        "component_rows": estimate.component_rows.duplicate(true),
    }


func _assert_item_foundation_reachability(catalog: GameCatalog, failures: Array[String]) -> void:
    var stats := load("res://data/stats/core_stats.tres") as StatCatalog
    var live_foundation := load("res://data/items/core_item_foundation_catalog.tres") as ItemFoundationCatalog
    var live_equipment := load("res://data/equipment/core_equipment_catalog.tres") as EquipmentCatalog
    TestAssertions.equal(live_foundation.validate(stats, live_equipment), PackedStringArray(), "live item foundation is reachable", failures)
    _assert_whole_pattern_reachability_regressions(live_foundation, live_equipment, stats, failures)
    _assert_canonical_generation_tag_registry(live_foundation, live_equipment, stats, failures)

    var unknown_implicit_equipment := live_equipment.duplicate(true) as EquipmentCatalog
    var sword_index := _equipment_index(unknown_implicit_equipment, &"forge_vanguard_sword")
    unknown_implicit_equipment.definitions[sword_index] = unknown_implicit_equipment.definitions[sword_index].duplicate(true) as EquipmentBaseDefinition
    unknown_implicit_equipment.definitions[sword_index].implicit_affix_ids = [&"missing_implicit"]
    var unknown_implicit_errors := live_foundation.validate(stats, unknown_implicit_equipment)
    TestAssertions.truthy(
        unknown_implicit_errors.has("PARTY_FORGE_ITEM_AFFIX_ERROR id=missing_implicit base=forge_vanguard_sword reason=unknown implicit affix reference"),
        "unknown equipment implicit is rejected exactly",
        failures,
    )

    var wrong_kind_foundation := live_foundation.duplicate(true) as ItemFoundationCatalog
    var wrong_kind_equipment := live_equipment.duplicate(true) as EquipmentCatalog
    sword_index = _equipment_index(wrong_kind_equipment, &"forge_vanguard_sword")
    wrong_kind_equipment.definitions[sword_index] = wrong_kind_equipment.definitions[sword_index].duplicate(true) as EquipmentBaseDefinition
    wrong_kind_equipment.definitions[sword_index].implicit_affix_ids = [&"stout"]
    TestAssertions.truthy(
        wrong_kind_foundation.validate(stats, wrong_kind_equipment).has("PARTY_FORGE_ITEM_AFFIX_ERROR id=stout base=forge_vanguard_sword reason=base implicit references affix kind prefix"),
        "base implicit must reference an implicit definition",
        failures,
    )

    var impossible_tag_foundation := live_foundation.duplicate(true) as ItemFoundationCatalog
    var stout_index := _affix_index(impossible_tag_foundation, &"stout")
    impossible_tag_foundation.affixes[stout_index] = impossible_tag_foundation.affixes[stout_index].duplicate(true) as ItemAffixDefinition
    impossible_tag_foundation.affixes[stout_index].required_item_tags = [&"impossible_live_tag"]
    TestAssertions.truthy(
        impossible_tag_foundation.validate(stats, live_equipment).has("PARTY_FORGE_ITEM_AFFIX_ERROR id=stout reason=affix stout references unknown required item tag impossible_live_tag"),
        "affix required tag must exist on live equipment",
        failures,
    )

    var live_normalized_tag_foundation := live_foundation.duplicate(true) as ItemFoundationCatalog
    stout_index = _affix_index(live_normalized_tag_foundation, &"stout")
    live_normalized_tag_foundation.affixes[stout_index] = live_normalized_tag_foundation.affixes[stout_index].duplicate(true) as ItemAffixDefinition
    live_normalized_tag_foundation.affixes[stout_index].required_item_tags = [&"martial"]
    TestAssertions.truthy(
        not live_normalized_tag_foundation.validate(stats, live_equipment).has("PARTY_FORGE_ITEM_AFFIX_ERROR id=stout reason=affix stout references unknown required item tag martial"),
        "affix accepts a tag from the live normalized equipment union",
        failures,
    )

    var empty_pattern_foundation := live_foundation.duplicate(true) as ItemFoundationCatalog
    var common_index := _rarity_index(empty_pattern_foundation, &"common")
    empty_pattern_foundation.rarities[common_index] = empty_pattern_foundation.rarities[common_index].duplicate(true) as ItemRarityDefinition
    empty_pattern_foundation.rarities[common_index].patterns = []
    TestAssertions.truthy(
        empty_pattern_foundation.validate(stats, live_equipment).has("PARTY_FORGE_ITEM_RARITY_ERROR id=common reason=ordinary generation has no reachable pattern"),
        "ordinary rarity without patterns is rejected exactly",
        failures,
    )

    var unavailable_kind_foundation := live_foundation.duplicate(true) as ItemFoundationCatalog
    common_index = _rarity_index(unavailable_kind_foundation, &"common")
    unavailable_kind_foundation.rarities[common_index] = unavailable_kind_foundation.rarities[common_index].duplicate(true) as ItemRarityDefinition
    var unavailable_pattern := unavailable_kind_foundation.rarities[common_index].patterns[0].duplicate(true) as ItemAffixPatternDefinition
    unavailable_pattern.special_count = 1
    unavailable_kind_foundation.rarities[common_index].patterns[0] = unavailable_pattern
    TestAssertions.truthy(
        unavailable_kind_foundation.validate(stats, live_equipment).has("PARTY_FORGE_ITEM_RARITY_ERROR id=common pattern=common_zero reason=no complete live generation scenario"),
        "pattern kind without live candidates is rejected exactly",
        failures,
    )

    var unreachable_tier_foundation := live_foundation.duplicate(true) as ItemFoundationCatalog
    stout_index = _affix_index(unreachable_tier_foundation, &"stout")
    unreachable_tier_foundation.affixes[stout_index] = unreachable_tier_foundation.affixes[stout_index].duplicate(true) as ItemAffixDefinition
    for tier_index: int in unreachable_tier_foundation.affixes[stout_index].tiers.size():
        unreachable_tier_foundation.affixes[stout_index].tiers[tier_index] = unreachable_tier_foundation.affixes[stout_index].tiers[tier_index].duplicate(true) as ItemAffixTierDefinition
        unreachable_tier_foundation.affixes[stout_index].tiers[tier_index].minimum_item_level = 1001
    TestAssertions.truthy(
        unreachable_tier_foundation.validate(stats, live_equipment).has("PARTY_FORGE_ITEM_AFFIX_ERROR id=stout reason=no tier is reachable at item level 1..1000"),
        "affix with no reachable tier is rejected exactly",
        failures,
    )

    var duplicate_path_foundation := live_foundation.duplicate(true) as ItemFoundationCatalog
    duplicate_path_foundation.affixes.append(duplicate_path_foundation.affixes[0])
    var duplicate_path := duplicate_path_foundation.affixes[0].resource_path
    TestAssertions.truthy(
        duplicate_path_foundation.validate(stats, live_equipment).has("PARTY_FORGE_ITEM_MANIFEST_ERROR reason=duplicate resource path %s" % duplicate_path),
        "duplicate manifest resource path is rejected exactly",
        failures,
    )

    var upper_ordinary_foundation := live_foundation.duplicate(true) as ItemFoundationCatalog
    var mythic_index := _rarity_index(upper_ordinary_foundation, &"mythic")
    upper_ordinary_foundation.rarities[mythic_index] = upper_ordinary_foundation.rarities[mythic_index].duplicate(true) as ItemRarityDefinition
    upper_ordinary_foundation.rarities[mythic_index].ordinary_generation_enabled = true
    TestAssertions.truthy(
        upper_ordinary_foundation.validate(stats, live_equipment).has("PARTY_FORGE_ITEM_RARITY_ERROR id=mythic reason=ordinary generation is limited to rarity ranks 1..5"),
        "upper rarity cannot enter ordinary generation",
        failures,
    )

    var propagated_foundation := live_foundation.duplicate(true) as ItemFoundationCatalog
    mythic_index = _rarity_index(propagated_foundation, &"mythic")
    propagated_foundation.rarities[mythic_index] = propagated_foundation.rarities[mythic_index].duplicate(true) as ItemRarityDefinition
    propagated_foundation.rarities[mythic_index].ordinary_generation_enabled = true
    catalog.item_foundation_catalog = propagated_foundation
    catalog.equipment_catalog = live_equipment
    TestAssertions.truthy(
        catalog.validate().has("PARTY_FORGE_ITEM_RARITY_ERROR id=mythic reason=ordinary generation is limited to rarity ranks 1..5"),
        "game catalog propagates cross-catalog foundation errors",
        failures,
    )
    catalog.item_foundation_catalog = live_foundation
    catalog.equipment_catalog = live_equipment

func _assert_whole_pattern_reachability_regressions(
    live_foundation: ItemFoundationCatalog,
    live_equipment: EquipmentCatalog,
    stats: StatCatalog,
    failures: Array[String]
) -> void:
    var cross_kind := live_foundation.duplicate(true) as ItemFoundationCatalog
    var cross_prefix := cross_kind.affix(&"stout").duplicate(true) as ItemAffixDefinition
    var cross_suffix := cross_kind.affix(&"of_embers").duplicate(true) as ItemAffixDefinition
    cross_prefix.modifier_family_ids = [&"cross_kind_family"]
    cross_suffix.modifier_family_ids = [&"cross_kind_family"]
    cross_kind.modifier_family_ids.append(&"cross_kind_family")
    cross_kind.affixes = [cross_prefix, cross_suffix]
    TestAssertions.truthy(
        cross_kind.validate(stats, live_equipment).has("PARTY_FORGE_ITEM_RARITY_ERROR id=rare pattern=rare_balanced reason=no complete live generation scenario"),
        "whole-pattern solver rejects cross-kind family conflict",
        failures,
    )

    var implicit_conflict := live_foundation.duplicate(true) as ItemFoundationCatalog
    var implicit := implicit_conflict.affix(&"tempered_edge").duplicate(true) as ItemAffixDefinition
    var explicit := implicit_conflict.affix(&"stout").duplicate(true) as ItemAffixDefinition
    implicit.modifier_family_ids = [&"implicit_explicit_conflict"]
    explicit.modifier_family_ids = [&"implicit_explicit_conflict"]
    implicit_conflict.modifier_family_ids.append(&"implicit_explicit_conflict")
    implicit_conflict.affixes = [implicit, explicit]
    var sword_only := EquipmentCatalog.new()
    sword_only.definitions = [live_equipment.definition(&"forge_vanguard_sword")]
    TestAssertions.truthy(
        implicit_conflict.validate(stats, sword_only).has("PARTY_FORGE_ITEM_RARITY_ERROR id=uncommon pattern=uncommon_prefix reason=no complete live generation scenario"),
        "base implicits block conflicting explicit families",
        failures,
    )

    var split_bases := _scenario_foundation(live_foundation, &"prefix_only", &"suffix_only", &"ordinary_drop", &"ordinary_enemy", &"ordinary_drop", &"ordinary_enemy")
    var split_equipment := EquipmentCatalog.new()
    split_equipment.definitions = [_scenario_base(&"prefix_base", &"prefix_only"), _scenario_base(&"suffix_base", &"suffix_only")]
    split_bases.known_item_tags = _live_tags(split_equipment)
    TestAssertions.truthy(
        split_bases.validate(stats, split_equipment).has("PARTY_FORGE_ITEM_RARITY_ERROR id=rare pattern=rare_balanced reason=no complete live generation scenario"),
        "whole pattern must be feasible on one base",
        failures,
    )

    var mismatched_route := _scenario_foundation(live_foundation, &"route", &"route", &"boss_drop", &"boss", &"ordinary_drop", &"ordinary_enemy")
    var route_equipment := EquipmentCatalog.new()
    route_equipment.definitions = [_scenario_base(&"route_base", &"route")]
    mismatched_route.known_item_tags = _live_tags(route_equipment)
    TestAssertions.truthy(
        mismatched_route.validate(stats, route_equipment).has("PARTY_FORGE_ITEM_RARITY_ERROR id=rare pattern=rare_balanced reason=no complete live generation scenario"),
        "whole pattern requires one compatible domain and source",
        failures,
    )

    TestAssertions.truthy(
        live_foundation.validate(stats, live_equipment, 0).has("PARTY_FORGE_ITEM_RARITY_ERROR id=uncommon pattern=uncommon_prefix reason=reachability exploration budget exhausted"),
        "reachability budget exhaustion rejects instead of accepting",
        failures,
    )

func _assert_canonical_generation_tag_registry(
    live_foundation: ItemFoundationCatalog,
    live_equipment: EquipmentCatalog,
    stats: StatCatalog,
    failures: Array[String]
) -> void:
    TestAssertions.equal(live_foundation.known_item_tags, _live_tags(live_equipment), "manifest tag registry is exact live normalized union", failures)
    var injected_equipment := live_equipment.duplicate(true) as EquipmentCatalog
    injected_equipment.definitions[0] = injected_equipment.definitions[0].duplicate(true) as EquipmentBaseDefinition
    injected_equipment.definitions[0].generation_tags.append(&"injected_explicit_tag")
    TestAssertions.truthy(
        live_foundation.validate(stats, injected_equipment).has("PARTY_FORGE_ITEM_MANIFEST_ERROR reason=missing current equipment item tag injected_explicit_tag"),
        "explicit equipment generation tag requires manifest registration",
        failures,
    )
    var registered := live_foundation.duplicate(true) as ItemFoundationCatalog
    registered.known_item_tags.append(&"injected_explicit_tag")
    registered.known_item_tags.sort()
    var request := ItemGenerationRequest.create(5, 0, 1, &"ordinary_enemy", &"ordinary_drop", [&"common"])
    request.required_base_tags = [&"injected_explicit_tag"]
    TestAssertions.equal(request.validate(registered), "", "registered explicit generation tag is accepted by requests", failures)

func _scenario_foundation(
    source: ItemFoundationCatalog,
    prefix_tag: StringName,
    suffix_tag: StringName,
    prefix_domain: StringName,
    prefix_source: StringName,
    suffix_domain: StringName,
    suffix_source: StringName
) -> ItemFoundationCatalog:
    var result := source.duplicate(true) as ItemFoundationCatalog
    var prefix := result.affix(&"stout").duplicate(true) as ItemAffixDefinition
    var suffix := result.affix(&"of_embers").duplicate(true) as ItemAffixDefinition
    prefix.required_item_tags = [prefix_tag]
    suffix.required_item_tags = [suffix_tag]
    prefix.allowed_generation_domains = [prefix_domain]
    suffix.allowed_generation_domains = [suffix_domain]
    prefix.allowed_source_ids = [prefix_source]
    suffix.allowed_source_ids = [suffix_source]
    result.affixes = [prefix, suffix]
    return result

func _scenario_base(id: StringName, tag: StringName) -> EquipmentBaseDefinition:
    var base := EquipmentBaseDefinition.new()
    base.id = id
    base.generation_tags = [tag]
    base.required_any_tags = [tag]
    return base

func _live_tags(equipment: EquipmentCatalog) -> Array[StringName]:
    var result: Array[StringName] = []
    for base: EquipmentBaseDefinition in equipment.definitions:
        if base == null:
            continue
        for tag: StringName in base.normalized_generation_tags():
            if tag not in result:
                result.append(tag)
    result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
    return result

func _rarity_index(catalog: ItemFoundationCatalog, id: StringName) -> int:
    for index: int in catalog.rarities.size():
        if catalog.rarities[index] != null and catalog.rarities[index].id == id:
            return index
    return -1

func _affix_index(catalog: ItemFoundationCatalog, id: StringName) -> int:
    for index: int in catalog.affixes.size():
        if catalog.affixes[index] != null and catalog.affixes[index].id == id:
            return index
    return -1

func _equipment_index(catalog: EquipmentCatalog, id: StringName) -> int:
    for index: int in catalog.definitions.size():
        if catalog.definitions[index] != null and catalog.definitions[index].id == id:
            return index
    return -1

func _assert_class_names_and_eligibility(catalog: GameCatalog, failures: Array[String]) -> void:
    var expected_names := {
        &"fighter": PackedStringArray(["Aldric", "Branna", "Cedric", "Dagna", "Garrick", "Hilda", "Rowan", "Thane"]),
        &"ranger": PackedStringArray(["Ash", "Briar", "Elowen", "Fen", "Linden", "Robin", "Sylvi", "Wren"]),
        &"mage": PackedStringArray(["Alaric", "Circe", "Elara", "Isolde", "Lucan", "Mira", "Orin", "Selene"]),
        &"cleric": PackedStringArray(["Ansel", "Beatrix", "Clement", "Faith", "Mercy", "Sabine", "Tobias", "Verity"]),
        &"paladin": PackedStringArray(["Aegis", "Armand", "Galahad", "Helena", "Roland", "Seraphine", "Tristan", "Valora"]),
        &"rogue": PackedStringArray(["Corvin", "Flick", "Jax", "Nyx", "Rook", "Shade", "Talia", "Vesper"]),
        &"frost_mage": PackedStringArray(["Boreas", "Eira", "Iskra", "Lumi", "Neve", "Rime", "Skadi", "Ylva"]),
        &"warlock": PackedStringArray(["Azrael", "Belladonna", "Dorian", "Hex", "Lilith", "Malachar", "Morwen", "Sable"]),
        &"marksman": PackedStringArray(["Arlen", "Blythe", "Cora", "Fletcher", "Hawke", "Ivo", "Petra", "Quinn"]),
    }
    for definition: ClassDefinition in catalog.classes:
        TestAssertions.truthy(definition.name_pool != null, "%s has name pool" % definition.id, failures)
        if definition.name_pool != null:
            TestAssertions.equal(definition.name_pool.id, definition.id, "%s name pool id" % definition.id, failures)
            TestAssertions.equal(definition.name_pool.names, expected_names[definition.id], "%s exact names" % definition.id, failures)
            TestAssertions.equal(definition.name_pool.resource_path, "res://data/names/%s.tres" % definition.id, "%s external name pool" % definition.id, failures)
        TestAssertions.equal(definition.name_pool.validate(8), PackedStringArray(), "%s name pool validates" % definition.id, failures)
        if EXPECTED_CAPABILITIES.has(definition.id):
            TestAssertions.equal(definition.capability_tags, EXPECTED_CAPABILITIES[definition.id], "%s explicit capabilities" % definition.id, failures)
        var expected_union: Array[StringName] = []
        expected_union.append_array(definition.traits)
        expected_union.append_array(definition.capability_tags)
        expected_union.sort()
        var deduped: Array[StringName] = []
        for tag: StringName in expected_union:
            if tag not in deduped:
                deduped.append(tag)
        TestAssertions.equal(definition.normalized_eligibility_tags(), deduped, "%s eligibility tags are deduped and sorted" % definition.id, failures)

func _assert_persisted_attack_damage_path(failures: Array[String]) -> void:
    var path := "user://typed_combat_malformed_attack.tres"
    var attack := AttackDefinition.new()
    attack.id = &"malformed_persisted"
    TestAssertions.equal(ResourceSaver.save(attack, path), OK, "malformed attack fixture saves", failures)
    var persisted_attack := load(path) as AttackDefinition
    TestAssertions.truthy(persisted_attack != null, "malformed attack fixture loads", failures)
    if persisted_attack == null:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
        return
    var definition := TypedAttackErrorClass.new()
    definition.id = &"typed_error_fixture"
    definition.primary_attack = persisted_attack
    var catalog := GameCatalog.new()
    catalog.classes.append(definition)
    TestAssertions.equal(catalog.validate(), PackedStringArray([
        "PARTY_FORGE_DAMAGE_ERROR path=%s attack=malformed_persisted type=void reason=unknown component type" % path,
    ]), "persisted attack retains damage prefix and attack path", failures)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _assert_generated_values(failures: Array[String]) -> void:
    var attack_rows: Array[Dictionary] = [
        {"path": "res://data/attacks/fighter_cleave.tres", "values": {"id": &"fighter_cleave", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "cooldown": 0.8, "range": 2.2, "projectile_speed": 0.0, "area_radius": 1.6, "damage_source": 1}, "damage_type": &"physical", "damage_amount": 18.0},
        {"path": "res://data/attacks/ranger_shot.tres", "values": {"id": &"ranger_shot", "kind": AttackDefinition.Kind.PROJECTILE, "cooldown": 0.55, "range": 11.0, "projectile_speed": 16.0, "area_radius": 0.0, "damage_source": 1}, "damage_type": &"physical", "damage_amount": 11.0},
        {"path": "res://data/attacks/mage_burst.tres", "values": {"id": &"mage_burst", "kind": AttackDefinition.Kind.AREA_PROJECTILE, "cooldown": 1.5, "range": 12.0, "projectile_speed": 11.0, "area_radius": 2.5, "action_tags": [&"area", &"caster", &"fire", &"projectile"]}, "damage_type": &"fire", "damage_amount": 24.0},
        {"path": "res://data/attacks/cleric_bolt.tres", "values": {"id": &"cleric_bolt", "kind": AttackDefinition.Kind.PROJECTILE, "cooldown": 1.0, "range": 10.0, "projectile_speed": 13.0, "area_radius": 0.0, "action_tags": [&"caster", &"lightning", &"projectile"]}, "damage_type": &"lightning", "damage_amount": 8.0},
        {"path": "res://data/attacks/cleric_heal.tres", "values": {"id": &"cleric_heal", "kind": AttackDefinition.Kind.HEAL, "power": 18.0, "cooldown": 3.0, "range": 9.0, "projectile_speed": 0.0, "area_radius": 0.0}},
        {"path": "res://data/attacks/paladin_smite.tres", "values": {"id": &"paladin_smite", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "power": 0.0, "cooldown": 1.05, "range": 2.1, "projectile_speed": 0.0, "area_radius": 1.4, "action_tags": [&"area", &"melee", &"physical"], "can_crit": true, "damage_source": 1}, "damage_type": &"physical", "damage_amount": 16.0},
        {"path": "res://data/attacks/rogue_flurry.tres", "values": {"id": &"rogue_flurry", "kind": AttackDefinition.Kind.MELEE_CLEAVE, "power": 0.0, "cooldown": 0.32, "range": 2.0, "projectile_speed": 0.0, "area_radius": 0.9, "action_tags": [&"area", &"melee", &"physical", &"skirmisher"], "can_crit": true, "damage_source": 1}, "damage_type": &"physical", "damage_amount": 8.0},
        {"path": "res://data/attacks/frost_shard.tres", "values": {"id": &"frost_shard", "kind": AttackDefinition.Kind.AREA_PROJECTILE, "power": 0.0, "cooldown": 1.35, "range": 12.5, "projectile_speed": 10.0, "area_radius": 3.0, "action_tags": [&"area", &"caster", &"cold", &"projectile"], "can_crit": true}, "damage_type": &"cold", "damage_amount": 20.0},
        {"path": "res://data/attacks/warlock_bolt.tres", "values": {"id": &"warlock_bolt", "kind": AttackDefinition.Kind.PROJECTILE, "power": 0.0, "cooldown": 1.75, "range": 12.5, "projectile_speed": 9.0, "area_radius": 0.0, "action_tags": [&"caster", &"chaos", &"projectile"], "can_crit": true}, "damage_type": &"chaos", "damage_amount": 30.0},
        {"path": "res://data/attacks/marksman_heavy_shot.tres", "values": {"id": &"marksman_heavy_shot", "kind": AttackDefinition.Kind.PROJECTILE, "power": 0.0, "cooldown": 2.2, "range": 16.0, "projectile_speed": 22.0, "area_radius": 0.0, "action_tags": [&"bow", &"physical", &"projectile", &"ranged"], "can_crit": true, "damage_source": 1}, "damage_type": &"physical", "damage_amount": 42.0},
        {"path": "res://data/attacks/boltcaster_bolt.tres", "values": {"id": &"boltcaster_bolt", "kind": AttackDefinition.Kind.PROJECTILE, "cooldown": 2.4, "range": 16.0, "projectile_speed": 8.0, "area_radius": 0.0, "action_tags": [&"projectile", &"ranged"]}, "damage_type": &"physical", "damage_amount": 9.0},
    ]
    var class_rows: Array[Dictionary] = [
        {"path": "res://data/classes/fighter.tres", "values": {"id": &"fighter", "display_name": "Fighter", "role": ClassDefinition.Role.FRONTLINE, "color": Color("d94f4f"), "traits": [&"martial", &"vanguard"], "max_health": 260.0, "armor": 10.0, "move_speed": 6.2, "preferred_distance": 2.0, "engagement_distance": 5.0, "tether_distance": 9.0, "support_action": null}},
        {"path": "res://data/classes/ranger.tres", "values": {"id": &"ranger", "display_name": "Ranger", "role": ClassDefinition.Role.MIDLINE, "color": Color("5fbd72"), "traits": [&"martial", &"ranged"], "max_health": 90.0, "armor": 1.0, "move_speed": 6.6, "preferred_distance": 5.0, "engagement_distance": 11.0, "tether_distance": 11.0, "support_action": null}},
        {"path": "res://data/classes/mage.tres", "values": {"id": &"mage", "display_name": "Mage", "role": ClassDefinition.Role.BACKLINE, "color": Color("9567e8"), "traits": [&"arcane", &"caster", &"fire"], "max_health": 75.0, "armor": 0.0, "move_speed": 6.0, "preferred_distance": 6.5, "engagement_distance": 12.0, "tether_distance": 12.0, "support_action": null}},
        {"path": "res://data/classes/cleric.tres", "values": {"id": &"cleric", "display_name": "Cleric", "role": ClassDefinition.Role.SUPPORT, "color": Color("f0d15b"), "traits": [&"divine", &"support", &"caster"], "max_health": 95.0, "armor": 2.0, "move_speed": 6.0, "preferred_distance": 4.0, "engagement_distance": 10.0, "tether_distance": 10.0}},
        {"path": "res://data/classes/paladin.tres", "values": {"id": &"paladin", "display_name": "Paladin", "role": ClassDefinition.Role.FRONTLINE, "color": Color("e6c85f"), "traits": [&"divine", &"vanguard", &"martial"], "capability_tags": EXPECTED_CAPABILITIES[&"paladin"], "base_stat_overrides": {&"block_chance": 0.18, &"block_effectiveness": 0.55, &"health_regeneration": 1.5}, "max_health": 220.0, "armor": 18.0, "move_speed": 5.6, "preferred_distance": 2.0, "engagement_distance": 4.5, "tether_distance": 8.5, "support_action": null}},
        {"path": "res://data/classes/rogue.tres", "values": {"id": &"rogue", "display_name": "Rogue", "role": ClassDefinition.Role.MIDLINE, "color": Color("a95be8"), "traits": [&"martial", &"skirmisher"], "capability_tags": EXPECTED_CAPABILITIES[&"rogue"], "base_stat_overrides": {&"crit_chance": 0.20, &"crit_multiplier": 1.75, &"dodge_chance": 0.18, &"life_steal": 0.05}, "max_health": 72.0, "armor": 0.0, "move_speed": 7.4, "preferred_distance": 1.4, "engagement_distance": 3.0, "tether_distance": 8.0, "support_action": null}},
        {"path": "res://data/classes/frost_mage.tres", "values": {"id": &"frost_mage", "display_name": "Frost Mage", "role": ClassDefinition.Role.BACKLINE, "color": Color("70c8ff"), "traits": [&"arcane", &"caster", &"cold"], "capability_tags": EXPECTED_CAPABILITIES[&"frost_mage"], "base_stat_overrides": {}, "max_health": 78.0, "armor": 0.0, "move_speed": 6.0, "preferred_distance": 6.5, "engagement_distance": 12.5, "tether_distance": 12.5, "support_action": null}},
        {"path": "res://data/classes/warlock.tres", "values": {"id": &"warlock", "display_name": "Warlock", "role": ClassDefinition.Role.BACKLINE, "color": Color("7e4bc4"), "traits": [&"occult", &"caster", &"chaos"], "capability_tags": EXPECTED_CAPABILITIES[&"warlock"], "base_stat_overrides": {&"chaos_damage": 1.10, &"life_steal": 0.12}, "max_health": 82.0, "armor": 1.0, "move_speed": 5.8, "preferred_distance": 6.0, "engagement_distance": 12.5, "tether_distance": 12.5, "support_action": null}},
        {"path": "res://data/classes/marksman.tres", "values": {"id": &"marksman", "display_name": "Marksman", "role": ClassDefinition.Role.MIDLINE, "color": Color(0.27579924, 0.36415747, 0.056183092, 1.0), "traits": [&"martial", &"ranged", &"bow"], "capability_tags": EXPECTED_CAPABILITIES[&"marksman"], "base_stat_overrides": {&"crit_chance": 0.10, &"crit_multiplier": 2.0}, "max_health": 80.0, "armor": 2.0, "move_speed": 5.8, "preferred_distance": 8.0, "engagement_distance": 16.0, "tether_distance": 16.0, "support_action": null}},
    ]
    var trait_rows: Array[Dictionary] = [
        {"path": "res://data/traits/martial.tres", "values": {"id": &"martial", "display_name": "Martial", "stat_id": &"attack_speed", "tiers": {2: 0.15, 4: 0.35}}},
        {"path": "res://data/traits/vanguard.tres", "values": {"id": &"vanguard", "display_name": "Vanguard", "stat_id": &"nearby_damage_reduction", "tiers": {2: 0.12, 4: 0.28}}},
        {"path": "res://data/traits/ranged.tres", "values": {"id": &"ranged", "display_name": "Ranged", "stat_id": &"projectile_speed_and_range", "tiers": {2: 0.15, 4: 0.35}}},
        {"path": "res://data/traits/arcane.tres", "values": {"id": &"arcane", "display_name": "Arcane", "stat_id": &"area_size", "tiers": {2: 0.18, 4: 0.40}}},
        {"path": "res://data/traits/caster.tres", "values": {"id": &"caster", "display_name": "Caster", "stat_id": &"cooldown_reduction", "tiers": {2: 0.12, 4: 0.28}}},
        {"path": "res://data/traits/divine.tres", "values": {"id": &"divine", "display_name": "Divine", "stat_id": &"healing_and_revive", "tiers": {2: 0.18, 4: 0.40}}},
        {"path": "res://data/traits/support.tres", "values": {"id": &"support", "display_name": "Support", "stat_id": &"support_power", "tiers": {2: 0.15, 4: 0.35}}},
    ]
    var enemy_rows: Array[Dictionary] = [
        {"path": "res://data/enemies/swarmer.tres", "values": {"id": &"swarmer", "behavior": EnemyDefinition.Behavior.SWARMER, "max_health": 12.0, "move_speed": 4.8, "stat_overrides": {}, "experience": 2}, "attacks": [&"swarmer_contact"]},
        {"path": "res://data/enemies/spitter.tres", "values": {"id": &"spitter", "behavior": EnemyDefinition.Behavior.SPITTER, "max_health": 18.0, "move_speed": 2.8, "stat_overrides": {}, "experience": 4}, "attacks": [&"spitter_projectile"]},
        {"path": "res://data/enemies/boltcaster.tres", "values": {"id": &"boltcaster", "behavior": EnemyDefinition.Behavior.BOLTCASTER, "max_health": 15.0, "move_speed": 3.1, "stat_overrides": {}, "experience": 3}, "attacks": [&"boltcaster_bolt"]},
        {"path": "res://data/enemies/forge_guardian.tres", "values": {"id": &"forge_guardian", "behavior": EnemyDefinition.Behavior.FORGE_GUARDIAN, "max_health": 3000.0, "move_speed": 3.3, "stat_overrides": {}, "experience": 100}, "attacks": [&"guardian_charge", &"guardian_shockwave"]},
    ]
    _assert_resource_table("attack", attack_rows, failures)
    _assert_resource_table("class", class_rows, failures)
    _assert_resource_table("trait", trait_rows, failures)
    _assert_resource_table("enemy", enemy_rows, failures)

func _assert_resource_table(kind: String, rows: Array[Dictionary], failures: Array[String]) -> void:
    for row: Dictionary in rows:
        var path: String = row["path"]
        var resource: Resource = load(path)
        TestAssertions.truthy(resource != null, "%s resource loads: %s" % [kind, path], failures)
        if resource == null:
            continue
        var values: Dictionary = row["values"]
        for property: Variant in values:
            var expected: Variant = values[property]
            var label: String = "%s %s %s" % [kind, resource.get("id"), property]
            if typeof(expected) == TYPE_FLOAT:
                TestAssertions.near(float(resource.get(property)), float(expected), 0.001, label, failures)
            else:
                TestAssertions.equal(resource.get(property), expected, label, failures)
        if kind == "attack" and row.has("damage_type"):
            var attack := resource as AttackDefinition
            TestAssertions.equal(attack.damage_components.size(), 1, "attack %s one damage component" % attack.id, failures)
            if attack.damage_components.size() == 1:
                TestAssertions.equal(attack.damage_components[0].damage_type_id, row["damage_type"], "attack %s damage type" % attack.id, failures)
                TestAssertions.near(attack.damage_components[0].base_amount, row["damage_amount"], 0.001, "attack %s damage amount" % attack.id, failures)
        if kind == "enemy" and row.has("attacks"):
            var enemy := resource as EnemyDefinition
            var ids: Array[StringName] = []
            for attack: AttackDefinition in enemy.attacks:
                ids.append(attack.id)
            TestAssertions.equal(ids, row["attacks"], "enemy %s exact attack links" % enemy.id, failures)
