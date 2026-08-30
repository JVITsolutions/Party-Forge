class_name TerminalExtractionViewModel
extends RefCounted

func build(policy: RunExtractionProjection, source: RunResolutionSource, profile: ProfileState) -> TerminalExtractionProjection:
	if policy == null or source == null or profile == null:
		return TerminalExtractionProjection.create([], [], 0, [], [], [], "Extraction information is unavailable.", false)
	if profile.profile_id != source.profile_id:
		return TerminalExtractionProjection.create([], [], policy.capacity, [], [], [], "The run and profile no longer match. Retry resolution.", false)
	if not policy.valid:
		return TerminalExtractionProjection.create([], [], policy.capacity, [], [], [], "Some run items changed. Review the refreshed extraction choices.", false)
	var state := source.item_state
	var registry := state.registry() if state != null else null
	if state == null or registry == null:
		return TerminalExtractionProjection.create([], [], policy.capacity, [], [], [], "Run items are unavailable. Retry resolution.", false)
	var selected_set := _set_from_ids(policy.selected_item_ids)
	var lost_set := _set_from_ids(policy.lost_item_ids)
	var automatic: Array[TerminalExtractionItemProjection] = []
	var eligible: Array[TerminalExtractionItemProjection] = []
	var seen: Dictionary = {}
	for item_id: String in policy.automatic_item_ids:
		if seen.has(item_id): return _duplicate_failure(policy.capacity)
		seen[item_id] = true
		var item_projection := _project_item(item_id, null, true, false, false, source, state, registry)
		if item_projection == null: return _item_failure(policy.capacity, item_id)
		automatic.append(item_projection)
	for selection: ExtractionSelection in policy.eligible_items:
		if selection == null or seen.has(selection.item_id): return _duplicate_failure(policy.capacity)
		seen[selection.item_id] = true
		var projected := _project_item(selection.item_id, selection, false, selected_set.has(selection.item_id), lost_set.has(selection.item_id), source, state, registry)
		if projected == null: return _item_failure(policy.capacity, selection.item_id)
		eligible.append(projected)
	return TerminalExtractionProjection.create(automatic, eligible, policy.capacity, policy.selected_item_ids, policy.lost_item_ids, [], "", true)

func _project_item(
	item_id: String,
	selection: ExtractionSelection,
	automatic: bool,
	selected: bool,
	lost: bool,
	source: RunResolutionSource,
	state: ItemOwnershipState,
	registry: ItemRegistry,
) -> TerminalExtractionItemProjection:
	var item := registry.item(item_id)
	if item == null:
		return null
	var class_definition := GameCatalog.load_defaults().class_by_id(source.leader_class_id)
	var detail := ItemPresentationProjector.project(item, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, class_definition)
	if detail.is_empty() or detail.has("error"):
		return null
	var container: ItemSlotContainer
	var source_slot := -1
	if selection != null:
		container = state.container(selection.expected_source_container_id)
		source_slot = selection.expected_source_slot
		if container == null or container.item_id_at(source_slot) != item_id:
			return null
	else:
		for candidate: ItemSlotContainer in state.containers():
			for occupied_slot: int in candidate.occupied_slots():
				if candidate.item_id_at(occupied_slot) == item_id:
					container = candidate
					source_slot = occupied_slot
					break
			if container != null:
				break
	if container == null:
		return null
	var owner_label := _owner_label(container, source)
	var container_label := _container_label(container, source)
	var member_id := _member_id_from_container(container.container_id)
	var class_label := _member_class_label(member_id, source)
	var comparisons := _comparisons_for(detail, source, state, registry, class_definition)
	return TerminalExtractionItemProjection.create_with_source(item_id, String(detail.get("name", item_id)), String(detail.get("rarity_name", "Unknown")), StringName(detail.get("rarity_id", &"")), owner_label, container_label, automatic, selected, lost, detail, comparisons, member_id, class_label, container.container_id, source_slot)

func _comparisons_for(detail: Dictionary, source: RunResolutionSource, state: ItemOwnershipState, registry: ItemRegistry, class_definition: ClassDefinition) -> Array[Dictionary]:
	var leader := state.container(StringName("run-equipment-%03d" % source.leader_member_id))
	if leader == null:
		return []
	var slots: Array[Dictionary] = []
	var records: Dictionary = {}
	for slot: int in leader.occupied_slots():
		var equipped_id := leader.item_id_at(slot)
		var equipped := registry.item(equipped_id)
		if equipped == null:
			continue
		var equipped_detail := ItemPresentationProjector.project(equipped, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, class_definition)
		if equipped_detail.is_empty() or equipped_detail.has("error"):
			continue
		records[equipped_id] = equipped_detail
		slots.append({"slot_id": String(EquipmentSlotIndex.slot_for(slot)), "instance_id": equipped_id})
	return ItemComparisonResolver.resolve(detail, slots, records)

func _owner_label(container: ItemSlotContainer, source: RunResolutionSource) -> String:
	if container.container_kind == ItemSlotContainer.RUN_INVENTORY:
		return "Run Inventory"
	var member_id := _member_id_from_container(container.container_id)
	var class_label := _member_class_label(member_id, source)
	if not class_label.is_empty():
		return "%s · Member %d" % [class_label, member_id]
	return "Party Member %d" % member_id

func _container_label(container: ItemSlotContainer, source: RunResolutionSource) -> String:
	if container.container_kind == ItemSlotContainer.RUN_INVENTORY:
		return "Run Inventory"
	var member_id := _member_id_from_container(container.container_id)
	return "Member %d Equipment" % member_id if member_id > 0 else "Run Equipment"

func _member_class_label(member_id: int, source: RunResolutionSource) -> String:
	for row: Dictionary in source.party_members:
		if int(row.get("member_id", 0)) == member_id:
			var definition := GameCatalog.load_defaults().class_by_id(StringName(row.get("class_id", &"")))
			return definition.display_name if definition != null else String(row.get("class_id", "Unknown")).capitalize()
	return ""

func _member_id_from_container(container_id: StringName) -> int:
	var value := String(container_id)
	return int(value.trim_prefix("run-equipment-")) if value.begins_with("run-equipment-") else 0

func _set_from_ids(ids: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for item_id: String in ids: result[item_id] = true
	return result

func _duplicate_failure(capacity: int) -> TerminalExtractionProjection:
	return TerminalExtractionProjection.create([], [], capacity, [], [], [], "Duplicate run item identity prevents a safe extraction choice.", false)

func _item_failure(capacity: int, _item_id: String) -> TerminalExtractionProjection:
	return TerminalExtractionProjection.create([], [], capacity, [], [], [], "An item could not be presented safely. Retry resolution.", false)
