class_name ActionCombatEstimateService
extends RefCounted

const ACTION_ARCHETYPE := preload("res://scripts/combat/action_archetype.gd")
const ACTION_DAMAGE_PROJECTION := preload("res://scripts/combat/action_damage_projection.gd")

static func estimate(attack: AttackDefinition, member_id: int, party: PartyManager, types: DamageTypeCatalog) -> ActionCombatEstimate:
	var result := ActionCombatEstimate.new()
	if attack == null:
		return _unavailable(result, "Missing attack definition.")
	result.action_id = attack.id
	result.display_name = String(attack.id).replace("_", " ").capitalize()
	if party == null or types == null or member_id <= 0:
		return _unavailable(result, "Missing character combat data.")
	var validation := attack.validate(types)
	if not validation.is_empty():
		return _unavailable(result, String(validation[0]).trim_prefix("PARTY_FORGE_DAMAGE_ERROR "))
	if attack.is_healing():
		return _unavailable(result, "Action does not deal direct damage.")
	var action_stats := party.stats_for_action(member_id, DamageResolver.action_tags_for(attack))
	if action_stats == null:
		return _unavailable(result, "Missing resolved character stats.")
	result.can_crit = attack.can_crit
	var crit_chance := action_stats.value(&"crit_chance", 0.0) if result.can_crit else 0.0
	if not is_finite(crit_chance):
		return _unavailable(result, "Invalid resolved critical chance.")
	crit_chance = clampf(crit_chance, 0.0, 1.0)
	var crit_multiplier := maxf(1.0, action_stats.value(&"crit_multiplier", 1.5))
	var global_multiplier := action_stats.value(&"damage", 1.0)
	var archetype_stat_id := ACTION_ARCHETYPE.stat_id(attack)
	var archetype_multiplier := action_stats.value(archetype_stat_id, 1.0)
	for component: AttackDamageComponent in attack.damage_components:
		var type_definition := types.definition(component.damage_type_id)
		var normal := ACTION_DAMAGE_PROJECTION.normal_component(component.base_amount, global_multiplier, archetype_multiplier, action_stats.value(type_definition.offense_stat_id, 1.0))
		if not is_finite(normal) or normal < 0.0:
			return _unavailable(result, "Invalid derived damage for %s." % type_definition.display_name)
		var critical := normal * crit_multiplier if result.can_crit else normal
		var average := normal * (1.0 + crit_chance * (crit_multiplier - 1.0))
		result.normal_hit += normal
		result.critical_hit += critical
		result.average_hit += average
		result.component_rows.append({
			"damage_type_id": component.damage_type_id,
			"display_name": type_definition.display_name,
			"normal_hit": normal,
			"critical_hit": critical,
			"average_hit": average,
		})
	result.attacks_per_second = action_stats.value(&"attack_speed", 1.0) / attack.cooldown
	result.estimated_dps = result.average_hit * result.attacks_per_second
	if not is_finite(result.attacks_per_second) or result.attacks_per_second < 0.0 or not is_finite(result.estimated_dps):
		return _unavailable(result, "Invalid derived action rate.")
	result.available = true
	return result

static func _unavailable(result: ActionCombatEstimate, reason: String) -> ActionCombatEstimate:
	result.available = false
	result.unavailable_reason = reason
	return result
