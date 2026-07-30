class_name PartyManager
extends Node

signal member_added(member: PartyMemberState)
signal class_rank_changed(class_id: StringName, rank: int)
signal active_traits_changed(tiers: Dictionary)
signal upgrades_changed
signal stats_changed(member_id: int)

const MAX_PARTY_SIZE := 4
const PARTY_STAT_IDS: Array[StringName] = [&"max_health", &"damage", &"move_speed", &"attack_speed", &"pickup_radius"]
const DEFAULT_UPGRADE_TUNING: UpgradeTuning = preload("res://data/upgrades/default_upgrades.tres")
const STAT_CATALOG: StatCatalog = preload("res://data/stats/core_stats.tres")
var members: Array[PartyMemberState] = []
var class_ranks: Dictionary = {}
var trait_definitions: Array[TraitDefinition] = []
var active_tiers: Dictionary = {}
var party_stat_ranks: Dictionary = {}
var trait_upgrade_ranks: Dictionary = {}
var upgrade_tuning: UpgradeTuning = DEFAULT_UPGRADE_TUNING
var _stat_revision := 0
var _stat_cache: Dictionary = {}

func _init() -> void:
    for stat_id: StringName in PARTY_STAT_IDS:
        party_stat_ranks[stat_id] = 0

func initialize(leader_class: ClassDefinition, traits: Array[TraitDefinition], tuning: UpgradeTuning = null) -> void:
    members.clear(); class_ranks.clear(); active_tiers.clear(); trait_upgrade_ranks.clear(); trait_definitions = traits
    upgrade_tuning = tuning if tuning != null else DEFAULT_UPGRADE_TUNING
    for stat_id: StringName in PARTY_STAT_IDS:
        party_stat_ranks[stat_id] = 0
    _append_member(leader_class, true)

func recruit(definition: ClassDefinition) -> bool:
    if definition == null or members.size() >= MAX_PARTY_SIZE:
        return false
    _append_member(definition, false)
    return true

func member_by_id(member_id: int) -> PartyMemberState:
    for member: PartyMemberState in members:
        if member.member_id == member_id:
            return member
    return null

func stats_for(member_id: int) -> ResolvedStatSnapshot:
    var member := member_by_id(member_id)
    if member == null:
        return null
    if _stat_cache.has(member_id):
        return _stat_cache[member_id] as ResolvedStatSnapshot
    var snapshot := StatResolver.resolve(member_id, STAT_CATALOG, member.class_definition.stat_base_values(), member.capability_tags, _sources_for(member), [], _stat_revision)
    _stat_cache[member_id] = snapshot
    return snapshot

func add_member_source(member_id: int, source: StatModifierSource) -> bool:
    var member := member_by_id(member_id)
    if member == null or source == null:
        return false
    var validation_errors := StatResolver.validate_sources(STAT_CATALOG, [source])
    if not validation_errors.is_empty():
        for error: String in validation_errors:
            push_error(error)
        return false
    source.owner_member_id = member_id
    member.modifier_sources.append(source)
    _invalidate_member(member_id)
    return true

func _invalidate_member(member_id: int) -> void:
    _stat_revision += 1
    _stat_cache.erase(member_id)
    stats_changed.emit(member_id)

func _invalidate_all_members() -> void:
    _stat_revision += 1
    _stat_cache.clear()
    for member: PartyMemberState in members:
        stats_changed.emit(member.member_id)

func rank_up(class_id: StringName) -> bool:
    if not class_ranks.has(class_id):
        return false
    class_ranks[class_id] = int(class_ranks[class_id]) + 1
    _invalidate_all_members()
    class_rank_changed.emit(class_id, int(class_ranks[class_id]))
    return true

func get_class_rank(class_id: StringName) -> int:
    return int(class_ranks.get(class_id, 0))

func trait_count(trait_id: StringName) -> int:
    var count := 0
    for member: PartyMemberState in members:
        if trait_id in member.class_definition.traits:
            count += 1
    return count

func active_tier(trait_id: StringName) -> int:
    return int(active_tiers.get(trait_id, 0))

func upgrade_party_stat(stat_id: StringName) -> bool:
    if stat_id not in PARTY_STAT_IDS or party_stat_rank(stat_id) >= upgrade_tuning.party_stat_max_rank:
        return false
    party_stat_ranks[stat_id] = party_stat_rank(stat_id) + 1
    _invalidate_all_members()
    upgrades_changed.emit()
    return true

func party_stat_rank(stat_id: StringName) -> int:
    return int(party_stat_ranks.get(stat_id, 0))

func party_stat_multiplier(stat_id: StringName) -> float:
    var step := 0.0
    match stat_id:
        &"max_health": step = upgrade_tuning.max_health_per_rank
        &"damage": step = upgrade_tuning.damage_per_rank
        &"move_speed": step = upgrade_tuning.move_speed_per_rank
        &"attack_speed": step = upgrade_tuning.attack_speed_per_rank
        &"pickup_radius": step = upgrade_tuning.pickup_radius_per_rank
        _: return 1.0
    return 1.0 + float(party_stat_rank(stat_id)) * step

func upgrade_trait(trait_id: StringName) -> bool:
    if active_tier(trait_id) <= 0 or trait_definition(trait_id) == null:
        return false
    trait_upgrade_ranks[trait_id] = trait_upgrade_rank(trait_id) + 1
    _invalidate_all_members()
    upgrades_changed.emit()
    return true

func trait_upgrade_rank(trait_id: StringName) -> int:
    return int(trait_upgrade_ranks.get(trait_id, 0))

func effective_trait_value(trait_id: StringName) -> float:
    var definition := trait_definition(trait_id)
    var tier := active_tier(trait_id)
    if definition == null or tier <= 0:
        return 0.0
    var base_value := float(definition.tiers.get(tier, 0.0))
    return base_value * (1.0 + float(trait_upgrade_rank(trait_id)) * upgrade_tuning.trait_upgrade_value_step)

func trait_definition(trait_id: StringName) -> TraitDefinition:
    for definition: TraitDefinition in trait_definitions:
        if definition != null and definition.id == trait_id:
            return definition
    return null

func revive_delay_multiplier() -> float:
    return maxf(0.1, 1.0 - effective_trait_value(&"divine"))

func incoming_damage_multiplier(target_actor: Node3D) -> float:
    if target_actor == null or active_tier(&"vanguard") <= 0:
        return 1.0
    var definition := trait_definition(&"vanguard")
    if definition == null:
        return 1.0
    var target_position: Vector3 = target_actor.global_position if target_actor.is_inside_tree() else target_actor.position
    var actor_nodes: Array[Node] = []
    if is_inside_tree():
        actor_nodes.assign(get_tree().get_nodes_in_group(&"party_actors"))
    elif get_parent() != null:
        for candidate: Node in get_parent().find_children("*", "PartyActor", true, false):
            actor_nodes.append(candidate)
    for actor_node: Node in actor_nodes:
        var actor := actor_node as PartyActor
        if actor == null or actor == target_actor or actor.party_manager != self or actor.member_state == null:
            continue
        if &"vanguard" not in actor.member_state.class_definition.traits:
            continue
        var combat_target := actor.get_combat_target()
        if not combat_target.is_available:
            continue
        var actor_position: Vector3 = actor.global_position if actor.is_inside_tree() else actor.position
        if actor_position.distance_to(target_position) <= definition.effect_radius:
            return maxf(0.0, 1.0 - effective_trait_value(&"vanguard"))
    return 1.0

func _sources_for(member: PartyMemberState) -> Array[StatModifierSource]:
    var sources: Array[StatModifierSource] = []
    var definition := member.class_definition
    var rank_bonus := float(maxi(get_class_rank(definition.id), 1) - 1) * definition.class_rank_power_step
    var class_rank_id := StringName("class_rank_%s" % definition.id)
    sources.append(StatModifierSource.create(
        class_rank_id,
        &"class_rank",
        "%s Rank" % definition.display_name,
        0,
        [StatModifier.create(&"damage", StatModifier.Operation.INCREASED, rank_bonus, class_rank_id, "%s Rank" % definition.display_name)],
    ))
    for source: StatModifierSource in member.modifier_sources:
        sources.append(source)

    var party_modifiers: Array[StatModifier] = []
    for stat_id: StringName in PARTY_STAT_IDS:
        var amount := float(party_stat_rank(stat_id)) * _party_stat_step(stat_id)
        party_modifiers.append(StatModifier.create(stat_id, StatModifier.Operation.INCREASED, amount, StringName("party_%s" % stat_id), "Party %s" % String(stat_id).capitalize()))
    sources.append(StatModifierSource.create(&"party_upgrades", &"party", "Party Upgrades", 0, party_modifiers))

    var trait_modifiers: Array[StatModifier] = []
    for trait_id: StringName in definition.traits:
        var trait_data := trait_definition(trait_id)
        var active_value := effective_trait_value(trait_id)
        if trait_data == null or active_value <= 0.0:
            continue
        var label := trait_data.display_name
        match trait_data.stat_id:
            &"attack_speed":
                trait_modifiers.append(StatModifier.create(&"attack_speed", StatModifier.Operation.INCREASED, active_value, trait_id, label))
            &"cooldown_reduction":
                trait_modifiers.append(StatModifier.create(&"attack_speed", StatModifier.Operation.MORE, 1.0 / maxf(1.0 - active_value, 0.05) - 1.0, trait_id, label))
            &"projectile_speed_and_range":
                trait_modifiers.append(StatModifier.create(&"projectile_speed", StatModifier.Operation.INCREASED, active_value, trait_id, label))
                trait_modifiers.append(StatModifier.create(&"attack_range", StatModifier.Operation.INCREASED, active_value, trait_id, label))
            &"area_size":
                trait_modifiers.append(StatModifier.create(&"area_size", StatModifier.Operation.INCREASED, active_value, trait_id, label))
            &"support_power", &"healing_and_revive":
                trait_modifiers.append(StatModifier.create(&"healing_power", StatModifier.Operation.INCREASED, active_value, trait_id, label))
    sources.append(StatModifierSource.create(&"active_traits", &"trait", "Active Traits", 0, trait_modifiers))
    return sources

func _party_stat_step(stat_id: StringName) -> float:
    match stat_id:
        &"max_health": return upgrade_tuning.max_health_per_rank
        &"damage": return upgrade_tuning.damage_per_rank
        &"move_speed": return upgrade_tuning.move_speed_per_rank
        &"attack_speed": return upgrade_tuning.attack_speed_per_rank
        &"pickup_radius": return upgrade_tuning.pickup_radius_per_rank
        _: return 0.0

func _append_member(definition: ClassDefinition, leader: bool) -> void:
    var member := PartyMemberState.new(members.size() + 1, definition, leader)
    members.append(member)
    if not class_ranks.has(definition.id): class_ranks[definition.id] = 1
    if not _recalculate_traits():
        _invalidate_all_members()
    member_added.emit(member)

func _recalculate_traits() -> bool:
    var next: Dictionary = {}
    for definition: TraitDefinition in trait_definitions:
        var count: int = trait_count(definition.id)
        var achieved := 0
        for threshold: Variant in definition.tiers.keys():
            if count >= int(threshold): achieved = maxi(achieved, int(threshold))
        if achieved > 0: next[definition.id] = achieved
    if next == active_tiers:
        return false
    active_tiers = next
    _invalidate_all_members()
    active_traits_changed.emit(active_tiers.duplicate())
    return true
