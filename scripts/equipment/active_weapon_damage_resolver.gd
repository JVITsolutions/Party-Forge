class_name ActiveWeaponDamageResolver
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_ACTIVE_WEAPON_DAMAGE_ERROR"

static func resolve(
	member_id: int,
	container: ItemSlotContainer,
	state: ItemOwnershipState,
	active_item_ids: Array[String],
	equipment: EquipmentCatalog,
	revision: int,
) -> Dictionary:
	var input_error := _validate_inputs(member_id, container, state, equipment, revision)
	if not input_error.is_empty():
		return _failure(member_id, input_error)
	var main_hand_slot := EquipmentSlotIndex.index_for(&"main_hand")
	if main_hand_slot < 0:
		return _failure(member_id, "reason=main hand slot is missing")
	var item_id := container.item_id_at(main_hand_slot)
	if item_id.is_empty() or item_id not in active_item_ids:
		return _success(null)
	return _snapshot_for_item(member_id, item_id, state, equipment, revision)

static func _snapshot_for_item(
	member_id: int,
	item_id: String,
	state: ItemOwnershipState,
	equipment: EquipmentCatalog,
	revision: int,
) -> Dictionary:
	var registry := state.registry()
	var item := registry.item(item_id) if registry != null else null
	if item == null:
		return _failure(member_id, "item=%s reason=item is missing from registry" % item_id)
	var base := equipment.definition(item.base_definition_id)
	if base == null:
		return _failure(member_id, "item=%s base=%s reason=equipment definition missing" % [item_id, item.base_definition_id])
	if item.base_damage_components.is_empty():
		return _success(null)
	var components: Array[ItemBaseDamageComponent] = []
	var seen_types: Dictionary = {}
	for index: int in item.base_damage_components.size():
		var component := item.base_damage_components[index]
		if component == null:
			return _failure(member_id, "item=%s base=%s component=%d reason=component is missing" % [item_id, item.base_definition_id, index])
		var component_copy := component.copy()
		var component_error := component_copy.validate(GameCatalog.DAMAGE_TYPES)
		if not component_error.is_empty():
			return _failure(member_id, "item=%s base=%s component=%d type=%s %s" % [item_id, item.base_definition_id, index, component_copy.damage_type_id, component_error])
		if seen_types.has(component_copy.damage_type_id):
			return _failure(member_id, "item=%s base=%s component=%d type=%s reason=duplicate damage type %s" % [item_id, item.base_definition_id, index, component_copy.damage_type_id, component_copy.damage_type_id])
		seen_types[component_copy.damage_type_id] = true
		components.append(component_copy)
	return _success(ActiveWeaponDamageSnapshot.create(
		member_id,
		item_id,
		base.id,
		components,
		revision,
	))

static func _validate_inputs(
	member_id: int,
	container: ItemSlotContainer,
	state: ItemOwnershipState,
	equipment: EquipmentCatalog,
	revision: int,
) -> String:
	if member_id <= 0:
		return "reason=member id must be positive"
	if revision < 0:
		return "reason=revision must be nonnegative"
	if container == null:
		return "reason=equipment container is null"
	if state == null:
		return "reason=ownership state is null"
	if equipment == null:
		return "reason=equipment catalog is null"
	if container.container_kind != ItemSlotContainer.RUN_MEMBER_EQUIPMENT and container.container_kind != ItemSlotContainer.PROFILE_LEADER_EQUIPMENT:
		return "reason=container is not equipment"
	return ""

static func _success(snapshot: ActiveWeaponDamageSnapshot) -> Dictionary:
	return {"error": "", "snapshot": snapshot.copy() if snapshot != null else null}

static func _failure(member_id: int, detail: String) -> Dictionary:
	return {"error": "%s member=%d %s" % [ERROR_PREFIX, member_id, detail], "snapshot": null}
