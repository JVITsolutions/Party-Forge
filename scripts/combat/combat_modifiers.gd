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
    var cadence: RefCounted
    var member_state: PartyMemberState
    var party_manager: PartyManager
    var attack_definition: AttackDefinition
    var error := ""

    func ok() -> bool:
        return error.is_empty() and geometry != null and geometry.ok() and cadence != null and bool(cadence.call("ok"))

    func matches(member: PartyMemberState, manager: PartyManager, attack: AttackDefinition) -> bool:
        return ok() and is_same(member_state, member) and is_same(party_manager, manager) and is_same(attack_definition, attack)

## Deprecated cadence-only compatibility path. Geometry multipliers are
## intentionally unavailable without exact action tags; use resolve_for_action.
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
    var authoritative_member := party_manager.member_by_id(member_state.member_id)
    if authoritative_member == null:
        result.error = "missing authoritative party member"
        return result
    if not is_same(authoritative_member, member_state):
        result.error = "party member state is not authoritative"
        return result
    var stats := party_manager.stats_for_action(member_state.member_id, DamageResolver.action_tags_for(attack))
    if stats == null:
        result.error = "missing resolved action snapshot"
        return result
    result.action_stats = stats
    result.member_state = member_state
    result.party_manager = party_manager
    result.attack_definition = attack
    result.attack_speed = stats.value(&"attack_speed", 1.0)
    result.cooldown_rate = stats.value(&"cooldown_rate", 1.0)
    result.cadence = ACTION_CADENCE.resolve(attack.cooldown, result.attack_speed, result.cooldown_rate)
    if not bool(result.cadence.call("ok")):
        result.error = String(result.cadence.get("error"))
        return result
    result.cooldown_rate_multiplier = float(result.cadence.get("progress_multiplier"))
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
    return modifiers.cadence
