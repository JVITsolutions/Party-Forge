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
    var action_stats: ResolvedStatSnapshot
    var geometry: ResolvedAttackGeometry
    var error := ""

    func ok() -> bool:
        return error.is_empty() and geometry != null and geometry.ok()

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


## Resolves every runtime modifier and effective geometry from the exact cached
## action-tagged member snapshot. Runtime ownership context is mandatory so a
## missing manager, member, or exact snapshot fails closed before execution.
static func resolve_for_action(member_state: PartyMemberState, party_manager: PartyManager, attack: AttackDefinition) -> Snapshot:
    var result := Snapshot.new()
    if attack == null:
        result.error = "missing attack definition"
        return result
    if member_state == null:
        result.error = "missing party member state"
        return result
    if party_manager == null:
        result.error = "missing party manager"
        return result
    var stats := party_manager.stats_for_action(member_state.member_id, DamageResolver.action_tags_for(attack))
    if stats == null:
        result.error = "missing resolved action snapshot"
        return result
    result.action_stats = stats
    result.attack_speed = stats.value(&"attack_speed", 1.0)
    result.cooldown_rate = stats.value(&"cooldown_rate", 1.0)
    var neutral_cooldown := ACTION_CADENCE.resolve(1.0, result.attack_speed, result.cooldown_rate)
    result.cooldown_rate_multiplier = float(neutral_cooldown.get("progress_multiplier")) if bool(neutral_cooldown.call("ok")) else NAN
    result.projectile_multiplier = stats.value(&"projectile_speed", 1.0)
    result.range_multiplier = stats.value(&"attack_range", 1.0)
    result.area_multiplier = stats.value(&"area_size", 1.0)
    result.geometry = ResolvedAttackGeometry.from_snapshot(attack, stats)
    if not result.geometry.ok():
        result.error = result.geometry.error
    return result

## Resolves action-tag-aware runtime cadence through the same formula as ledger
## estimates and candidate validation. Missing runtime ownership fails closed.
static func action_cadence(member_state: PartyMemberState, party_manager: PartyManager, attack: AttackDefinition) -> RefCounted:
    if attack == null:
        return ACTION_CADENCE.resolve(NAN, 1.0, 1.0)
    var modifiers := resolve_for_action(member_state, party_manager, attack)
    if not modifiers.ok():
        return ACTION_CADENCE.resolve(NAN, 1.0, 1.0)
    return ACTION_CADENCE.resolve(attack.cooldown, modifiers.attack_speed, modifiers.cooldown_rate)
