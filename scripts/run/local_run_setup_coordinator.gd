class_name LocalRunSetupCoordinator
extends RefCounted

signal decision_required(profile_id: String, projection: LoadoutCompatibilityProjection)

const ERROR_PREFIX := "PARTY_FORGE_LOCAL_RUN_SETUP_ERROR"
const MAX_PARTICIPANTS := PartyManager.MAX_PARTY_SIZE
const DECISION_FIELDS: Array[String] = [
	"cancelled",
	"confirmation_token",
	"confirmed",
	"incompatible_sources",
	"overflow_item_ids",
	"planned_stash_destinations",
	"profile_id",
	"selected_class_id",
	"state_fingerprint",
	"transaction_id",
]

var _profile_store: ProfileStore
var _profile_root := ProfileStore.DEFAULT_ROOT
var _compatibility: LoadoutCompatibilityService
var _transitions: LoadoutTransitionService
var _catalog: GameCatalog
var _equipment: EquipmentCatalog
var _foundation: ItemFoundationCatalog
var _assignment_guard: Callable
var _context_factory: Callable
var _participants_by_profile: Dictionary = {}
var _participants: Array[LocalRunSetupParticipant] = []
var _locked := false
var _registry: RunContextRegistry

func _init(dependencies: Dictionary = {}) -> void:
	_profile_store = dependencies.get("profile_store") as ProfileStore
	if _profile_store == null:
		_profile_store = ProfileStore.new()
	_profile_root = String(dependencies.get("profile_root", ProfileStore.DEFAULT_ROOT))
	_compatibility = dependencies.get("compatibility_service") as LoadoutCompatibilityService
	if _compatibility == null:
		_compatibility = LoadoutCompatibilityService.new()
	_catalog = dependencies.get("classes") as GameCatalog
	if _catalog == null:
		_catalog = GameCatalog.load_defaults()
	_equipment = dependencies.get("equipment") as EquipmentCatalog
	if _equipment == null:
		_equipment = GameCatalog.EQUIPMENT_CATALOG
	_foundation = dependencies.get("foundation") as ItemFoundationCatalog
	if _foundation == null:
		_foundation = GameCatalog.ITEM_FOUNDATION_CATALOG
	_transitions = dependencies.get("transition_service") as LoadoutTransitionService
	if _transitions == null:
		_transitions = LoadoutTransitionService.new(
			ProfileMutationService.new(_profile_store),
			_compatibility,
			_equipment,
			_foundation,
			_catalog,
		)
	_assignment_guard = dependencies.get("assignment_guard", Callable()) as Callable
	_context_factory = dependencies.get("context_factory", Callable()) as Callable

func begin(values: Array) -> PackedStringArray:
	if _locked:
		return _errors("field=state reason=coordinator is locked")
	if values.is_empty() or values.size() > MAX_PARTICIPANTS:
		return _errors("field=participants reason=participant count must be between 1 and %d" % MAX_PARTICIPANTS)
	var profiles: Dictionary = {}
	var devices: Dictionary = {}
	var slots: Dictionary = {}
	var captured: Array[LocalRunSetupParticipant] = []
	var pending: Array[LocalRunSetupParticipant] = []
	for index: int in values.size():
		var source := values[index] as LocalRunSetupParticipant
		if source == null:
			return _errors("field=participants[%d] reason=participant is null or invalid" % index)
		var profile_error := ProfileCodec.validate_profile_id(source.profile_id)
		if not profile_error.is_empty():
			return _errors("field=participants[%d].profile_id reason=%s" % [index, profile_error])
		if profiles.has(source.profile_id):
			return _errors("field=participants[%d].profile_id reason=duplicate profile" % index)
		if source.device_id < -1:
			return _errors("field=participants[%d].device_id reason=device must be keyboard/mouse (-1) or a controller id" % index)
		if devices.has(source.device_id):
			return _errors("field=participants[%d].device_id reason=duplicate device" % index)
		if source.player_slot < 0:
			return _errors("field=participants[%d].player_slot reason=player slot must be nonnegative" % index)
		if slots.has(source.player_slot):
			return _errors("field=participants[%d].player_slot reason=duplicate player slot" % index)
		if source.selected_class_id.is_empty() or _catalog.class_by_id(source.selected_class_id) == null:
			return _errors("field=participants[%d].selected_class_id reason=unknown selected class" % index)
		profiles[source.profile_id] = true
		devices[source.device_id] = true
		slots[source.player_slot] = true
	for index: int in values.size():
		var source := values[index] as LocalRunSetupParticipant
		if not _assignment_is_current(source):
			return _errors("field=participants[%d] reason=assignment changed" % index)
		var loaded := _load_strict_profile(source.profile_id)
		if not String(loaded.get("error", "")).is_empty():
			return _errors("field=participants[%d].profile reason=%s" % [index, loaded["error"]])
		var profile := loaded["profile"] as ProfileState
		var class_definition := _catalog.class_by_id(source.selected_class_id)
		var projection := _compatibility.project(profile, class_definition, _equipment, _foundation)
		if projection == null or not projection.valid:
			return _errors("field=participants[%d].projection reason=%s" % [index, projection.error if projection != null else "unavailable"])
		var owned := source._snapshot()
		owned._set_projection(projection)
		captured.append(owned)
		if not owned.ready:
			pending.append(owned)

	var next_by_profile: Dictionary = {}
	for participant_value: LocalRunSetupParticipant in captured:
		next_by_profile[participant_value.profile_id] = participant_value
	_participants = captured
	_participants_by_profile = next_by_profile
	_registry = null
	for participant_value: LocalRunSetupParticipant in pending:
		decision_required.emit(participant_value.profile_id, participant_value.projection)
	return PackedStringArray()

func submit(profile_id: String, decision: Dictionary) -> PackedStringArray:
	if _locked:
		return _errors("field=state reason=coordinator is locked")
	var participant_value := _participants_by_profile.get(profile_id) as LocalRunSetupParticipant
	if participant_value == null:
		return _errors("field=profile_id reason=unknown profile")
	if participant_value.ready or participant_value.decision_state != LocalRunSetupParticipant.DECISION_REQUIRED:
		return _errors("field=decision reason=profile has no pending decision")
	if not _assignment_is_current(participant_value):
		return _errors("field=assignment reason=assignment changed")
	var decision_error := _validate_decision_document(participant_value, decision)
	if not decision_error.is_empty():
		return _errors(decision_error)
	var loaded := _load_strict_profile(profile_id)
	if not String(loaded.get("error", "")).is_empty():
		return _errors("field=profile reason=%s" % loaded["error"])
	var profile := loaded["profile"] as ProfileState
	var fresh := _compatibility.project(
		profile,
		_catalog.class_by_id(participant_value.selected_class_id),
		_equipment,
		_foundation,
	)
	if not _projection_matches(participant_value.projection, fresh) or not _decision_matches_projection(decision, fresh):
		return _errors("field=decision reason=stale projection")
	if bool(decision["cancelled"]):
		_cancel_unlocked()
		return PackedStringArray()
	var request := LoadoutTransitionRequest.create(
		String(decision["transaction_id"]),
		profile_id,
		participant_value.selected_class_id,
		(decision["incompatible_sources"] as Array).duplicate(true),
		(decision["planned_stash_destinations"] as Array).duplicate(true),
		_array_of_strings(decision["overflow_item_ids"] as Array),
		true,
		false,
		String(decision["confirmation_token"]),
		String(decision["state_fingerprint"]),
	)
	var result := _transitions.apply(profile_id, request, _profile_root)
	if result == null or not result.ok():
		return _errors("field=transition reason=%s" % [result.error if result != null else "unavailable"])
	loaded = _load_strict_profile(profile_id)
	if not String(loaded.get("error", "")).is_empty():
		return _errors("field=reload reason=%s" % loaded["error"])
	profile = loaded["profile"] as ProfileState
	var clean := _compatibility.project(
		profile,
		_catalog.class_by_id(participant_value.selected_class_id),
		_equipment,
		_foundation,
	)
	if clean == null or not clean.valid or not clean.incompatible_items.is_empty():
		return _errors("field=reprojection reason=transition did not produce clean compatibility")
	participant_value._set_projection(clean)
	return PackedStringArray()

func cancel() -> bool:
	if _locked or _participants.is_empty():
		return false
	_cancel_unlocked()
	return true

func ready_contexts() -> Array[PlayerRunContext]:
	if _locked or _participants.is_empty():
		return []
	for participant_value: LocalRunSetupParticipant in _participants:
		if not participant_value.ready:
			return []
	if not _context_factory.is_valid():
		return []
	var sorted := _participants.duplicate()
	sorted.sort_custom(func(left: LocalRunSetupParticipant, right: LocalRunSetupParticipant) -> bool:
		return left.player_slot < right.player_slot)
	var next_registry := RunContextRegistry.new()
	var contexts: Array[PlayerRunContext] = []
	for participant_value: LocalRunSetupParticipant in sorted:
		if not _assignment_is_current(participant_value):
			return []
		var loaded := _load_strict_profile(participant_value.profile_id)
		if not String(loaded.get("error", "")).is_empty():
			return []
		var profile := loaded["profile"] as ProfileState
		var projection := _compatibility.project(
			profile,
			_catalog.class_by_id(participant_value.selected_class_id),
			_equipment,
			_foundation,
		)
		if projection == null or not projection.valid or not projection.incompatible_items.is_empty():
			return []
		var context := _context_factory.call(participant_value._snapshot(), profile.copy()) as PlayerRunContext
		if (
			context == null
			or context.profile_id != participant_value.profile_id
			or context.player_slot_index != participant_value.player_slot
			or context.run_player_id.is_empty()
			or context.party == null
		):
			return []
		var registration := next_registry.register_context(context, participant_value.device_id)
		if not registration.ok():
			return []
		contexts.append(context)
	next_registry.lock_arena_roster()
	for index: int in sorted.size():
		sorted[index]._set_context(contexts[index])
	_registry = next_registry
	_locked = true
	return _registry.all_contexts()

func armoury_projection(profile_id: String) -> ProfileStorageProjection:
	if not _participants_by_profile.has(profile_id):
		return null
	var participant_value := _participants_by_profile[profile_id] as LocalRunSetupParticipant
	if participant_value == null or not _assignment_is_current(participant_value):
		return null
	var loaded := _load_strict_profile(profile_id)
	if not String(loaded.get("error", "")).is_empty():
		return null
	var projection := ProfileStorageProjection.from_profile(loaded["profile"] as ProfileState, _equipment, _foundation)
	return projection.copy() if projection != null else null

func is_locked() -> bool:
	return _locked

func participant(profile_id: String) -> LocalRunSetupParticipant:
	var value := _participants_by_profile.get(profile_id) as LocalRunSetupParticipant
	return value._snapshot() if value != null else null

func run_context_registry() -> RunContextRegistry:
	return _registry

func _load_strict_profile(profile_id: String) -> Dictionary:
	var loaded := _profile_store.load_profile(profile_id, _profile_root)
	if loaded == null or not loaded.ok():
		return {"error": loaded.error if loaded != null else "profile load unavailable"}
	var validation := ProfileCodec.validate_profile(loaded.profile)
	if not validation.is_empty():
		return {"error": validation}
	if loaded.profile.profile_id != profile_id:
		return {"error": "loaded profile identity mismatch"}
	return {"error": "", "profile": loaded.profile.copy()}

func _assignment_is_current(participant_value: LocalRunSetupParticipant) -> bool:
	return not _assignment_guard.is_valid() or bool(_assignment_guard.call(participant_value._snapshot()))

func _validate_decision_document(participant_value: LocalRunSetupParticipant, decision: Dictionary) -> String:
	if decision.size() != DECISION_FIELDS.size():
		return "field=decision reason=must contain exact fields"
	for field: String in DECISION_FIELDS:
		if not decision.has(field):
			return "field=decision reason=must contain exact fields"
	if typeof(decision["profile_id"]) != TYPE_STRING or String(decision["profile_id"]) != participant_value.profile_id:
		return "field=decision.profile_id reason=profile mismatch"
	if typeof(decision["selected_class_id"]) != TYPE_STRING or StringName(decision["selected_class_id"]) != participant_value.selected_class_id:
		return "field=decision.selected_class_id reason=selected class mismatch"
	if typeof(decision["transaction_id"]) != TYPE_STRING or String(decision["transaction_id"]).strip_edges().is_empty():
		return "field=decision.transaction_id reason=must be non-empty"
	if typeof(decision["confirmed"]) != TYPE_BOOL or typeof(decision["cancelled"]) != TYPE_BOOL:
		return "field=decision reason=confirmation fields must be boolean"
	if bool(decision["confirmed"]) == bool(decision["cancelled"]):
		return "field=decision reason=exactly one of confirmed or cancelled is required"
	if (
		not decision["incompatible_sources"] is Array
		or not decision["planned_stash_destinations"] is Array
		or not decision["overflow_item_ids"] is Array
		or typeof(decision["confirmation_token"]) != TYPE_STRING
		or typeof(decision["state_fingerprint"]) != TYPE_STRING
	):
		return "field=decision reason=projection fields are malformed"
	return ""

func _decision_matches_projection(decision: Dictionary, projection: LoadoutCompatibilityProjection) -> bool:
	return (
		projection != null
		and StringName(decision["selected_class_id"]) == projection.selected_class_id
		and decision["incompatible_sources"] == projection.incompatible_sources()
		and decision["planned_stash_destinations"] == projection.planned_stash_destinations
		and decision["overflow_item_ids"] == projection.overflow_item_ids
		and String(decision["confirmation_token"]) == projection.confirmation_token
		and String(decision["state_fingerprint"]) == projection.state_fingerprint
	)

func _projection_matches(left: LoadoutCompatibilityProjection, right: LoadoutCompatibilityProjection) -> bool:
	return (
		left != null
		and right != null
		and left.valid
		and right.valid
		and left.selected_class_id == right.selected_class_id
		and left.incompatible_sources() == right.incompatible_sources()
		and left.planned_stash_destinations == right.planned_stash_destinations
		and left.overflow_item_ids == right.overflow_item_ids
		and left.confirmation_token == right.confirmation_token
		and left.state_fingerprint == right.state_fingerprint
	)

func _cancel_unlocked() -> void:
	_participants_by_profile.clear()
	_participants.clear()
	_registry = null

func _array_of_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result

func _errors(detail: String) -> PackedStringArray:
	return PackedStringArray(["%s %s" % [ERROR_PREFIX, detail]])
