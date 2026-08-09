class_name EquipmentModifierProjector
extends RefCounted

const SOURCE_TYPE := &"equipment"
const SOURCE_LABEL := "Equipment"

static func project(
	member_id: int,
	container_id: StringName,
	state: ItemOwnershipState,
	active_item_ids: Array[String],
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
) -> EquipmentModifierProjection:
	var input_error := _validate_inputs(member_id, container_id, state, equipment, foundation, stats)
	if not input_error.is_empty():
		return EquipmentModifierProjection.failure(input_error)

	var container := state.container(container_id)
	var registry := state.registry()
	var active_lookup: Dictionary = {}
	var equipped_counts: Dictionary = {}
	for slot_index: int in container.occupied_slots():
		var equipped_id := container.item_id_at(slot_index)
		equipped_counts[equipped_id] = int(equipped_counts.get(equipped_id, 0)) + 1
	for item_id: String in active_item_ids:
		if item_id.strip_edges().is_empty():
			return EquipmentModifierProjection.failure(_error(member_id, "<none>", item_id, "<none>", "<none>", "<none>", "active item id is empty"))
		if active_lookup.has(item_id):
			return EquipmentModifierProjection.failure(_error(member_id, "<none>", item_id, "<none>", "<none>", "<none>", "duplicate active item id"))
		var equipped_count := int(equipped_counts.get(item_id, 0))
		if equipped_count == 0:
			return EquipmentModifierProjection.failure(_error(member_id, "<none>", item_id, "<none>", "<none>", "<none>", "active item is not equipped in container %s" % container_id))
		if equipped_count != 1:
			return EquipmentModifierProjection.failure(_error(member_id, "<none>", item_id, "<none>", "<none>", "<none>", "active item is equipped %d times in container %s" % [equipped_count, container_id]))
		active_lookup[item_id] = true

	var modifiers: Array[StatModifier] = []
	var modifier_ids: Dictionary = {}
	for slot_index: int in container.occupied_slots():
		var item_id := container.item_id_at(slot_index)
		if not active_lookup.has(item_id):
			continue
		var slot_id := EquipmentSlotIndex.slot_for(slot_index)
		if slot_id.is_empty():
			return EquipmentModifierProjection.failure(_error(member_id, str(slot_index), item_id, "<none>", "<none>", "<none>", "unknown equipment slot"))
		var item := registry.item(item_id)
		if item == null:
			return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, "<none>", "<none>", "<none>", "item is missing from registry"))
		if item.instance_id != item_id or item.instance_id.strip_edges().is_empty():
			return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, "<none>", "<none>", "<none>", "item identity does not match container reference"))
		var base := equipment.definition(item.base_definition_id)
		if base == null:
			return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, "<none>", "<none>", "<none>", "unknown equipment base %s" % item.base_definition_id))
		if base.id.is_empty() or base.display_name.strip_edges().is_empty():
			return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, "<none>", "<none>", "<none>", "equipment base identity or label is empty"))

		for affix_index: int in item.affixes.size():
			var affix := item.affixes[affix_index]
			if affix == null:
				return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, "<null>", str(affix_index), "<none>", "affix is null"))
			var affix_id := String(affix.definition_id)
			if affix.definition_id.is_empty():
				return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(affix_index), "<none>", "affix identity is empty"))
			var definition := foundation.affix(affix.definition_id)
			if definition == null:
				return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, "<none>", "<none>", "unknown affix"))
			if definition.id.is_empty() or definition.display_name.strip_edges().is_empty():
				return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, "<none>", "<none>", "affix definition identity or label is empty"))
			if affix.affix_kind != definition.affix_kind:
				return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, "<none>", "<none>", "affix kind does not match definition"))
			var tier := definition.tier_definition(affix.tier)
			if tier == null:
				return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, "<none>", "<none>", "unknown affix tier %d" % affix.tier))
			if affix.rolls.size() != definition.effects.size():
				return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, "<none>", "<none>", "roll count does not match affix definition"))

			for roll_index: int in affix.rolls.size():
				var roll := affix.rolls[roll_index]
				if roll == null:
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), "<null>", "roll is null"))
				var stat_id := String(roll.stat_id)
				if roll.stat_id.is_empty() or stats.definition(roll.stat_id) == null:
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id, "unknown stat"))
				if roll.operation not in ItemAffixDefinition.VALID_OPERATIONS:
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id, "unsupported operation %d" % roll.operation))
				if not is_finite(roll.value):
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id, "non-finite value"))
				var policy_error := EquipmentBaseDefinition.monotonic_core_modifier_error(roll.stat_id, roll.operation, roll.value)
				if not policy_error.is_empty():
					return EquipmentModifierProjection.failure(_error(
						member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id,
						"base=%s operation=%s value=%s %s" % [
							base.id,
							EquipmentBaseDefinition.modifier_operation_name(roll.operation),
							str(roll.value),
							policy_error,
						],
					))
				var tag_error := _validate_tags(roll.required_tags, foundation.known_item_tags)
				if not tag_error.is_empty():
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id, tag_error))
				var effect := definition.effects[roll_index]
				if effect == null:
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id, "affix effect is null"))
				if roll.stat_id != effect.stat_id or roll.operation != effect.operation or roll.required_tags != effect.required_tags:
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id, "roll does not match affix definition"))
				var bounds := tier.roll_bounds(roll_index)
				if not is_finite(bounds.x) or not is_finite(bounds.y) or bounds.x > bounds.y or roll.value < bounds.x or roll.value > bounds.y:
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id, "roll value is outside issued bounds"))

				var modifier_id := StringName("equip_m%d_s%s_i%s_a%d_%s_r%d" % [member_id, slot_id, item.instance_id, affix_index, affix.definition_id, roll_index])
				if modifier_id.is_empty():
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id, "modifier identity is empty"))
				if modifier_ids.has(modifier_id):
					return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, affix_id, str(roll_index), stat_id, "duplicate modifier identity %s" % modifier_id))
				modifier_ids[modifier_id] = true
				modifiers.append(StatModifier.create(
					roll.stat_id,
					roll.operation,
					roll.value,
					modifier_id,
					_label(base, affix, foundation),
					roll.required_tags,
				))

		var item_error := ItemInstanceCodec.validate(item, equipment, foundation)
		if not item_error.is_empty():
			return EquipmentModifierProjection.failure(_error(member_id, String(slot_id), item_id, "<none>", "<none>", "<none>", item_error))

	var source_id := StringName("equipment_member_%d" % member_id)
	var source := StatModifierSource.create(source_id, SOURCE_TYPE, SOURCE_LABEL, member_id, modifiers)
	var source_errors := StatResolver.validate_sources(stats, [source])
	if not source_errors.is_empty():
		return EquipmentModifierProjection.failure(_error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", source_errors[0]))
	return EquipmentModifierProjection.success(source)

static func _validate_inputs(
	member_id: int,
	container_id: StringName,
	state: ItemOwnershipState,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
) -> String:
	if member_id <= 0:
		return _error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", "member id must be positive")
	if container_id.is_empty():
		return _error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", "container id is empty")
	if state == null:
		return _error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", "ownership state is null")
	if equipment == null:
		return _error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", "equipment catalog is null")
	if foundation == null:
		return _error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", "item foundation catalog is null")
	if stats == null:
		return _error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", "stat catalog is null")
	var container := state.container(container_id)
	if container == null:
		return _error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", "unknown equipment container %s" % container_id)
	if container.container_kind not in [ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, ItemSlotContainer.RUN_MEMBER_EQUIPMENT]:
		return _error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", "container %s is not equipment" % container_id)
	if state.registry() == null:
		return _error(member_id, "<none>", "<none>", "<none>", "<none>", "<none>", "item registry is null")
	return ""

static func _validate_tags(tags: Array[StringName], known_tags: Array[StringName]) -> String:
	var seen: Dictionary = {}
	for tag: StringName in tags:
		if tag.is_empty():
			return "empty required tag"
		if seen.has(tag):
			return "duplicate required tag %s" % tag
		if tag not in known_tags:
			return "unknown required tag %s" % tag
		seen[tag] = true
	return ""

static func _label(base: EquipmentBaseDefinition, affix: ItemAffixInstance, foundation: ItemFoundationCatalog) -> String:
	var definition := foundation.affix(affix.definition_id)
	var affix_name := definition.display_name if definition != null else String(affix.definition_id).replace("_", " ").capitalize()
	return "%s — %s" % [base.display_name, affix_name]

static func _error(
	member_id: int,
	slot: String,
	item: String,
	affix: String,
	roll: String,
	stat: String,
	reason: String,
) -> String:
	return "PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=%d slot=%s item=%s affix=%s roll=%s stat=%s reason=%s" % [
		member_id,
		slot if not slot.is_empty() else "<none>",
		item if not item.is_empty() else "<none>",
		affix if not affix.is_empty() else "<none>",
		roll if not roll.is_empty() else "<none>",
		stat if not stat.is_empty() else "<none>",
		reason,
	]
