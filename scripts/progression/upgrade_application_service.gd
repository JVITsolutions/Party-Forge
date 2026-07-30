class_name UpgradeApplicationService
extends RefCounted

static func eligible_member_ids(definition: UpgradeDefinition, party: PartyManager) -> Array[int]:
	var result: Array[int] = []
	if definition == null or party == null:
		return result
	for member: PartyMemberState in party.members:
		if definition.is_member_eligible(member):
			result.append(member.member_id)
	return result

static func eligibility_reason(definition: UpgradeDefinition, party: PartyManager, member_id: int) -> String:
	if definition == null:
		return "Upgrade is unavailable."
	if party == null:
		return "Party is unavailable."
	var member := party.member_by_id(member_id)
	if member == null:
		return "Member is no longer available."
	if not definition.allowed_class_ids.is_empty() and member.class_definition.id not in definition.allowed_class_ids:
		return "Class is not eligible."
	for tag: StringName in definition.required_all_tags:
		if tag not in member.capability_tags:
			return "Requires %s." % String(tag).capitalize()
	if not definition.required_any_tags.is_empty() and not definition.required_any_tags.any(func(tag: StringName) -> bool: return tag in member.capability_tags):
		return "Requires one matching eligibility tag."
	for tag: StringName in definition.excluded_tags:
		if tag in member.capability_tags:
			return "Excluded by %s." % String(tag).capitalize()
	return ""

static func validate_application(definition: UpgradeDefinition, party: PartyManager, member_id: int = 0) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append(_error(&"<missing>", member_id, "upgrade is unavailable"))
		return errors
	if party == null:
		errors.append(_error(definition.id, member_id, "party is unavailable"))
		return errors
	var owner_member_id := 0
	if definition.is_single_recipient():
		var reason := eligibility_reason(definition, party, member_id)
		if not reason.is_empty():
			errors.append(_error(definition.id, member_id, reason.trim_suffix(".").to_lower()))
			return errors
		owner_member_id = member_id
	elif eligible_member_ids(definition, party).is_empty():
		errors.append(_error(definition.id, member_id, "no eligible party member"))
		return errors
	var current_rank := party.upgrade_rank(definition.id, owner_member_id)
	if current_rank >= definition.max_rank:
		errors.append(_error(definition.id, member_id, "maximum rank reached"))
		return errors
	var source := source_for_rank(definition, current_rank + 1, owner_member_id)
	if source.modifiers.size() != definition.effects.size():
		errors.append(_error(definition.id, member_id, "unsupported upgrade effect"))
	for reason: String in StatResolver.validate_sources(PartyManager.STAT_CATALOG, [source]):
		errors.append(_error(definition.id, member_id, reason))
	for modifier: StatModifier in source.modifiers:
		if modifier.operation not in [StatModifier.Operation.FLAT, StatModifier.Operation.INCREASED, StatModifier.Operation.REDUCED, StatModifier.Operation.MORE, StatModifier.Operation.LESS]:
			errors.append(_error(definition.id, member_id, "unsupported operation %d" % modifier.operation))
		if not is_finite(modifier.value):
			errors.append(_error(definition.id, member_id, "modifier value must be finite"))
	return errors

static func apply(upgrade_id: StringName, catalog: GameCatalog, party: PartyManager, member_id: int = 0) -> bool:
	if catalog == null:
		push_error(_error(upgrade_id, member_id, "catalog is unavailable"))
		return false
	var definition := catalog.upgrade_by_id(upgrade_id)
	if definition == null:
		push_error(_error(upgrade_id, member_id, "unknown upgrade id"))
		return false
	var errors := validate_application(definition, party, member_id)
	if not errors.is_empty():
		for error: String in errors:
			push_error(error)
		return false
	var owner_member_id := member_id if definition.is_single_recipient() else 0
	var next_rank := party.upgrade_rank(definition.id, owner_member_id) + 1
	var source := source_for_rank(definition, next_rank, owner_member_id)
	if definition.is_single_recipient():
		return party._commit_personal_upgrade(definition, member_id, next_rank, source)
	return party._commit_party_upgrade(definition, next_rank, source)

static func source_for_rank(definition: UpgradeDefinition, rank: int, owner_member_id: int) -> StatModifierSource:
	var source_id := StringName("upgrade:%s:member:%d" % [definition.id, owner_member_id]) if owner_member_id > 0 else StringName("upgrade:%s:party" % definition.id)
	var label := "%s Rank %d" % [definition.display_name, rank]
	var modifiers: Array[StatModifier] = []
	for effect_definition: UpgradeEffectDefinition in definition.effects:
		var effect := effect_definition as StatUpgradeEffect
		if effect == null:
			continue
		var cumulative_value := 0.0
		for applied_rank: int in range(1, rank + 1):
			cumulative_value += effect.value_for_rank(applied_rank)
		var modifier := StatModifier.create(effect.stat_id, effect.operation, cumulative_value, source_id, label)
		modifier.required_capability_tags = effect.required_capability_tags.duplicate()
		modifier.excluded_capability_tags = effect.excluded_capability_tags.duplicate()
		modifier.required_action_tags = effect.required_action_tags.duplicate()
		modifier.excluded_action_tags = effect.excluded_action_tags.duplicate()
		modifiers.append(modifier)
	return StatModifierSource.create(source_id, &"authored_upgrade", label, owner_member_id, modifiers)

static func preview_values(definition: UpgradeDefinition, party: PartyManager, member_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if definition == null or party == null:
		return result
	var member := party.member_by_id(member_id)
	if member == null or not definition.is_member_eligible(member):
		return result
	var owner_member_id := member_id if definition.is_single_recipient() else 0
	if not validate_application(definition, party, owner_member_id).is_empty():
		return result
	var next_rank := party.upgrade_rank(definition.id, owner_member_id) + 1
	var prospective := source_for_rank(definition, next_rank, owner_member_id)
	var current_sources := party._sources_for(member)
	var prospective_sources: Array[StatModifierSource] = []
	for source: StatModifierSource in current_sources:
		if source.id != prospective.id:
			prospective_sources.append(source)
	prospective_sources.append(prospective)
	for index: int in definition.effects.size():
		var effect := definition.effects[index] as StatUpgradeEffect
		if effect == null or index >= prospective.modifiers.size():
			continue
		var action_tags := effect.required_action_tags.duplicate()
		if not prospective.modifiers[index].applies_to(member.capability_tags, action_tags):
			continue
		var before := StatResolver.resolve(member_id, PartyManager.STAT_CATALOG, member.class_definition.stat_base_values(), member.capability_tags, current_sources, action_tags, -1)
		var after := StatResolver.resolve(member_id, PartyManager.STAT_CATALOG, member.class_definition.stat_base_values(), member.capability_tags, prospective_sources, action_tags, -1)
		result.append({
			"stat_id": effect.stat_id,
			"before": before.value(effect.stat_id),
			"after": after.value(effect.stat_id),
			"operation": effect.operation,
			"rank": next_rank,
			"value": prospective.modifiers[index].value,
		})
	return result

static func _error(upgrade_id: StringName, member_id: int, reason: String) -> String:
	return "PARTY_FORGE_UPGRADE_APPLICATION_ERROR id=%s member=%d reason=%s" % [upgrade_id, member_id, reason]
