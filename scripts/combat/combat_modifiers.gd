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
    if member_state == null or party_manager == null:
        return result
    var stats := party_manager.stats_for(member_state.member_id)
    if stats == null:
        return result
    result.power_multiplier = stats.value(&"damage", 1.0)
    result.cooldown_rate_multiplier = stats.value(&"attack_speed", 1.0)
    result.projectile_multiplier = stats.value(&"projectile_speed", 1.0)
    result.range_multiplier = stats.value(&"attack_range", 1.0)
    result.area_multiplier = stats.value(&"area_size", 1.0)
    result.healing_multiplier = stats.value(&"healing_power", 1.0)
    return result
