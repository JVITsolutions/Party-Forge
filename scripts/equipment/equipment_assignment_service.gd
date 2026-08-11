class_name EquipmentAssignmentService
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_EQUIPMENT_ASSIGNMENT_ERROR"
const INVENTORY_ID := &"run-inventory"

func validate_member_loadout(
	state: ItemOwnershipState,
	member_id: int,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	class_definition: ClassDefinition,
) -> String:
	if state == null or equipment == null or foundation == null or member_id <= 0:
		return "%s reason=invalid request" % ERROR_PREFIX
	if class_definition == null:
		return "%s member=%d reason=class missing" % [ERROR_PREFIX, member_id]
	var state_error := state.validate(equipment, foundation)
	if not state_error.is_empty():
		return "%s reason=invalid ownership state detail=%s" % [ERROR_PREFIX, state_error]
	var loadout_result := _loadout_for(state, _equipment_id(member_id), equipment)
	var loadout_error := String(loadout_result["error"])
	if not loadout_error.is_empty():
		return "%s member=%d reason=%s" % [ERROR_PREFIX, member_id, loadout_error]
	var eligibility_error := _validate_complete_loadout(loadout_result["loadout"] as Dictionary, class_definition)
	if not eligibility_error.is_empty():
		return "%s member=%d reason=ineligible detail=%s" % [ERROR_PREFIX, member_id, eligibility_error]
	return ""

func preview(
	state: ItemOwnershipState,
	member_id: int,
	item_id: String,
	slot_id: StringName,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	class_definition: ClassDefinition = null,
	_attributes: Dictionary = {},
) -> EquipmentAssignmentResult:
	if state == null or equipment == null or foundation == null or member_id <= 0 or item_id.strip_edges().is_empty():
		return _failure("reason=invalid request")
	if class_definition == null:
		return _failure("member=%d reason=class missing" % member_id)
	var state_error := state.validate(equipment, foundation)
	if not state_error.is_empty():
		return _failure("reason=invalid ownership state detail=%s" % state_error)
	var registry := state.registry()
	var item := registry.item(item_id) if registry != null else null
	if item == null:
		return _failure("item=%s reason=unknown item" % item_id)
	var item_definition := equipment.definition(item.base_definition_id)
	if item_definition == null:
		return _failure("item=%s reason=unknown base definition %s" % [item_id, item.base_definition_id])

	var equipment_id := _equipment_id(member_id)
	var member_equipment := state.container(equipment_id)
	var inventory := state.container(INVENTORY_ID)
	if member_equipment == null:
		return _failure("member=%d reason=equipment container missing" % member_id)
	if inventory == null:
		return _failure("reason=run inventory missing")
	var source := _locate_item(state, item_id)
	if source.is_empty():
		return _failure("item=%s reason=item location missing" % item_id)
	var source_container_id := StringName(String(source["container_id"]))
	var source_slot := int(source["slot"])
	if source_container_id != INVENTORY_ID and source_container_id != equipment_id:
		return _failure("member=%d item=%s reason=item belongs to another container" % [member_id, item_id])

	var destination_container_id: StringName
	var destination_slot := -1
	if slot_id.is_empty():
		if source_container_id != equipment_id:
			return _failure("member=%d item=%s reason=item is not equipped" % [member_id, item_id])
		destination_container_id = INVENTORY_ID
		destination_slot = inventory.first_empty_slot()
		if destination_slot < 0:
			return _failure("item=%s reason=run inventory full" % item_id)
	else:
		destination_container_id = equipment_id
		destination_slot = EquipmentSlotIndex.index_for(slot_id)
		if destination_slot < 0:
			return _failure("slot=%s reason=invalid slot" % slot_id)
		if source_container_id == equipment_id and source_slot == destination_slot:
			return _failure("member=%d item=%s slot=%s reason=item already equipped" % [member_id, item_id, slot_id])
	return _preview_endpoints(
		state,
		member_id,
		item_id,
		slot_id,
		source_container_id,
		source_slot,
		destination_container_id,
		destination_slot,
		equipment,
		foundation,
		class_definition,
	)

func preview_exact(
	state: ItemOwnershipState,
	member_id: int,
	item_id: String,
	source_container_id: StringName,
	source_slot: int,
	destination_container_id: StringName,
	destination_slot: int,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	class_definition: ClassDefinition = null,
	_attributes: Dictionary = {},
) -> EquipmentAssignmentResult:
	if state == null or equipment == null or foundation == null or member_id <= 0 or item_id.strip_edges().is_empty():
		return _failure("reason=invalid exact request")
	if class_definition == null:
		return _failure("member=%d reason=class missing" % member_id)
	var state_error := state.validate(equipment, foundation)
	if not state_error.is_empty():
		return _failure("reason=invalid ownership state detail=%s" % state_error)
	var equipment_id := _equipment_id(member_id)
	var allowed_endpoints: Array[StringName] = [INVENTORY_ID, equipment_id]
	if source_container_id not in allowed_endpoints or destination_container_id not in allowed_endpoints:
		return _failure("member=%d item=%s reason=endpoint belongs outside member ownership" % [member_id, item_id])
	if source_container_id != equipment_id and destination_container_id != equipment_id:
		return _failure("member=%d item=%s reason=exact assignment must cross equipment" % [member_id, item_id])
	var slot_id := EquipmentSlotIndex.slot_for(destination_slot) if destination_container_id == equipment_id else &""
	return _preview_endpoints(
		state,
		member_id,
		item_id,
		slot_id,
		source_container_id,
		source_slot,
		destination_container_id,
		destination_slot,
		equipment,
		foundation,
		class_definition,
	)

func _preview_endpoints(
	state: ItemOwnershipState,
	member_id: int,
	item_id: String,
	slot_id: StringName,
	source_container_id: StringName,
	source_slot: int,
	destination_container_id: StringName,
	destination_slot: int,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	class_definition: ClassDefinition,
) -> EquipmentAssignmentResult:
	var equipment_id := _equipment_id(member_id)
	var storage_ids: Array[StringName] = [INVENTORY_ID]
	var planned := EquipmentOwnershipTransitionPlanner.preview(
		state,
		item_id,
		source_container_id,
		source_slot,
		destination_container_id,
		destination_slot,
		equipment_id,
		storage_ids,
		equipment,
		foundation,
	)
	if not planned.ok():
		return _failure("member=%d item=%s slot=%s reason=ownership transition failed detail=%s" % [member_id, item_id, slot_id, planned.error])
	var candidate := planned.state()

	var loadout_result := _loadout_for(candidate, equipment_id, equipment)
	if not String(loadout_result["error"]).is_empty():
		return _failure("member=%d reason=%s" % [member_id, String(loadout_result["error"])])
	var loadout := loadout_result["loadout"] as Dictionary
	var eligibility_error := _validate_complete_loadout(loadout, class_definition)
	if not eligibility_error.is_empty():
		return _failure("member=%d item=%s slot=%s reason=ineligible detail=%s" % [member_id, item_id, slot_id, eligibility_error])
	var candidate_error := candidate.validate(equipment, foundation)
	if not candidate_error.is_empty():
		return _failure("reason=invalid candidate detail=%s" % candidate_error)
	return EquipmentAssignmentResult.success(candidate, planned.newly_equipped_item_ids())

func _loadout_for(state: ItemOwnershipState, equipment_id: StringName, equipment: EquipmentCatalog) -> Dictionary:
	var container := state.container(equipment_id)
	var registry := state.registry()
	if container == null or registry == null:
		return {"loadout": {}, "error": "equipment state unavailable"}
	var loadout: Dictionary = {}
	for slot: int in container.occupied_slots():
		var item := registry.item(container.item_id_at(slot))
		if item == null:
			return {"loadout": {}, "error": "equipped instance missing"}
		var definition := equipment.definition(item.base_definition_id)
		if definition == null:
			return {"loadout": {}, "error": "equipped base definition missing"}
		loadout[EquipmentSlotIndex.slot_for(slot)] = definition
	return {"loadout": loadout, "error": ""}

func _validate_complete_loadout(loadout: Dictionary, class_definition: ClassDefinition) -> String:
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		var definition := loadout.get(slot_id) as EquipmentBaseDefinition
		if definition == null:
			continue
		var errors := EquipmentEligibility.validate_structure(definition, class_definition, slot_id, loadout)
		if not errors.is_empty():
			return errors[0]
	var off_hand := loadout.get(&"off_hand") as EquipmentBaseDefinition
	if off_hand != null and off_hand.item_type_id == &"quiver":
		var main_hand := loadout.get(&"main_hand") as EquipmentBaseDefinition
		if main_hand == null:
			return "quiver %s requires a main-hand bow" % off_hand.id
		if &"off_hand" not in main_hand.reserved_slot_ids or off_hand.item_type_id not in main_hand.compatible_offhand_item_types:
			return "quiver %s is not permitted by %s" % [off_hand.id, main_hand.id]
		if main_hand.weapon_family_id.is_empty() or off_hand.weapon_family_id != main_hand.weapon_family_id:
			return "quiver %s family does not match %s" % [off_hand.id, main_hand.id]
	return ""

func _locate_item(state: ItemOwnershipState, item_id: String) -> Dictionary:
	for container: ItemSlotContainer in state.containers():
		for slot: int in container.occupied_slots():
			if container.item_id_at(slot) == item_id:
				return {"container_id": String(container.container_id), "slot": slot}
	return {}

func _equipment_id(member_id: int) -> StringName:
	return StringName("run-equipment-%03d" % member_id)

func _failure(detail: String) -> EquipmentAssignmentResult:
	return EquipmentAssignmentResult.failure("%s %s" % [ERROR_PREFIX, detail])
