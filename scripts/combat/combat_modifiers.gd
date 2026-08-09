class_name CombatModifiers
extends RefCounted

const ACTION_CADENCE := preload("res://scripts/combat/action_cadence.gd")

class Snapshot extends RefCounted:
    var attack_speed := 1.0
    var cooldown_rate := 1.0
    var cooldown_rate_multiplier := 1.0
    var projectile_multiplier := 1.0
    var range_multiplier := 1.0
    var area_multiplier := 1.0

static func resolve(member_state: PartyMemberState, party_manager: PartyManager) -> Snapshot:
    var result := Snapshot.new()
    if member_state == null or party_manager == null:
        return result
    var stats := party_manager.stats_for(member_state.member_id)
    if stats == null:
        return result
    result.attack_speed = stats.value(&"attack_speed", 1.0)
    result.cooldown_rate = stats.value(&"cooldown_rate", 1.0)
    var neutral_cooldown := ACTION_CADENCE.resolve(1.0, result.attack_speed, result.cooldown_rate)
    result.cooldown_rate_multiplier = float(neutral_cooldown.get("progress_multiplier")) if bool(neutral_cooldown.call("ok")) else NAN
    result.projectile_multiplier = stats.value(&"projectile_speed", 1.0)
    result.range_multiplier = stats.value(&"attack_range", 1.0)
    result.area_multiplier = stats.value(&"area_size", 1.0)
    return result

## Resolves action-tag-aware runtime cadence through the same formula as ledger
## estimates and candidate validation. Missing runtime ownership stays neutral
## for compatibility with standalone actor fixtures.
static func action_cadence(member_state: PartyMemberState, party_manager: PartyManager, attack: AttackDefinition) -> RefCounted:
    if attack == null:
        return ACTION_CADENCE.resolve(NAN, 1.0, 1.0)
    var attack_speed := 1.0
    var cooldown_rate := 1.0
    if member_state != null and party_manager != null:
        var stats := party_manager.stats_for_action(member_state.member_id, DamageResolver.action_tags_for(attack))
        if stats != null:
            attack_speed = stats.value(&"attack_speed", 1.0)
            cooldown_rate = stats.value(&"cooldown_rate", 1.0)
    return ACTION_CADENCE.resolve(attack.cooldown, attack_speed, cooldown_rate)
