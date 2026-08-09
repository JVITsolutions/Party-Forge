class_name EquipmentActivationResolver
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_EQUIPMENT_ACTIVATION_ERROR"

static func resolve(
	member_id: int,
	container_id: StringName,
	state: ItemOwnershipState,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	base_values: Dictionary,
	capabilities: Array[StringName],
	non_equipment_sources: Array[StatModifierSource],
	revision: int,
) -> EquipmentActivationResult:
	var input_error := _validate_inputs(member_id, container_id, state, equipment, foundation, stats, non_equipment_sources)
	if not input_error.is_empty():
		return _failure(member_id, input_error)

	var container := state.container(container_id)
	var registry := state.registry()
	var equipped_ids: Array[String] = []
	for slot_index: int in container.occupied_slots():
		equipped_ids.append(container.item_id_at(slot_index))
	equipped_ids.sort()

	var active_ids: Array[String] = []
	while true:
		var pass_result := _project_and_resolve(
			member_id, container_id, state, active_ids, equipment, foundation, stats,
			base_values, capabilities, non_equipment_sources, revision,
		)
		if not String(pass_result["error"]).is_empty():
			return _failure(member_id, String(pass_result["error"]))
		var raw := pass_result["raw"] as ResolvedStatSnapshot
		var attributes := _attribute_values(raw)
		var changed := false
		for item_id: String in equipped_ids:
			if item_id in active_ids:
				continue
			var item := registry.item(item_id)
			var definition := equipment.definition(item.base_definition_id) if item != null else null
			if definition == null:
				return _failure(member_id, "item=%s reason=equipment definition missing" % item_id)
			if EquipmentEligibility.unmet_attribute_requirements(definition, attributes).is_empty():
				active_ids.append(item_id)
				changed = true
		if not changed:
			break
		active_ids.sort()

	var final_pass := _project_and_resolve(
		member_id, container_id, state, active_ids, equipment, foundation, stats,
		base_values, capabilities, non_equipment_sources, revision,
	)
	if not String(final_pass["error"]).is_empty():
		return _failure(member_id, String(final_pass["error"]))
	var final_raw := final_pass["raw"] as ResolvedStatSnapshot
	var final_attributes := _attribute_values(final_raw)
	var disabled: Dictionary = {}
	for item_id: String in equipped_ids:
		if item_id in active_ids:
			continue
		var item := registry.item(item_id)
		var definition := equipment.definition(item.base_definition_id) if item != null else null
		if definition == null:
			return _failure(member_id, "item=%s reason=equipment definition missing" % item_id)
		var reasons := EquipmentEligibility.unmet_attribute_requirements(definition, final_attributes)
		reasons.sort()
		disabled[item_id] = reasons
	return EquipmentActivationResult.success(
		active_ids,
		disabled,
		final_raw,
		final_pass["source"] as StatModifierSource,
	)

static func _project_and_resolve(
	member_id: int,
	container_id: StringName,
	state: ItemOwnershipState,
	active_ids: Array[String],
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	base_values: Dictionary,
	capabilities: Array[StringName],
	non_equipment_sources: Array[StatModifierSource],
	revision: int,
) -> Dictionary:
	var projection := EquipmentModifierProjector.project(
		member_id, container_id, state, active_ids, equipment, foundation, stats,
	)
	if not projection.ok():
		return {"error": projection.error, "raw": null, "source": null}
	var raw_sources := non_equipment_sources.duplicate()
	raw_sources.append(projection.source)
	var source_errors := StatResolver.validate_sources(stats, raw_sources)
	if not source_errors.is_empty():
		return {"error": source_errors[0], "raw": null, "source": null}
	var raw := StatResolver.resolve(member_id, stats, base_values, capabilities, raw_sources, [], revision)
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		if not is_finite(raw.value(attribute_id, NAN)):
			return {"error": "attribute=%s reason=resolved value is non-finite" % attribute_id, "raw": null, "source": null}
	return {"error": "", "raw": raw, "source": projection.source}

static func _validate_inputs(
	member_id: int,
	container_id: StringName,
	state: ItemOwnershipState,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	non_equipment_sources: Array[StatModifierSource],
) -> String:
	if member_id <= 0:
		return "reason=member id must be positive"
	if container_id.is_empty():
		return "reason=container id is empty"
	if state == null:
		return "reason=ownership state is null"
	if equipment == null:
		return "reason=equipment catalog is null"
	if foundation == null:
		return "reason=item foundation catalog is null"
	if stats == null:
		return "reason=stat catalog is null"
	var state_error := state.validate(equipment, foundation)
	if not state_error.is_empty():
		return "reason=invalid ownership state detail=%s" % state_error
	var container := state.container(container_id)
	if container == null:
		return "reason=equipment container is missing"
	if container.container_kind != ItemSlotContainer.RUN_MEMBER_EQUIPMENT and container.container_kind != ItemSlotContainer.PROFILE_LEADER_EQUIPMENT:
		return "reason=container is not equipment"
	var source_errors := StatResolver.validate_sources(stats, non_equipment_sources)
	if not source_errors.is_empty():
		return source_errors[0]
	return ""

static func _attribute_values(raw: ResolvedStatSnapshot) -> Dictionary:
	var attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		attributes[attribute_id] = raw.value(attribute_id) if raw != null else 0.0
	return attributes

static func _failure(member_id: int, detail: String) -> EquipmentActivationResult:
	return EquipmentActivationResult.failure("%s member=%d detail=%s" % [ERROR_PREFIX, member_id, detail])
