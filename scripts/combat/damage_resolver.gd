class_name DamageResolver
extends RefCounted

static func action_tags_for(attack: AttackDefinition) -> Array[StringName]:
	var tags: Array[StringName] = []
	if attack != null:
		tags = attack.normalized_action_tags()
		for component: AttackDamageComponent in attack.damage_components:
			if component != null and not component.damage_type_id.is_empty() and component.damage_type_id not in tags:
				tags.append(component.damage_type_id)
	tags.sort()
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

	var tags := action_tags_for(attack)
	var crit_chance := source.stat_value(&"crit_chance", 0.0) if attack.can_crit else 0.0
	var crit_roll := rng.roll(crit_chance)
	var critical := bool(crit_roll["success"])
	var crit_multiplier := maxf(1.0, source.stat_value(&"crit_multiplier", 1.5))
	var prepared: Array[PreparedDamageComponent] = []
	for component: AttackDamageComponent in attack.damage_components:
		var type_definition := types.definition(component.damage_type_id)
		var global_scaled := component.base_amount * source.stat_value(&"damage", 1.0)
		var typed_scaled := global_scaled * source.stat_value(type_definition.offense_stat_id, 1.0)
		var post_crit := typed_scaled * crit_multiplier if critical else typed_scaled
		if not is_finite(post_crit): return _invalid_packet("attack=%s source=%s type=%s reason=non-finite prepared amount" % [attack.id, source.combatant_id, component.damage_type_id], source, attack.id)
		prepared.append(PreparedDamageComponent.new(component.damage_type_id, component.base_amount, global_scaled, typed_scaled, post_crit))
	return DamagePacket.create(source, attack.id, tags, attack.can_crit, critical, float(crit_roll["draw"]), crit_multiplier, source.stat_value(&"life_steal", 0.0), prepared)

static func resolve(packet: DamagePacket, target: CombatantAdapter, rng: CombatRng, types: DamageTypeCatalog) -> DamageResult:
	var result := _base_result(packet, target)
	var invalid_reason := _resolution_error(packet, target, rng, types)
	if not invalid_reason.is_empty():
		result.error_reason = invalid_reason
		if packet == null or packet.valid: push_error(invalid_reason)
		return result
	result.valid = true
	result.dodge_chance = target.stat_value(&"dodge_chance", 0.0)
	var dodge := rng.roll(result.dodge_chance)
	result.dodge_draw = float(dodge["draw"])
	result.dodged = bool(dodge["success"])
	if result.dodged: return result

	for prepared: PreparedDamageComponent in packet.components:
		var definition := types.definition(prepared.damage_type_id)
		var defense := target.stat_value(definition.defense_stat_id, 0.0)
		var mitigated := prepared.post_crit
		match definition.mitigation_rule:
			DamageTypeDefinition.MitigationRule.ARMOR:
				mitigated = prepared.post_crit * 100.0 / (100.0 + maxf(0.0, defense))
			DamageTypeDefinition.MitigationRule.RESISTANCE:
				mitigated = prepared.post_crit * (1.0 - defense)
			_:
				result.valid = false
				result.error_reason = _unsupported_mitigation_rule_error(packet, target, prepared.damage_type_id, definition.mitigation_rule)
				push_error(result.error_reason)
				return result
		mitigated = maxf(0.0, mitigated)
		result.total_post_mitigation += mitigated
		result.component_breakdowns.append({
			"damage_type_id": prepared.damage_type_id,
			"authored_amount": prepared.authored_amount,
			"global_scaled": prepared.global_scaled,
			"typed_scaled": prepared.typed_scaled,
			"post_crit": prepared.post_crit,
			"defense_stat_id": definition.defense_stat_id,
			"defense_value": defense,
			"post_mitigation": mitigated,
		})

	result.incoming_multiplier = target.incoming_damage_multiplier(packet)
	result.damage_before_block = result.total_post_mitigation * result.incoming_multiplier
	result.incoming_prevented = result.total_post_mitigation - result.damage_before_block
	result.block_chance = target.stat_value(&"block_chance", 0.0)
	var block := rng.roll(result.block_chance)
	result.block_draw = float(block["draw"])
	result.blocked = bool(block["success"])
	result.block_effectiveness = target.stat_value(&"block_effectiveness", 0.5) if result.blocked else 0.0
	result.final_damage = maxf(0.0, result.damage_before_block * (1.0 - result.block_effectiveness))
	result.block_prevented = result.damage_before_block - result.final_damage
	result.actual_health_removed = target.health.apply_damage(result.final_damage)
	result.life_steal_rate = packet.life_steal_rate
	if packet.source_is_available_for_life_steal() and result.actual_health_removed > 0.0:
		result.life_steal_restored = packet.source.health.heal(result.actual_health_removed * packet.life_steal_rate)
	return result

static func _base_result(packet: DamagePacket, target: CombatantAdapter) -> DamageResult:
	var result := DamageResult.new()
	if packet != null:
		result.source_id = packet.source_id
		result.attack_id = packet.attack_id
		result.action_tags = packet.action_tags
		result.can_crit = packet.can_crit
		result.critical = packet.critical
		result.crit_draw = packet.crit_draw
		result.crit_multiplier = packet.crit_multiplier
	if target != null: result.target_id = target.combatant_id
	return result

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
