class_name RunLootRecapProvider
extends RunRecapProvider

func provider_id() -> StringName:
	return &"loot"

func display_order() -> int:
	return 0

func project(snapshot: RunTerminalSnapshot, resolution: RunResolutionResult) -> RunRecapProviderResult:
	if snapshot == null or resolution == null or not resolution.ok():
		return RunRecapProviderResult.failure("accepted terminal loot truth is unavailable")
	var accepted := resolution.accepted_extraction
	var profile := resolution.profile
	if accepted == null or not accepted.valid or profile == null:
		return RunRecapProviderResult.failure("accepted extraction or durable profile is unavailable")
	var source := snapshot.resolution_source
	var source_state := source.item_state if source != null else null
	var source_registry := source_state.registry() if source_state != null else null
	var profile_registry_result := ItemRegistry._decode(profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	var profile_registry := profile_registry_result.value as ItemRegistry if String(profile_registry_result.error).is_empty() else null
	if source == null or source_state == null or source_registry == null or profile_registry == null:
		return RunRecapProviderResult.failure("item presentation truth is unavailable")
	var class_definition := GameCatalog.load_defaults().class_by_id(source.leader_class_id)
	var entries: Array[RunRecapEntryProjection] = []
	for item_id: String in accepted.automatic_item_ids:
		var entry := _entry("Automatic retention", item_id, source_registry, class_definition, _source_detail(source_state, item_id))
		if entry == null: return RunRecapProviderResult.failure("automatic item %s cannot be presented" % item_id)
		entries.append(entry)
	for item_id: String in accepted.selected_item_ids:
		var entry := _entry("Selected extraction", item_id, source_registry, class_definition, _selection_detail(accepted, item_id))
		if entry == null: return RunRecapProviderResult.failure("selected item %s cannot be presented" % item_id)
		entries.append(entry)
	for item_id: String in accepted.lost_item_ids:
		var entry := _entry("Lost", item_id, source_registry, class_definition, _selection_detail(accepted, item_id))
		if entry == null: return RunRecapProviderResult.failure("lost item %s cannot be presented" % item_id)
		entries.append(entry)
	for item_id: String in resolution.protected_displaced_item_ids:
		var entry := _entry("Protected displaced gear", item_id, profile_registry, class_definition, "Recovery Overflow · exact item ID %s" % item_id)
		if entry == null: return RunRecapProviderResult.failure("protected item %s cannot be presented" % item_id)
		entries.append(entry)
	if entries.is_empty():
		entries.append(RunRecapEntryProjection.create("Run loot", "No run-owned items were resolved", "Accepted extraction contained no automatic, selected, lost, or protected item IDs."))
	var summary := "Automatic %d · Selected %d · Lost %d" % [accepted.automatic_item_ids.size(), accepted.selected_item_ids.size(), accepted.lost_item_ids.size()]
	if not resolution.protected_displaced_item_ids.is_empty():
		summary += " · Protected %d" % resolution.protected_displaced_item_ids.size()
	return RunRecapProviderResult.success(RunRecapSectionProjection.create(&"loot", "EXTRACTION TRUTH", RunRecapSectionProjection.SemanticKind.LOOT, entries, summary))

func _entry(label: String, item_id: String, registry: ItemRegistry, class_definition: ClassDefinition, detail: String) -> RunRecapEntryProjection:
	var item := registry.item(item_id) if registry != null else null
	if item == null:
		return null
	var presentation := ItemPresentationProjector.project(item, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, class_definition)
	if presentation.is_empty() or presentation.has("error"):
		return null
	var item_name := String(presentation.get("name", "")).strip_edges()
	if item_name.is_empty():
		return null
	var rarity := String(presentation.get("rarity_name", "")).strip_edges()
	var value := item_name if rarity.is_empty() else "%s · %s" % [item_name, rarity]
	return RunRecapEntryProjection.create(label, value, detail)

func _source_detail(state: ItemOwnershipState, item_id: String) -> String:
	for container: ItemSlotContainer in state.containers():
		for slot: int in container.occupied_slots():
			if container.item_id_at(slot) == item_id:
				return "%s · slot %d · exact item ID %s" % [String(container.container_id), slot, item_id]
	return "Exact item ID %s" % item_id

func _selection_detail(accepted: RunExtractionProjection, item_id: String) -> String:
	for selection: ExtractionSelection in accepted.eligible_items:
		if selection != null and selection.item_id == item_id:
			return "%s · slot %d · exact item ID %s" % [String(selection.expected_source_container_id), selection.expected_source_slot, item_id]
	return "Exact item ID %s" % item_id
