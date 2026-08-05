class_name LoadoutTransitionService
extends RefCounted

const OPERATION := "loadout_transition"
const ERROR_PREFIX := "PARTY_FORGE_LOADOUT_TRANSITION_ERROR"

var _mutations: ProfileMutationService
var _compatibility: LoadoutCompatibilityService
var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _classes: GameCatalog

func _init(
	mutations: ProfileMutationService = null,
	compatibility: LoadoutCompatibilityService = null,
	equipment: EquipmentCatalog = null,
	foundation: ItemFoundationCatalog = null,
	classes: GameCatalog = null,
) -> void:
	_mutations = mutations if mutations != null else ProfileMutationService.new()
	_compatibility = compatibility if compatibility != null else LoadoutCompatibilityService.new()
	_equipment = equipment if equipment != null else GameCatalog.EQUIPMENT_CATALOG
	_foundation = foundation if foundation != null else GameCatalog.ITEM_FOUNDATION_CATALOG
	_classes = classes if classes != null else GameCatalog.load_defaults()

func apply(
	profile_id: String,
	request: LoadoutTransitionRequest,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> ProfileMutationResult:
	var request_error := _validate_request(profile_id, request)
	if not request_error.is_empty():
		return _failure(request_error)
	return _mutations.apply(
		profile_id,
		request.transaction_id,
		func(candidate: ProfileState) -> String:
			return _apply_candidate(candidate, request),
		root,
		-1,
		OPERATION,
		request.canonical_document(),
	)

func _validate_request(profile_id: String, request: LoadoutTransitionRequest) -> String:
	if request == null:
		return _error("field=request reason=must not be null")
	if request.transaction_id.strip_edges().is_empty():
		return _error("field=transaction_id reason=must not be empty")
	if profile_id != request.profile_id:
		return _error("field=profile_id reason=profile identity mismatch")
	if request.profile_id.strip_edges().is_empty():
		return _error("field=profile_id reason=must not be empty")
	if request.selected_class_id.is_empty() or _classes.class_by_id(request.selected_class_id) == null:
		return _error("field=selected_class_id reason=unknown selected class")
	if request.cancelled:
		return _error("field=cancelled reason=transition was cancelled")
	if not request.confirmed:
		return _error("field=confirmed reason=explicit confirmation required")
	if request.confirmation_token.is_empty():
		return _error("field=confirmation_token reason=confirmation token is required")
	if request.state_fingerprint.length() != 64 or not request.state_fingerprint.is_valid_hex_number(false):
		return _error("field=state_fingerprint reason=preflight state fingerprint is required")

	var shape_error := _validate_projection_shape(
		request.incompatible_sources,
		request.planned_stash_destinations,
		request.overflow_item_ids,
	)
	if not shape_error.is_empty():
		return shape_error
	var expected_token := LoadoutCompatibilityProjection.confirmation_token_for(
		request.selected_class_id,
		request.incompatible_sources,
		request.planned_stash_destinations,
		request.overflow_item_ids,
	)
	if request.confirmation_token != expected_token:
		return _error("field=confirmation_token reason=confirmation token is missing or stale")
	return ""

func _validate_projection_shape(
	sources: Array[Dictionary],
	destinations: Array[Dictionary],
	overflow: Array[String],
) -> String:
	var source_ids: Array[String] = []
	var previous_slot := -1
	for index: int in sources.size():
		var source := sources[index]
		if not _has_exact_fields(source, ["instance_id", "source_container_id", "source_slot"]):
			return _error("field=incompatible_sources[%d] reason=must have exact source fields" % index)
		if typeof(source["instance_id"]) != TYPE_STRING or String(source["instance_id"]).strip_edges().is_empty():
			return _error("field=incompatible_sources[%d].instance_id reason=must be a non-empty string" % index)
		if source["source_container_id"] != "leader-loadout":
			return _error("field=incompatible_sources[%d].source_container_id reason=must be leader-loadout" % index)
		if typeof(source["source_slot"]) != TYPE_INT:
			return _error("field=incompatible_sources[%d].source_slot reason=must be an integer" % index)
		var source_slot := int(source["source_slot"])
		if source_slot < 0 or source_slot >= EquipmentSlotIndex.capacity() or source_slot <= previous_slot:
			return _error("field=incompatible_sources[%d].source_slot reason=must be unique canonical equipment order" % index)
		previous_slot = source_slot
		var instance_id := String(source["instance_id"])
		if instance_id in source_ids:
			return _error("field=incompatible_sources[%d].instance_id reason=duplicate instance" % index)
		source_ids.append(instance_id)

	var resolved_ids: Array[String] = []
	for index: int in destinations.size():
		var destination := destinations[index]
		if not _has_exact_fields(destination, ["destination_container_id", "destination_slot", "instance_id"]):
			return _error("field=planned_stash_destinations[%d] reason=must have exact destination fields" % index)
		if typeof(destination["instance_id"]) != TYPE_STRING or String(destination["instance_id"]).strip_edges().is_empty():
			return _error("field=planned_stash_destinations[%d].instance_id reason=must be a non-empty string" % index)
		if typeof(destination["destination_container_id"]) != TYPE_STRING or String(destination["destination_container_id"]).strip_edges().is_empty():
			return _error("field=planned_stash_destinations[%d].destination_container_id reason=must be a non-empty string" % index)
		if typeof(destination["destination_slot"]) != TYPE_INT or int(destination["destination_slot"]) < 0 or int(destination["destination_slot"]) >= ItemSlotContainer.STASH_CAPACITY:
			return _error("field=planned_stash_destinations[%d].destination_slot reason=must be a valid stash slot" % index)
		var instance_id := String(destination["instance_id"])
		if instance_id not in source_ids or instance_id in resolved_ids:
			return _error("field=planned_stash_destinations[%d].instance_id reason=must name one incompatible source exactly once" % index)
		resolved_ids.append(instance_id)

	for index: int in overflow.size():
		var instance_id := overflow[index]
		if instance_id.strip_edges().is_empty() or instance_id not in source_ids or instance_id in resolved_ids:
			return _error("field=overflow_item_ids[%d] reason=must name one incompatible source exactly once" % index)
		resolved_ids.append(instance_id)
	if resolved_ids.size() != source_ids.size():
		return _error("field=incompatible_sources reason=every source requires one destination or overflow decision")
	return ""

func _apply_candidate(candidate: ProfileState, request: LoadoutTransitionRequest) -> String:
	if candidate == null or candidate.profile_id != request.profile_id:
		return _error("field=profile_id reason=candidate profile mismatch")
	var class_definition := _classes.class_by_id(request.selected_class_id)
	if class_definition == null:
		return _error("field=selected_class_id reason=unknown selected class")
	var projection := _compatibility.project(candidate, class_definition, _equipment, _foundation)
	if not projection.valid:
		return _error("field=projection reason=%s" % projection.error)
	if (
		request.selected_class_id != projection.selected_class_id
		or request.incompatible_sources != projection.incompatible_sources()
		or request.planned_stash_destinations != projection.planned_stash_destinations
		or request.overflow_item_ids != projection.overflow_item_ids
		or request.confirmation_token != projection.confirmation_token
		or request.state_fingerprint != projection.state_fingerprint
	):
		return _error("field=projection reason=stale projection")

	var ownership := _profile_ownership(candidate)
	if not ownership.ok():
		return _error("field=profile_items reason=%s" % ownership.error)
	var state := ownership.state
	var registry := state.registry()
	var leader := state.container(&"leader-loadout")
	if registry == null or leader == null:
		return _error("field=profile_items reason=registry or leader loadout missing")
	var stash_tabs: Array[ItemSlotContainer] = []
	var stash_by_id: Dictionary = {}
	for index: int in candidate.stash_tabs.size():
		var document := candidate.stash_tabs[index]
		var container_id := StringName(String(document.get("container_id", "")))
		var tab := state.container(container_id)
		if tab == null or tab.container_kind != ItemSlotContainer.PROFILE_STASH_TAB:
			return _error("field=stash_tabs[%d] reason=stored tab unavailable" % index)
		stash_tabs.append(tab)
		stash_by_id[String(tab.container_id)] = tab

	var source_by_id: Dictionary = {}
	for source: Dictionary in request.incompatible_sources:
		source_by_id[String(source["instance_id"])] = source.duplicate(true)
	for destination: Dictionary in request.planned_stash_destinations:
		var instance_id := String(destination["instance_id"])
		var source := source_by_id.get(instance_id, {}) as Dictionary
		var source_slot := int(source.get("source_slot", -1))
		var tab := stash_by_id.get(String(destination["destination_container_id"])) as ItemSlotContainer
		var destination_slot := int(destination["destination_slot"])
		if source.is_empty() or leader.item_id_at(source_slot) != instance_id:
			return _error("field=leader_loadout reason=planned source changed for %s" % instance_id)
		if tab == null or not tab.item_id_at(destination_slot).is_empty():
			return _error("field=stash reason=planned destination changed for %s" % instance_id)
		leader._clear_slot(source_slot)
		tab._set_item_id(destination_slot, instance_id)

	var destroyed: Dictionary = {}
	for instance_id: String in request.overflow_item_ids:
		var source := source_by_id.get(instance_id, {}) as Dictionary
		var source_slot := int(source.get("source_slot", -1))
		if source.is_empty() or leader.item_id_at(source_slot) != instance_id:
			return _error("field=leader_loadout reason=confirmed overflow source changed for %s" % instance_id)
		leader._clear_slot(source_slot)
		destroyed[instance_id] = true

	var retained_items: Array[ItemInstance] = []
	for instance_id: String in registry.ids():
		if not destroyed.has(instance_id):
			retained_items.append(registry.item(instance_id))
	var containers: Array[ItemSlotContainer] = [leader]
	containers.append_array(stash_tabs)
	var rebuilt := ItemOwnershipState.create(candidate.profile_id, ItemRegistry.new(retained_items), containers)
	var rebuilt_error := rebuilt.validate(_equipment, _foundation)
	if not rebuilt_error.is_empty():
		return _error("field=profile_items reason=rebuilt ownership invalid detail=%s" % rebuilt_error)

	candidate.item_records = rebuilt.registry().to_dictionary()
	candidate.leader_loadout = rebuilt.container(&"leader-loadout").to_dictionary()
	var stored_tabs: Array[Dictionary] = []
	for tab: ItemSlotContainer in stash_tabs:
		stored_tabs.append(rebuilt.container(tab.container_id).to_dictionary())
	candidate.stash_tabs = stored_tabs
	candidate.leader_loadout_class_id = String(request.selected_class_id)
	return ""

func _profile_ownership(profile: ProfileState) -> ItemOwnershipStateDecodeResult:
	var containers: Array = [profile.leader_loadout.duplicate(true)]
	containers.append_array(profile.stash_tabs.duplicate(true))
	return ItemOwnershipState.decode({
		"schema_version": ItemOwnershipState.SCHEMA_VERSION,
		"owner_id": profile.profile_id,
		"registry": profile.item_records.duplicate(true),
		"containers": containers,
	}, _equipment, _foundation)

func _has_exact_fields(document: Dictionary, expected: Array[String]) -> bool:
	if document.size() != expected.size():
		return false
	for field: String in expected:
		if not document.has(field):
			return false
	return true

func _failure(detail: String) -> ProfileMutationResult:
	var result := ProfileMutationResult.new()
	result.error = detail
	return result

func _error(detail: String) -> String:
	return "%s %s" % [ERROR_PREFIX, detail]
