class_name EquipmentAssignmentService
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_EQUIPMENT_ASSIGNMENT_ERROR"
const INVENTORY_ID := &"run-inventory"

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

	var candidate := state.copy()
	if slot_id.is_empty():
		if source_container_id != equipment_id:
			return _failure("member=%d item=%s reason=item is not equipped" % [member_id, item_id])
		var inventory_slot := inventory.first_empty_slot()
		if inventory_slot < 0:
			return _failure("item=%s reason=run inventory full" % item_id)
		candidate._clear_slot(source_container_id, source_slot)
		candidate._set_slot(INVENTORY_ID, inventory_slot, item_id)
	else:
		var destination_slot := EquipmentSlotIndex.index_for(slot_id)
		if destination_slot < 0:
			return _failure("slot=%s reason=invalid slot" % slot_id)
		var destination_item_id := member_equipment.item_id_at(destination_slot)
		if not destination_item_id.is_empty() and destination_item_id != item_id:
			return _failure("member=%d slot=%s reason=destination occupied" % [member_id, slot_id])
		if source_container_id == equipment_id and source_slot == destination_slot:
			return _failure("member=%d item=%s slot=%s reason=item already equipped" % [member_id, item_id, slot_id])
		candidate._clear_slot(source_container_id, source_slot)
		candidate._set_slot(equipment_id, destination_slot, item_id)

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
	return EquipmentAssignmentResult.success(candidate)

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
