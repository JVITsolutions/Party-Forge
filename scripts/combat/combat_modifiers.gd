class_name CombatModifiers
extends RefCounted

class Snapshot extends RefCounted:
    var power_multiplier := 1.0
    var cooldown_rate_multiplier := 1.0
    var projectile_multiplier := 1.0
    var range_multiplier := 1.0
    var area_multiplier := 1.0
    var healing_multiplier := 1.0

static func resolve(member_state: PartyMemberState, party_manager: PartyManager) -> Snapshot:
    var result := Snapshot.new()
    if member_state == null or member_state.class_definition == null:
        return result
    var definition: ClassDefinition = member_state.class_definition
    if party_manager == null:
        return result

    var class_rank: int = maxi(party_manager.get_class_rank(definition.id), 1)
    result.power_multiplier = (1.0 + float(class_rank - 1) * definition.class_rank_power_step) * party_manager.party_stat_multiplier(&"damage")
    result.cooldown_rate_multiplier *= party_manager.party_stat_multiplier(&"attack_speed")
    for trait_id: StringName in definition.traits:
        var active_threshold: int = party_manager.active_tier(trait_id)
        if active_threshold <= 0:
            continue
        var trait_definition := _trait_definition(party_manager, trait_id)
        if trait_definition == null:
            continue
        var active_value: float = party_manager.effective_trait_value(trait_id)
        match trait_definition.stat_id:
            &"attack_speed":
                result.cooldown_rate_multiplier *= 1.0 + active_value
            &"cooldown_reduction":
                result.cooldown_rate_multiplier *= 1.0 / maxf(1.0 - active_value, 0.05)
            &"projectile_speed_and_range":
                result.projectile_multiplier *= 1.0 + active_value
                result.range_multiplier *= 1.0 + active_value
            &"area_size":
                result.area_multiplier *= 1.0 + active_value
            &"support_power", &"healing_and_revive":
                result.healing_multiplier *= 1.0 + active_value
    return result

static func _trait_definition(party_manager: PartyManager, trait_id: StringName) -> TraitDefinition:
    return party_manager.trait_definition(trait_id)
