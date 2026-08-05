class_name LoadoutCompatibilityService
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_LOADOUT_COMPATIBILITY_ERROR"

func project(
	profile: ProfileState,
	class_definition: ClassDefinition,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> LoadoutCompatibilityProjection:
	if profile == null:
		return _failure("field=profile reason=must not be null")
	if class_definition == null or class_definition.id.is_empty():
		return _failure("field=class reason=selected authoritative class is missing")
	if equipment == null or foundation == null:
		return _failure("field=catalog reason=equipment and item foundation catalogs are required")
	if profile.profile_id.strip_edges().is_empty():
		return _failure("field=profile_id reason=must not be empty")

	var ownership := _profile_ownership(profile, equipment, foundation)
	if not ownership.ok():
		return _failure("field=profile_items reason=%s" % ownership.error)
	var state := ownership.state
	var registry := state.registry()
	var leader := state.container(&"leader-loadout")
	if leader == null or leader.container_kind != ItemSlotContainer.PROFILE_LEADER_EQUIPMENT:
		return _failure("field=leader_loadout reason=canonical leader equipment container is missing")

	var stash_tabs: Array[ItemSlotContainer] = []
	var stash_documents: Array[Dictionary] = []
	for index: int in profile.stash_tabs.size():
		var stored_document := profile.stash_tabs[index]
		var container_id := StringName(String(stored_document.get("container_id", "")))
		var tab := state.container(container_id)
		if tab == null or tab.container_kind != ItemSlotContainer.PROFILE_STASH_TAB:
			return _failure("field=stash_tabs[%d] reason=stored profile stash tab is unavailable" % index)
		stash_tabs.append(tab)
		stash_documents.append(tab.to_dictionary())
	var state_fingerprint := LoadoutCompatibilityProjection.state_fingerprint_for(
		profile.leader_loadout_class_id,
		class_definition.id,
		registry.to_dictionary(),
		leader.to_dictionary(),
		stash_documents,
	)

	var attributes := _base_core_attributes(class_definition)
	var compatible_loadout: Dictionary = {}
	var compatible: Array[Dictionary] = []
	var incompatible: Array[Dictionary] = []
	for slot: int in leader.occupied_slots():
		var slot_id := EquipmentSlotIndex.slot_for(slot)
		var instance_id := leader.item_id_at(slot)
		var item := registry.item(instance_id) if registry != null else null
		var definition := equipment.definition(item.base_definition_id) if item != null else null
		if slot_id.is_empty() or item == null or definition == null:
			return _failure("field=leader_loadout slot=%d reason=equipped item definition is unavailable" % slot)
		var reasons := EquipmentEligibility.validate_equip(
			definition,
			class_definition,
			slot_id,
			compatible_loadout,
			attributes,
		)
		if reasons.is_empty() and definition.item_type_id == &"quiver":
			var main_hand := compatible_loadout.get(&"main_hand") as EquipmentBaseDefinition
			if main_hand == null:
				reasons.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=quiver requires a compatible main-hand bow" % definition.id)
			elif &"off_hand" not in main_hand.reserved_slot_ids or definition.item_type_id not in main_hand.compatible_offhand_item_types:
				reasons.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=quiver is not permitted by %s" % [definition.id, main_hand.id])
			elif main_hand.weapon_family_id.is_empty() or definition.weapon_family_id != main_hand.weapon_family_id:
				reasons.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=quiver family does not match %s" % [definition.id, main_hand.id])
		var entry := {
			"base_definition_id": String(item.base_definition_id),
			"display_name": definition.display_name,
			"instance_id": instance_id,
			"slot_id": String(slot_id),
			"source_container_id": String(leader.container_id),
			"source_slot": slot,
		}
		if reasons.is_empty():
			compatible.append(entry)
			compatible_loadout[slot_id] = definition
		else:
			entry["reasons"] = Array(reasons)
			incompatible.append(entry)

	var planned: Array[Dictionary] = []
	var overflow: Array[String] = []
	for entry: Dictionary in incompatible:
		var destination := _first_empty_stash_destination(stash_tabs)
		var instance_id := String(entry["instance_id"])
		if destination.is_empty():
			overflow.append(instance_id)
			continue
		var tab_index := int(destination[0])
		var destination_slot := int(destination[1])
		var tab := stash_tabs[tab_index]
		tab._set_item_id(destination_slot, instance_id)
		planned.append({
			"instance_id": instance_id,
			"destination_container_id": String(tab.container_id),
			"destination_slot": destination_slot,
		})
	return LoadoutCompatibilityProjection.success(
		class_definition.id,
		compatible,
		incompatible,
		planned,
		overflow,
		state_fingerprint,
	)

func _profile_ownership(
	profile: ProfileState,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> ItemOwnershipStateDecodeResult:
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	return ItemOwnershipState.decode({
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": containers,
	}, equipment, foundation)

func _base_core_attributes(class_definition: ClassDefinition) -> Dictionary:
	var values := class_definition.stat_base_values()
	var result: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		result[attribute_id] = float(values.get(attribute_id, values.get(String(attribute_id), 0.0)))
	return result

func _first_empty_stash_destination(stash_tabs: Array[ItemSlotContainer]) -> Array[int]:
	for index: int in stash_tabs.size():
		var slot := stash_tabs[index].first_empty_slot()
		if slot >= 0:
			return [index, slot]
	return []

func _failure(detail: String) -> LoadoutCompatibilityProjection:
	return LoadoutCompatibilityProjection.failure("%s %s" % [ERROR_PREFIX, detail])
