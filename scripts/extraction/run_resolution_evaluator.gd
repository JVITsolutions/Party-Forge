class_name RunResolutionEvaluator
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_RUN_RESOLUTION_ERROR"

static func evaluate(
	candidate: ProfileState,
	source: RunResolutionSource,
	request: RunResolutionRequest,
) -> RunResolutionEvaluation:
	var identity_error := _validate_identity(candidate, source, request)
	if not identity_error.is_empty():
		return RunResolutionEvaluation.create(null, 0, 0, 0, identity_error, RunResolutionEvaluation.FailureCategory.RUN_IDENTITY_MISMATCH, "This no longer matches the saved run. Return to run recovery.", false, false, false)
	var projection := RunExtractionPolicy.project_source(source, candidate, request.ordinary_selections)
	var profile_decode := _profile_ownership(candidate)
	if not profile_decode.ok():
		var ordinary_known := projection != null and (projection.valid or projection.failure_kind == RunExtractionProjection.FailureKind.OVER_CAPACITY)
		return RunResolutionEvaluation.create(projection, 0, projection.selected_item_ids.size() if ordinary_known else 0, 0, _error("field=profile.ownership reason=%s" % profile_decode.error), RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION, "Item ownership could not be verified. Nothing was moved.", false, ordinary_known, false)
	var profile_state := profile_decode.state
	var profile_registry := profile_state.registry()
	var leader_loadout := profile_state.container(&"leader-loadout")
	var stash_tabs: Array[ItemSlotContainer] = []
	for stash_document: Dictionary in candidate.stash_tabs:
		var container := profile_state.container(StringName(String(stash_document["container_id"])))
		if container == null or container.container_kind != ItemSlotContainer.PROFILE_STASH_TAB:
			return RunResolutionEvaluation.create(projection, 0, projection.selected_item_ids.size() if projection.valid else 0, 0, _error("field=profile.stash_tabs reason=stored tab unavailable"), RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION, "Item ownership could not be verified. Nothing was moved.", false, projection.valid, false)
		stash_tabs.append(container)

	var automatic_leader := RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK in candidate.permanent_feature_unlocks
	var displaced_item_ids: Array[String] = []
	if automatic_leader:
		for slot: int in leader_loadout.occupied_slots():
			displaced_item_ids.append(leader_loadout.item_id_at(slot))
	var mandatory := displaced_item_ids.size()
	var available := _empty_stash_slots(stash_tabs)
	if not projection.valid:
		var category := RunResolutionEvaluation.FailureCategory.STALE_SELECTION
		var player_reason := "Review the extraction selection again before resolving the run."
		var ordinary_known := false
		if projection.failure_kind == RunExtractionProjection.FailureKind.OVER_CAPACITY:
			category = RunResolutionEvaluation.FailureCategory.SELECTION_OVER_CAPACITY
			player_reason = "Too many ordinary items are selected for the current extraction capacity. Deselect items and review again."
			ordinary_known = true
		elif projection.failure_kind == RunExtractionProjection.FailureKind.SOURCE_INVALID:
			category = RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION
			player_reason = "Item ownership could not be verified. Nothing was moved."
		return RunResolutionEvaluation.create(projection, mandatory, projection.selected_item_ids.size() if ordinary_known else 0, available, _error("field=extraction reason=%s" % " | ".join(projection.errors)), category, player_reason, true, ordinary_known, true)

	var ordinary := projection.selected_item_ids.size()
	var live_state := source.item_state
	var live_validation := live_state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not live_validation.is_empty():
		return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=source.item_state reason=%s" % live_validation), RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION, "Item ownership could not be verified. Nothing was moved.")
	var live_registry := live_state.registry()
	var leader_equipment := live_state.container(StringName("run-equipment-%03d" % request.leader_member_id))
	if automatic_leader:
		var eligibility_error := _validate_live_leader_loadout(source, live_registry, leader_equipment)
		if not eligibility_error.is_empty():
			return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, eligibility_error, RunResolutionEvaluation.FailureCategory.ELIGIBILITY_INVALID, "The leader's live equipment is no longer eligible. Review the loadout before resolving.")
	if available < mandatory + ordinary:
		var automatic_only := mandatory > available
		var category := RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY if automatic_only else RunResolutionEvaluation.FailureCategory.STASH_REDUCIBLE
		var shortage := mandatory + ordinary - available
		var player_reason := "Automatic leader replacement needs %d stash slots, but %d are available. Deselecting ordinary items cannot fix this." % [mandatory, available] if automatic_only else "Stash space is short: %d required, %d available. Deselect at least %d ordinary item(s) and try again." % [mandatory + ordinary, available, shortage]
		return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=stash reason=insufficient empty slots required=%d available=%d" % [mandatory + ordinary, available]), category, player_reason)

	var next_items: Array[ItemInstance] = []
	for instance_id: String in profile_registry.ids():
		next_items.append(profile_registry.item(instance_id))
	if automatic_leader:
		for slot: int in leader_loadout.occupied_slots(): leader_loadout._clear_slot(slot)
		for instance_id: String in displaced_item_ids:
			var displaced_destination := _first_empty_stash_destination(stash_tabs)
			if displaced_destination.is_empty(): return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=stash reason=insufficient empty slots"), RunResolutionEvaluation.FailureCategory.INTERNAL, "Stash placement changed unexpectedly. Nothing was moved.")
			(stash_tabs[displaced_destination[0]] as ItemSlotContainer)._set_item_id(displaced_destination[1], instance_id)
		for instance_id: String in projection.automatic_item_ids:
			if profile_registry.has(instance_id): return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=item.instance_id reason=already exists in profile %s" % instance_id), RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION, "Item ownership could not be verified. Nothing was moved.")
			var source_slot := _slot_for_item(leader_equipment, instance_id)
			if source_slot < 0: return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=automatic_item reason=leader source missing %s" % instance_id), RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION, "Item ownership could not be verified. Nothing was moved.")
			var item := live_registry.item(instance_id)
			if item == null: return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=source.item_state.registry reason=missing item %s" % instance_id), RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION, "Item ownership could not be verified. Nothing was moved.")
			next_items.append(item)
			leader_loadout._set_item_id(source_slot, instance_id)
	for instance_id: String in projection.selected_item_ids:
		if profile_registry.has(instance_id): return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=item.instance_id reason=already exists in profile %s" % instance_id), RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION, "Item ownership could not be verified. Nothing was moved.")
		var item := live_registry.item(instance_id)
		if item == null: return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=source.item_state.registry reason=missing item %s" % instance_id), RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION, "Item ownership could not be verified. Nothing was moved.")
		var destination := _first_empty_stash_destination(stash_tabs)
		if destination.is_empty(): return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=stash reason=insufficient empty slots"), RunResolutionEvaluation.FailureCategory.INTERNAL, "Stash placement changed unexpectedly. Nothing was moved.")
		next_items.append(item)
		(stash_tabs[destination[0]] as ItemSlotContainer)._set_item_id(destination[1], instance_id)

	var containers: Array[ItemSlotContainer] = [leader_loadout]
	containers.append_array(stash_tabs)
	var resolved_ownership := ItemOwnershipState.create(candidate.profile_id, ItemRegistry.new(next_items), containers)
	var resolved_error := resolved_ownership.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not resolved_error.is_empty(): return RunResolutionEvaluation.create(projection, mandatory, ordinary, available, _error("field=profile.ownership reason=%s" % resolved_error), RunResolutionEvaluation.FailureCategory.OWNERSHIP_VERIFICATION, "Item ownership could not be verified. Nothing was moved.")
	candidate.item_records = resolved_ownership.registry().to_dictionary()
	candidate.leader_loadout = resolved_ownership.container(&"leader-loadout").to_dictionary()
	var resolved_tabs: Array[Dictionary] = []
	for stored_tab: ItemSlotContainer in stash_tabs: resolved_tabs.append(resolved_ownership.container(stored_tab.container_id).to_dictionary())
	candidate.stash_tabs = resolved_tabs
	candidate.leader_loadout_class_id = String(source.leader_class_id)
	candidate.resumable_run = {}
	return RunResolutionEvaluation.create(projection, mandatory, ordinary, available)

static func _validate_identity(candidate: ProfileState, source: RunResolutionSource, request: RunResolutionRequest) -> String:
	if candidate == null or source == null or request == null: return _error("field=identity reason=candidate, source, and request are required")
	if candidate.profile_id != request.profile_id or source.profile_id != request.profile_id: return _error("field=profile_id reason=candidate, source, and request must match")
	if not candidate.resumable_run.has("item_state"): return _error("field=resumable_run reason=strict item run required")
	var durable := ResumableRunItemCodec.decode(candidate.resumable_run, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	if durable == null: return _error("field=resumable_run reason=invalid strict item run")
	if durable.run_id != request.run_id or durable.run_seed != request.run_seed or durable.run_player_id != request.run_player_id or durable.leader_member_id != request.leader_member_id or source.run_id != request.run_id or source.run_seed != request.run_seed or source.run_player_id != request.run_player_id or source.leader_member_id != request.leader_member_id:
		return _error("field=run_identity reason=durable profile, resolution source, and request must match")
	return ""

static func _profile_ownership(profile: ProfileState) -> ItemOwnershipStateDecodeResult:
	var containers: Array = [profile.leader_loadout.duplicate(true)]; containers.append_array(profile.stash_tabs.duplicate(true))
	return ItemOwnershipState.decode({"schema_version": ItemOwnershipState.SCHEMA_VERSION, "owner_id": profile.profile_id, "registry": profile.item_records.duplicate(true), "containers": containers}, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)

static func _validate_live_leader_loadout(source: RunResolutionSource, registry: ItemRegistry, leader_equipment: ItemSlotContainer) -> String:
	var class_definition := GameCatalog.load_defaults().class_by_id(source.leader_class_id)
	if class_definition == null: return _error("field=leader_class reason=authoritative leader class missing")
	if registry == null or leader_equipment == null: return _error("field=leader_loadout reason=live ownership unavailable")
	var loadout: Dictionary = {}
	for slot: int in leader_equipment.occupied_slots():
		var slot_id := EquipmentSlotIndex.slot_for(slot)
		var item := registry.item(leader_equipment.item_id_at(slot))
		var definition := GameCatalog.EQUIPMENT_CATALOG.definition(item.base_definition_id) if item != null else null
		if slot_id.is_empty() or definition == null: return _error("field=leader_loadout reason=unknown live equipment")
		loadout[slot_id] = definition
	var attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS: attributes[attribute_id] = float(source.leader_core_attributes[String(attribute_id)])
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		var definition := loadout.get(slot_id) as EquipmentBaseDefinition
		if definition == null: continue
		var errors := EquipmentEligibility.validate_equip(definition, class_definition, slot_id, loadout, attributes)
		if not errors.is_empty(): return _error("field=leader_loadout reason=ineligible detail=%s" % errors[0])
	var off_hand := loadout.get(&"off_hand") as EquipmentBaseDefinition
	if off_hand != null and off_hand.item_type_id == &"quiver":
		var main_hand := loadout.get(&"main_hand") as EquipmentBaseDefinition
		if main_hand == null: return _error("field=leader_loadout reason=ineligible detail=quiver requires a main-hand bow")
		if &"off_hand" not in main_hand.reserved_slot_ids or off_hand.item_type_id not in main_hand.compatible_offhand_item_types: return _error("field=leader_loadout reason=ineligible detail=quiver is not permitted by main hand")
		if main_hand.weapon_family_id.is_empty() or off_hand.weapon_family_id != main_hand.weapon_family_id: return _error("field=leader_loadout reason=ineligible detail=quiver family does not match main hand")
	return ""

static func _available_stash_slots(profile: ProfileState) -> int:
	if profile == null: return 0
	var decoded := _profile_ownership(profile)
	if not decoded.ok(): return 0
	var tabs: Array[ItemSlotContainer] = []
	for document: Dictionary in profile.stash_tabs:
		var tab := decoded.state.container(StringName(String(document.get("container_id", ""))))
		if tab != null and tab.container_kind == ItemSlotContainer.PROFILE_STASH_TAB: tabs.append(tab)
	return _empty_stash_slots(tabs)

static func _empty_stash_slots(stash_tabs: Array[ItemSlotContainer]) -> int:
	var result := 0
	for tab: ItemSlotContainer in stash_tabs: result += tab.capacity - tab.occupied_slots().size()
	return result
static func _first_empty_stash_destination(stash_tabs: Array[ItemSlotContainer]) -> Array[int]:
	for index: int in stash_tabs.size():
		var slot := stash_tabs[index].first_empty_slot()
		if slot >= 0: return [index, slot]
	return []
static func _slot_for_item(container: ItemSlotContainer, instance_id: String) -> int:
	if container == null: return -1
	for slot: int in container.occupied_slots():
		if container.item_id_at(slot) == instance_id: return slot
	return -1
static func _error(detail: String) -> String: return "%s %s" % [ERROR_PREFIX, detail]
