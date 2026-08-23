class_name DamageResolver
extends RefCounted

const ACTION_ARCHETYPE := preload("res://scripts/combat/action_archetype.gd")
const ACTION_DAMAGE_PROJECTION := preload("res://scripts/combat/action_damage_projection.gd")
const ACTION_DAMAGE_COMPONENT_PROJECTION := preload("res://scripts/combat/action_damage_component_projection.gd")
const DAMAGE_DEFENSE_SNAPSHOT := preload("res://scripts/combat/damage_defense_snapshot.gd")
const MULTI_CRIT_ROLL := preload("res://scripts/combat/multi_crit_roll.gd")

static func action_tags_for(attack: AttackDefinition, weapon: ActiveWeaponDamageSnapshot = null) -> Array[StringName]:
	var tags: Array[StringName] = []
	if attack != null:
		tags = attack.normalized_action_tags()
		for authored_component: AttackDamageComponent in attack.damage_components:
			if authored_component != null and not authored_component.damage_type_id.is_empty() and authored_component.damage_type_id not in tags:
				tags.append(authored_component.damage_type_id)
		var projection := ACTION_DAMAGE_COMPONENT_PROJECTION.resolve(attack, weapon)
		if String(projection.get("error", "")).is_empty():
			for component: ItemBaseDamageComponent in projection.get("components", []):
				if component != null and not component.damage_type_id.is_empty() and component.damage_type_id not in tags:
					tags.append(component.damage_type_id)
	tags.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return tags

static func prepare(attack: AttackDefinition, source: CombatantAdapter, rng: CombatRng, types: DamageTypeCatalog) -> DamagePacket:
	if attack == null: return _invalid_packet("attack=<null> source=<unknown> reason=missing attack", source)
	if source == null: return _invalid_packet("attack=%s source=<null> reason=missing source provider" % attack.id, null, attack.id)
	if source.combatant_id.is_empty(): return _invalid_packet("attack=%s source=<empty> reason=missing combatant identity" % attack.id, source, attack.id)
	if rng == null: return _invalid_packet("attack=%s source=%s reason=missing combat RNG" % [attack.id, source.combatant_id], source, attack.id)
	if types == null: return _invalid_packet("attack=%s source=%s reason=missing damage catalog" % [attack.id, source.combatant_id], source, attack.id)
	var validation := attack.validate(types)
	if not validation.is_empty(): return _invalid_packet(String(validation[0]).trim_prefix("PARTY_FORGE_DAMAGE_ERROR "), source, attack.id)
	if attack.is_healing(): return _invalid_packet("attack=%s source=%s reason=healing cannot create damage packet" % [attack.id, source.combatant_id], source, attack.id)
	var weapon := source.weapon_snapshot
	if attack.damage_source == AttackDefinition.DamageSource.ACTIVE_WEAPON and weapon != null:
		if source.stats == null or weapon.revision != source.stats.revision:
			return _invalid_packet("attack=%s source=%s reason=active weapon revision does not match action stats" % [attack.id, source.combatant_id], source, attack.id)
		var source_member_id := _party_member_id(source.combatant_id)
		if source_member_id > 0 and weapon.member_id != source_member_id:
			return _invalid_packet("attack=%s source=%s reason=active weapon member does not match source" % [attack.id, source.combatant_id], source, attack.id)
	var projection := ACTION_DAMAGE_COMPONENT_PROJECTION.resolve(attack, weapon)
	var projection_error := String(projection.get("error", ""))
	if not projection_error.is_empty():
		return _invalid_packet(projection_error.trim_prefix("PARTY_FORGE_DAMAGE_ERROR "), source, attack.id)
	var projected_components: Array[ItemBaseDamageComponent] = []
	for component: ItemBaseDamageComponent in projection.get("components", []):
		if component == null:
			return _invalid_packet("attack=%s source=%s type=<null> reason=null projected component" % [attack.id, source.combatant_id], source, attack.id)
		var component_error := component.validate(types)
		if not component_error.is_empty():
			return _invalid_packet("attack=%s source=%s type=%s reason=%s" % [attack.id, source.combatant_id, component.damage_type_id, component_error.trim_prefix("PARTY_FORGE_ITEM_BASE_DAMAGE_ERROR ")], source, attack.id)
		projected_components.append(component)

	var tags := action_tags_for(attack, weapon)
	var crit_chance := source.stat_value(&"crit_chance", 0.0) if attack.can_crit else 0.0
	var crit_roll: MULTI_CRIT_ROLL = MULTI_CRIT_ROLL.create(crit_chance, rng) as MULTI_CRIT_ROLL
	if not crit_roll.valid:
		return _invalid_packet("attack=%s source=%s reason=critical chance must be finite" % [attack.id, source.combatant_id], source, attack.id)
	var critical: bool = bool(crit_roll.call("primary_critical"))
	var crit_multiplier := maxf(1.0, source.stat_value(&"crit_multiplier", 1.5))
	var global_multiplier := source.stat_value(&"damage", 1.0)
	var archetype_stat_id := ACTION_ARCHETYPE.stat_id(attack)
	var archetype_multiplier := source.stat_value(archetype_stat_id, 1.0)
	var prepared: Array[PreparedDamageComponent] = []
	for component: ItemBaseDamageComponent in projected_components:
		var type_definition := types.definition(component.damage_type_id)
		var amount := component.minimum_damage
		if component.minimum_damage != component.maximum_damage:
			amount = lerpf(component.minimum_damage, component.maximum_damage, rng.unit())
		var global_scaled := amount * global_multiplier
		var typed_scaled := ACTION_DAMAGE_PROJECTION.normal_component(amount, global_multiplier, archetype_multiplier, source.stat_value(type_definition.offense_stat_id, 1.0))
		var post_crit := typed_scaled * crit_multiplier if critical else typed_scaled
		if not is_finite(post_crit): return _invalid_packet("attack=%s source=%s type=%s reason=non-finite prepared amount" % [attack.id, source.combatant_id, component.damage_type_id], source, attack.id)
		prepared.append(PreparedDamageComponent.new(component.damage_type_id, amount, global_scaled, typed_scaled, post_crit))
	return DamagePacket.create(source, attack.id, tags, attack.can_crit, critical, crit_roll.fractional_draw, crit_multiplier, source.stat_value(&"life_steal", 0.0), prepared, crit_roll)

static func _party_member_id(combatant_id: StringName) -> int:
	var text := String(combatant_id)
	if not text.begins_with("party:"):
		return 0
	var suffix := text.trim_prefix("party:")
	return suffix.to_int() if suffix.is_valid_int() else 0

static func resolve(packet: DamagePacket, target: CombatantAdapter, rng: CombatRng, types: DamageTypeCatalog) -> DamageResult:
	var result := _base_result(packet, target)
	var invalid_reason := _resolution_error(packet, target, rng, types)
	if not invalid_reason.is_empty():
		result.error_reason = invalid_reason
		if packet == null or packet.valid: push_error(invalid_reason)
		return result
	var snapshot: DAMAGE_DEFENSE_SNAPSHOT = capture_defense(packet, target, types)
	if snapshot == null or not snapshot.valid:
		result.error_reason = snapshot.error_reason if snapshot != null else "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing defense snapshot" % [packet.attack_id, packet.source_id, target.combatant_id]
		return result
	var roll: MULTI_CRIT_ROLL = packet.multi_crit_roll
	var first_critical := roll != null and not roll.critical_flags.is_empty() and roll.critical_flags[0]
	return resolve_instance(packet, 0, first_critical, snapshot, target, rng, types, true, true)

static func capture_defense(packet: DamagePacket, target: CombatantAdapter, types: DamageTypeCatalog) -> DAMAGE_DEFENSE_SNAPSHOT:
	var invalid_reason := _capture_error(packet, target, types)
	if not invalid_reason.is_empty():
		if packet == null or packet.valid: push_error(invalid_reason)
		return DAMAGE_DEFENSE_SNAPSHOT.invalid(invalid_reason) as DAMAGE_DEFENSE_SNAPSHOT
	var type_defenses: Dictionary = {}
	for prepared: PreparedDamageComponent in packet.components:
		if type_defenses.has(prepared.damage_type_id):
			continue
		var definition := types.definition(prepared.damage_type_id)
		type_defenses[prepared.damage_type_id] = {
			"defense_stat_id": definition.defense_stat_id,
			"defense_value": target.stat_value(definition.defense_stat_id, 0.0),
			"mitigation_rule": definition.mitigation_rule,
		}
	var snapshot: DAMAGE_DEFENSE_SNAPSHOT = DAMAGE_DEFENSE_SNAPSHOT.create(
		packet,
		target.combatant_id,
		target.team_id,
		target.stat_value(&"dodge_chance", 0.0),
		type_defenses,
		target.incoming_damage_multiplier(packet),
		target.stat_value(&"block_chance", 0.0),
		target.stat_value(&"block_effectiveness", 0.5)
	) as DAMAGE_DEFENSE_SNAPSHOT
	if snapshot == null:
		var missing_reason := "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing defense snapshot" % [packet.attack_id, packet.source_id, target.combatant_id]
		push_error(missing_reason)
		return DAMAGE_DEFENSE_SNAPSHOT.invalid(missing_reason) as DAMAGE_DEFENSE_SNAPSHOT
	if not snapshot.valid:
		var contextual_reason := _snapshot_context_error(packet, target, snapshot.error_reason)
		push_error(contextual_reason)
		return DAMAGE_DEFENSE_SNAPSHOT.invalid(contextual_reason) as DAMAGE_DEFENSE_SNAPSHOT
	return snapshot

static func resolve_instance(
	packet: DamagePacket,
	instance_index: int,
	critical: bool,
	snapshot: DAMAGE_DEFENSE_SNAPSHOT,
	target: CombatantAdapter,
	rng: CombatRng,
	types: DamageTypeCatalog,
	apply_health: bool,
	allow_life_steal: bool
) -> DamageResult:
	var result := _base_result(packet, target)
	result.instance_index = instance_index
	result.critical = critical
	var invalid_reason := _instance_resolution_error(packet, instance_index, critical, snapshot, target, rng, types, apply_health, allow_life_steal)
	if not invalid_reason.is_empty():
		result.error_reason = invalid_reason
		if packet == null or packet.valid: push_error(invalid_reason)
		return result
	result.health_before = target.health.current_health
	result.target_was_alive = target.available and not target.health.is_dead and not target.health.is_downed and result.health_before > 0.0
	result.overkill_only = not result.target_was_alive
	var calculation := _calculate_instance(packet, instance_index, critical, snapshot, result.health_before, result.target_was_alive, result.overkill_only, apply_health, allow_life_steal)
	var calculation_error := String(calculation.get("error", ""))
	if not calculation_error.is_empty():
		result.error_reason = calculation_error
		push_error(calculation_error)
		return result
	result.valid = true
	result.dodge_chance = snapshot.dodge_chance
	var dodge := rng.roll(result.dodge_chance)
	result.dodge_draw = float(dodge["draw"])
	result.dodged = bool(dodge["success"])
	if result.dodged: return result

	result.component_breakdowns.assign(calculation["component_breakdowns"])
	result.total_post_mitigation = float(calculation["total_post_mitigation"])
	result.incoming_multiplier = snapshot.incoming_multiplier
	result.damage_before_block = float(calculation["damage_before_block"])
	result.incoming_prevented = float(calculation["incoming_prevented"])
	result.block_chance = snapshot.block_chance
	var block := rng.roll(result.block_chance)
	result.block_draw = float(block["draw"])
	result.blocked = bool(block["success"])
	result.block_effectiveness = snapshot.block_effectiveness if result.blocked else 0.0
	result.final_damage = float(calculation["blocked_damage"] if result.blocked else calculation["unblocked_damage"])
	result.block_prevented = float(calculation["blocked_prevented"] if result.blocked else calculation["unblocked_prevented"])
	if apply_health and result.target_was_alive:
		result.actual_health_removed = target.health.apply_damage(result.final_damage)
	result.killing_blow = result.target_was_alive and result.actual_health_removed > 0.0 and (target.health.is_dead or target.health.is_downed or target.health.current_health <= 0.0)
	if result.final_damage > 0.0:
		if result.overkill_only:
			result.excess_damage = result.final_damage
		elif apply_health:
			result.excess_damage = maxf(0.0, result.final_damage - result.actual_health_removed)
		else:
			result.excess_damage = maxf(0.0, result.final_damage - result.health_before)
	result.proc_eligible = result.target_was_alive and result.final_damage > 0.0 and (not apply_health or result.actual_health_removed > 0.0)
	result.life_steal_rate = packet.life_steal_rate
	if allow_life_steal and packet.source_is_available_for_life_steal() and result.actual_health_removed > 0.0:
		var life_steal_amount := result.actual_health_removed * packet.life_steal_rate
		result.life_steal_restored = packet.source.health.heal(life_steal_amount)
	return result

static func _calculate_instance(
	packet: DamagePacket,
	instance_index: int,
	critical: bool,
	snapshot: DAMAGE_DEFENSE_SNAPSHOT,
	health_before: float,
	target_was_alive: bool,
	overkill_only: bool,
	apply_health: bool,
	allow_life_steal: bool
) -> Dictionary:
	var component_breakdowns: Array[Dictionary] = []
	var total_post_mitigation := 0.0
	var frozen_defenses := snapshot.type_defenses
	for prepared: PreparedDamageComponent in packet.components:
		var defense_row := frozen_defenses[prepared.damage_type_id] as Dictionary
		var defense := float(defense_row["defense_value"])
		var mitigation_rule := int(defense_row["mitigation_rule"])
		var post_crit := prepared.typed_scaled * packet.crit_multiplier if critical else prepared.typed_scaled
		if not _finite_nonnegative(post_crit):
			return {"error": _arithmetic_error(packet, snapshot, instance_index, "critical", prepared.damage_type_id, "derived critical amount must be finite and nonnegative")}
		var mitigated := post_crit
		match mitigation_rule:
			DamageTypeDefinition.MitigationRule.ARMOR:
				var armor_denominator := 100.0 + maxf(0.0, defense)
				var armor_factor := 100.0 / armor_denominator
				if not _finite_nonnegative(armor_factor):
					return {"error": _arithmetic_error(packet, snapshot, instance_index, "mitigation", prepared.damage_type_id, "armor factor must be finite and nonnegative")}
				mitigated = post_crit * armor_factor
			DamageTypeDefinition.MitigationRule.RESISTANCE:
				var resistance_factor := 1.0 - defense
				if not is_finite(resistance_factor):
					return {"error": _arithmetic_error(packet, snapshot, instance_index, "mitigation", prepared.damage_type_id, "resistance factor must be finite")}
				mitigated = post_crit * resistance_factor
			_:
				return {"error": _arithmetic_error(packet, snapshot, instance_index, "mitigation", prepared.damage_type_id, "unsupported mitigation rule")}
		if not is_finite(mitigated):
			return {"error": _arithmetic_error(packet, snapshot, instance_index, "mitigation", prepared.damage_type_id, "post-mitigation amount must be finite")}
		mitigated = maxf(0.0, mitigated)
		var accumulated := total_post_mitigation + mitigated
		if not _finite_nonnegative(accumulated):
			return {"error": _arithmetic_error(packet, snapshot, instance_index, "accumulation", prepared.damage_type_id, "post-mitigation total must be finite and nonnegative")}
		total_post_mitigation = accumulated
		component_breakdowns.append({
			"damage_type_id": prepared.damage_type_id,
			"authored_amount": prepared.authored_amount,
			"global_scaled": prepared.global_scaled,
			"typed_scaled": prepared.typed_scaled,
			"post_crit": post_crit,
			"defense_stat_id": StringName(defense_row["defense_stat_id"]),
			"defense_value": defense,
			"post_mitigation": mitigated,
		})

	var damage_before_block := total_post_mitigation * snapshot.incoming_multiplier
	if not _finite_nonnegative(damage_before_block):
		return {"error": _arithmetic_error(packet, snapshot, instance_index, "incoming", &"", "incoming-scaled amount must be finite and nonnegative")}
	var incoming_prevented := total_post_mitigation - damage_before_block
	if not is_finite(incoming_prevented):
		return {"error": _arithmetic_error(packet, snapshot, instance_index, "incoming", &"", "incoming prevention evidence must be finite")}
	var unblocked_damage := damage_before_block
	var blocked_raw := damage_before_block * (1.0 - snapshot.block_effectiveness)
	if not is_finite(blocked_raw):
		return {"error": _arithmetic_error(packet, snapshot, instance_index, "block", &"", "blocked amount must be finite")}
	var blocked_damage := maxf(0.0, blocked_raw)
	if not _finite_nonnegative(blocked_damage):
		return {"error": _arithmetic_error(packet, snapshot, instance_index, "block", &"", "final blocked amount must be finite and nonnegative")}
	var unblocked_prevented := damage_before_block - unblocked_damage
	var blocked_prevented := damage_before_block - blocked_damage
	if not is_finite(unblocked_prevented) or not is_finite(blocked_prevented):
		return {"error": _arithmetic_error(packet, snapshot, instance_index, "block", &"", "block prevention evidence must be finite")}

	for possible_damage: float in [unblocked_damage, blocked_damage]:
		var possible_excess := _prospective_excess(possible_damage, health_before, overkill_only)
		if not _finite_nonnegative(possible_excess):
			return {"error": _arithmetic_error(packet, snapshot, instance_index, "excess", &"", "excess amount must be finite and nonnegative")}
		if allow_life_steal and apply_health and target_was_alive and packet.source_is_available_for_life_steal():
			var possible_removed := minf(possible_damage, health_before)
			var possible_life_steal := possible_removed * packet.life_steal_rate
			if not _finite_nonnegative(possible_life_steal):
				return {"error": _arithmetic_error(packet, snapshot, instance_index, "life_steal", &"", "life-steal amount must be finite and nonnegative")}

	return {
		"error": "",
		"component_breakdowns": component_breakdowns,
		"total_post_mitigation": total_post_mitigation,
		"damage_before_block": damage_before_block,
		"incoming_prevented": incoming_prevented,
		"unblocked_damage": unblocked_damage,
		"blocked_damage": blocked_damage,
		"unblocked_prevented": unblocked_prevented,
		"blocked_prevented": blocked_prevented,
	}

static func _prospective_excess(final_damage: float, health_before: float, overkill_only: bool) -> float:
	if final_damage <= 0.0:
		return 0.0
	if overkill_only:
		return final_damage
	return maxf(0.0, final_damage - health_before)

static func _finite_nonnegative(value: float) -> bool:
	return is_finite(value) and value >= 0.0

static func _valid_draw_evidence(value: float) -> bool:
	return is_finite(value) and (value == -1.0 or (value >= 0.0 and value < 1.0))

static func _arithmetic_error(packet: DamagePacket, snapshot: DAMAGE_DEFENSE_SNAPSHOT, instance_index: int, stage: String, type_id: StringName, reason: String) -> String:
	var type_context := " type=%s" % type_id if not type_id.is_empty() else ""
	return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d stage=%s%s reason=%s" % [packet.attack_id, packet.source_id, snapshot.target_id, instance_index, stage, type_context, reason]

static func _base_result(packet: DamagePacket, target: CombatantAdapter) -> DamageResult:
	var result := DamageResult.new()
	if packet != null:
		result.source_id = packet.source_id
		result.attack_id = packet.attack_id
		result.action_tags = packet.action_tags
		result.can_crit = packet.can_crit
		result.critical = packet.critical
		if _valid_draw_evidence(packet.crit_draw):
			result.crit_draw = packet.crit_draw
		if _finite_nonnegative(packet.crit_multiplier):
			result.crit_multiplier = packet.crit_multiplier
	if target != null: result.target_id = target.combatant_id
	return result

static func _capture_error(packet: DamagePacket, target: CombatantAdapter, types: DamageTypeCatalog) -> String:
	if packet == null: return "PARTY_FORGE_DAMAGE_ERROR attack=<null> source=<null> target=<unknown> reason=missing packet"
	if not packet.valid: return packet.error_reason
	if target == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<null> reason=missing target provider" % [packet.attack_id, packet.source_id]
	if target.combatant_id.is_empty(): return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<empty> reason=missing combatant identity" % [packet.attack_id, packet.source_id]
	if not target.available or target.health == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=target unavailable" % [packet.attack_id, packet.source_id, target.combatant_id]
	if packet.source_team_id == target.team_id: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=team-invalid target" % [packet.attack_id, packet.source_id, target.combatant_id]
	if types == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing damage catalog" % [packet.attack_id, packet.source_id, target.combatant_id]
	for component: PreparedDamageComponent in packet.components:
		var definition := types.definition(component.damage_type_id)
		if definition == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s type=%s reason=unknown runtime type" % [packet.attack_id, packet.source_id, target.combatant_id, component.damage_type_id]
		if definition.mitigation_rule not in [DamageTypeDefinition.MitigationRule.ARMOR, DamageTypeDefinition.MitigationRule.RESISTANCE]: return _unsupported_mitigation_rule_error(packet, target, component.damage_type_id, definition.mitigation_rule)
		if not is_finite(component.typed_scaled) or component.typed_scaled < 0.0: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s type=%s reason=invalid runtime amount" % [packet.attack_id, packet.source_id, target.combatant_id, component.damage_type_id]
	return ""

static func _snapshot_context_error(packet: DamagePacket, target: CombatantAdapter, reason: String) -> String:
	var detail := reason.trim_prefix("PARTY_FORGE_DAMAGE_ERROR ")
	return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s snapshot={%s}" % [packet.attack_id, packet.source_id, target.combatant_id, detail]

static func _instance_resolution_error(
	packet: DamagePacket,
	instance_index: int,
	critical: bool,
	snapshot: DAMAGE_DEFENSE_SNAPSHOT,
	target: CombatantAdapter,
	rng: CombatRng,
	types: DamageTypeCatalog,
	apply_health: bool,
	allow_life_steal: bool
) -> String:
	if packet == null: return "PARTY_FORGE_DAMAGE_ERROR attack=<null> source=<null> target=<unknown> reason=missing packet"
	if not packet.valid: return packet.error_reason
	if snapshot == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<unknown> instance=%d reason=missing defense snapshot" % [packet.attack_id, packet.source_id, instance_index]
	if not snapshot.valid:
		return snapshot.error_reason if not snapshot.error_reason.is_empty() else "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<unknown> instance=%d reason=invalid defense snapshot" % [packet.attack_id, packet.source_id, instance_index]
	if not snapshot.matches_packet(packet):
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d packet=%d snapshot_packet=%d reason=snapshot packet mismatch" % [packet.attack_id, packet.source_id, snapshot.target_id, instance_index, packet.get_instance_id(), snapshot.packet_instance_id]
	if target == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<null> instance=%d reason=missing target provider" % [packet.attack_id, packet.source_id, instance_index]
	if target.combatant_id.is_empty(): return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<empty> instance=%d reason=missing combatant identity" % [packet.attack_id, packet.source_id, instance_index]
	if target.health == null or (apply_health and not target.available): return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d reason=target unavailable" % [packet.attack_id, packet.source_id, target.combatant_id, instance_index]
	if not _finite_nonnegative(target.health.current_health): return _arithmetic_error(packet, snapshot, instance_index, "health", &"", "target health must be finite and nonnegative")
	if snapshot.target_id != target.combatant_id or snapshot.target_team_id != target.team_id:
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s snapshot_target=%s instance=%d reason=defense snapshot target mismatch" % [packet.attack_id, packet.source_id, target.combatant_id, snapshot.target_id, instance_index]
	if packet.source_team_id == snapshot.target_team_id: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d reason=team-invalid target" % [packet.attack_id, packet.source_id, target.combatant_id, instance_index]
	if rng == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d reason=missing combat RNG" % [packet.attack_id, packet.source_id, target.combatant_id, instance_index]
	if types == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d reason=missing damage catalog" % [packet.attack_id, packet.source_id, target.combatant_id, instance_index]
	if not _valid_draw_evidence(packet.crit_draw): return _arithmetic_error(packet, snapshot, instance_index, "critical", &"", "critical draw must be -1 or finite in [0,1)")
	if not _finite_nonnegative(packet.crit_multiplier): return _arithmetic_error(packet, snapshot, instance_index, "critical", &"", "critical multiplier must be finite and nonnegative")
	if not _finite_nonnegative(packet.life_steal_rate): return _arithmetic_error(packet, snapshot, instance_index, "life_steal", &"", "life-steal rate must be finite and nonnegative")
	if allow_life_steal and packet.source_is_available_for_life_steal():
		if not _finite_nonnegative(packet.source.health.current_health) or not _finite_nonnegative(packet.source.health.max_health):
			return _arithmetic_error(packet, snapshot, instance_index, "life_steal", &"", "source health must be finite and nonnegative")
	var roll: MULTI_CRIT_ROLL = packet.multi_crit_roll
	var flags: Array[bool] = roll.critical_flags if roll != null else [] as Array[bool]
	if instance_index < 0 or instance_index >= flags.size():
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d processed=%d reason=instance index out of range" % [packet.attack_id, packet.source_id, target.combatant_id, instance_index, flags.size()]
	if flags[instance_index] != critical:
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d reason=critical flag does not match prepared roll" % [packet.attack_id, packet.source_id, target.combatant_id, instance_index]
	var frozen_defenses := snapshot.type_defenses
	for component: PreparedDamageComponent in packet.components:
		if not frozen_defenses.has(component.damage_type_id) or not frozen_defenses[component.damage_type_id] is Dictionary:
			return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s type=%s instance=%d reason=missing frozen type defense" % [packet.attack_id, packet.source_id, target.combatant_id, component.damage_type_id, instance_index]
		if not _finite_nonnegative(component.authored_amount) or not _finite_nonnegative(component.global_scaled):
			return _arithmetic_error(packet, snapshot, instance_index, "component", component.damage_type_id, "component evidence must be finite and nonnegative")
		if not is_finite(component.typed_scaled) or component.typed_scaled < 0.0:
			return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s type=%s instance=%d reason=invalid runtime amount" % [packet.attack_id, packet.source_id, target.combatant_id, component.damage_type_id, instance_index]
		var post_crit := component.typed_scaled * packet.crit_multiplier if critical else component.typed_scaled
		if not is_finite(post_crit) or post_crit < 0.0:
			return _arithmetic_error(packet, snapshot, instance_index, "critical", component.damage_type_id, "derived critical amount must be finite and nonnegative")
	return ""

static func _resolution_error(packet: DamagePacket, target: CombatantAdapter, rng: CombatRng, types: DamageTypeCatalog) -> String:
	if packet == null: return "PARTY_FORGE_DAMAGE_ERROR attack=<null> source=<null> target=<unknown> reason=missing packet"
	if not packet.valid: return packet.error_reason
	if target == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<null> reason=missing target provider" % [packet.attack_id, packet.source_id]
	if target.combatant_id.is_empty(): return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<empty> reason=missing combatant identity" % [packet.attack_id, packet.source_id]
	if not target.available or target.health == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=target unavailable" % [packet.attack_id, packet.source_id, target.combatant_id]
	if packet.source_team_id == target.team_id: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=team-invalid target" % [packet.attack_id, packet.source_id, target.combatant_id]
	if rng == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing combat RNG" % [packet.attack_id, packet.source_id, target.combatant_id]
	if types == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing damage catalog" % [packet.attack_id, packet.source_id, target.combatant_id]
	for component: PreparedDamageComponent in packet.components:
		var definition := types.definition(component.damage_type_id)
		if definition == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s type=%s reason=unknown runtime type" % [packet.attack_id, packet.source_id, target.combatant_id, component.damage_type_id]
		if definition.mitigation_rule not in [DamageTypeDefinition.MitigationRule.ARMOR, DamageTypeDefinition.MitigationRule.RESISTANCE]: return _unsupported_mitigation_rule_error(packet, target, component.damage_type_id, definition.mitigation_rule)
		if not is_finite(component.post_crit) or component.post_crit < 0.0: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s type=%s reason=invalid runtime amount" % [packet.attack_id, packet.source_id, target.combatant_id, component.damage_type_id]
	return ""

static func _unsupported_mitigation_rule_error(packet: DamagePacket, target: CombatantAdapter, type_id: StringName, rule: int) -> String:
	return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s type=%s rule=%d reason=unsupported mitigation rule" % [packet.attack_id, packet.source_id, target.combatant_id, type_id, rule]

static func _invalid_packet(reason: String, source: CombatantAdapter = null, attack_id: StringName = &"") -> DamagePacket:
	var message := "PARTY_FORGE_DAMAGE_ERROR %s" % reason
	push_error(message)
	return DamagePacket.invalid(message, source, attack_id)
