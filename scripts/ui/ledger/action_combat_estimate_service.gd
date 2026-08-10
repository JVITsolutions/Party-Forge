class_name ActionCombatEstimateService
extends RefCounted

const ACTION_ARCHETYPE := preload("res://scripts/combat/action_archetype.gd")
const ACTION_DAMAGE_PROJECTION := preload("res://scripts/combat/action_damage_projection.gd")
const ACTION_DAMAGE_COMPONENT_PROJECTION := preload("res://scripts/combat/action_damage_component_projection.gd")
const ACTION_CADENCE := preload("res://scripts/combat/action_cadence.gd")

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
	var weapon := party.active_weapon_snapshot(member_id)
	var action_stats := party.stats_for_action(member_id, DamageResolver.action_tags_for(attack, weapon))
	if action_stats == null:
		return _unavailable(result, "Missing resolved character stats.")
	if weapon != null and (weapon.member_id != member_id or weapon.revision != action_stats.revision):
		return _unavailable(result, "Active weapon member or revision does not match resolved character stats.")
	return estimate_from_snapshot(attack, action_stats, types, weapon)

static func estimate_from_snapshot(attack: AttackDefinition, action_stats: ResolvedStatSnapshot, types: DamageTypeCatalog, weapon: ActiveWeaponDamageSnapshot = null) -> ActionCombatEstimate:
	var result := ActionCombatEstimate.new()
	if attack == null:
		return _unavailable(result, "Missing attack definition.")
	var validation := attack.validate(types)
	if not validation.is_empty():
		return _unavailable(result, String(validation[0]).trim_prefix("PARTY_FORGE_DAMAGE_ERROR "))
	result.action_id = attack.id
	result.display_name = String(attack.id).replace("_", " ").capitalize()
	if action_stats == null or types == null:
		return _unavailable(result, "Missing resolved character stats.")
	var geometry := ResolvedAttackGeometry.from_snapshot(attack, action_stats)
	if not geometry.ok():
		return _unavailable(result, geometry.error)
	result.range = geometry.range
	result.area_radius = geometry.area_radius
	result.projectile_speed = geometry.projectile_speed
	var cadence := ACTION_CADENCE.resolve(
		attack.cooldown,
		action_stats.value(&"attack_speed", 1.0),
		action_stats.value(&"cooldown_rate", 1.0),
	)
	if not bool(cadence.call("ok")):
		return _unavailable(result, String(cadence.get("error")))
	result.attacks_per_second = float(cadence.get("actions_per_second"))
	if attack.is_healing():
		result.is_healing = true
		var healing_power := action_stats.value(&"healing_power", 1.0)
		if not _is_finite_nonnegative(healing_power):
			return _unavailable(result, "Invalid resolved healing power.")
		result.healing_amount = attack.power * healing_power
		if not _is_finite_nonnegative(result.healing_amount):
			return _unavailable(result, "Invalid derived healing amount.")
		result.estimated_hps = result.healing_amount * result.attacks_per_second
		if not _is_finite_nonnegative(result.estimated_hps):
			return _unavailable(result, "Invalid derived healing per second.")
		result.available = true
		return result
	if weapon != null and weapon.revision != action_stats.revision:
		return _unavailable(result, "Active weapon revision does not match resolved character stats.")
	var projection := ACTION_DAMAGE_COMPONENT_PROJECTION.resolve(attack, weapon)
	var projection_error := String(projection.get("error", ""))
	if not projection_error.is_empty():
		return _unavailable(result, projection_error.trim_prefix("PARTY_FORGE_DAMAGE_ERROR "))
	var archetype_validation := ACTION_ARCHETYPE.validate_player_damage_action(attack)
	if not archetype_validation.is_empty():
		return _unavailable(result, String(archetype_validation[0]).trim_prefix("PARTY_FORGE_DAMAGE_ERROR "))
	result.can_crit = attack.can_crit
	var crit_chance := action_stats.value(&"crit_chance", 0.0) if result.can_crit else 0.0
	if not is_finite(crit_chance):
		return _unavailable(result, "Invalid resolved critical chance.")
	crit_chance = clampf(crit_chance, 0.0, 1.0)
	var crit_multiplier := 1.0
	if result.can_crit:
		crit_multiplier = action_stats.value(&"crit_multiplier", 1.5)
		if not is_finite(crit_multiplier):
			return _unavailable(result, "Invalid resolved critical multiplier.")
		crit_multiplier = maxf(1.0, crit_multiplier)
	var global_multiplier := action_stats.value(&"damage", 1.0)
	var archetype_stat_id := ACTION_ARCHETYPE.stat_id(attack)
	var archetype_multiplier := action_stats.value(archetype_stat_id, 1.0)
	for component: ItemBaseDamageComponent in projection.get("components", []):
		var type_definition := types.definition(component.damage_type_id)
		if type_definition == null:
			return _unavailable(result, "Invalid damage type %s." % component.damage_type_id)
		if not component.validate(types).is_empty():
			return _unavailable(result, "Invalid damage range for %s." % type_definition.display_name)
		var midpoint := component.minimum_damage + (component.maximum_damage - component.minimum_damage) * 0.5
		if not _is_finite_nonnegative(midpoint):
			return _unavailable(result, "Invalid midpoint damage for %s." % type_definition.display_name)
		var normal := ACTION_DAMAGE_PROJECTION.normal_component(midpoint, global_multiplier, archetype_multiplier, action_stats.value(type_definition.offense_stat_id, 1.0))
		if not _is_finite_nonnegative(normal):
			return _unavailable(result, "Invalid derived damage for %s." % type_definition.display_name)
		var critical := normal * crit_multiplier if result.can_crit else normal
		if not _is_finite_nonnegative(critical):
			return _unavailable(result, "Invalid derived critical damage for %s." % type_definition.display_name)
		var average := normal * (1.0 + crit_chance * (crit_multiplier - 1.0))
		if not _is_finite_nonnegative(average):
			return _unavailable(result, "Invalid derived average damage for %s." % type_definition.display_name)
		result.normal_hit += normal
		result.critical_hit += critical
		result.average_hit += average
		if not _is_finite_nonnegative(result.normal_hit):
			return _unavailable(result, "Invalid derived normal hit total.")
		if not _is_finite_nonnegative(result.critical_hit):
			return _unavailable(result, "Invalid derived critical hit total.")
		if not _is_finite_nonnegative(result.average_hit):
			return _unavailable(result, "Invalid derived average hit total.")
		result.component_rows.append({
			"damage_type_id": component.damage_type_id,
			"display_name": type_definition.display_name,
			"normal_hit": normal,
			"critical_hit": critical,
			"average_hit": average,
		})
	result.estimated_dps = result.average_hit * result.attacks_per_second
	if not _is_finite_nonnegative(result.estimated_dps):
		return _unavailable(result, "Invalid derived DPS.")
	result.available = true
	return result

static func _unavailable(result: ActionCombatEstimate, reason: String) -> ActionCombatEstimate:
	result.available = false
	result.unavailable_reason = reason
	return result

static func _is_finite_nonnegative(value: float) -> bool:
	return is_finite(value) and value >= 0.0
