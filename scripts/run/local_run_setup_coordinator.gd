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
const CHECKOUT_REQUEST_FIELDS: Array[String] = [
	"bring_in_gear",
	"leader_member_id",
	"profile_id",
	"run_id",
	"run_player_id",
	"run_seed",
	"selected_leader_class_id",
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
var _checkout_service: RunLoadoutCheckoutService
var _checkout_request_factory: Callable
var _context_factory: Callable
var _participants_by_profile: Dictionary = {}
var _participants: Array[LocalRunSetupParticipant] = []
var _checkout_recovery_by_profile: Dictionary = {}
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
	_checkout_service = dependencies.get("checkout_service") as RunLoadoutCheckoutService
	if _checkout_service == null:
		_checkout_service = RunLoadoutCheckoutService.new(ProfileMutationService.new(_profile_store))
	_checkout_request_factory = dependencies.get("checkout_request_factory", Callable()) as Callable
	_context_factory = dependencies.get("context_factory", Callable()) as Callable

func begin(values: Array) -> PackedStringArray:
	if _locked:
		return _errors("field=state reason=coordinator is locked")
	if not _checkout_recovery_by_profile.is_empty():
		return _errors("field=state reason=committed checkout recovery is active")
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
	_checkout_recovery_by_profile.clear()
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
	if not _checkout_request_factory.is_valid() or not _context_factory.is_valid():
		return []
	var sorted := _participants.duplicate()
	sorted.sort_custom(func(left: LocalRunSetupParticipant, right: LocalRunSetupParticipant) -> bool:
		return left.player_slot < right.player_slot)
	var preflight := _preflight_ready_contexts(sorted)
	if not String(preflight.get("error", "")).is_empty():
		return []
	var prepared_by_profile := preflight.get("prepared", {}) as Dictionary
	var contexts: Array[PlayerRunContext] = []
	for participant_value: LocalRunSetupParticipant in sorted:
		var preflight_entry := prepared_by_profile.get(participant_value.profile_id, {}) as Dictionary
		var prepared := _prepare_committed_checkout(
			participant_value,
			preflight_entry.get("profile") as ProfileState,
			preflight_entry.get("request") as RunLoadoutCheckoutRequest,
			(preflight_entry.get("request_document", {}) as Dictionary).duplicate(true),
		)
		if not String(prepared.get("error", "")).is_empty():
			return []
		var profile := prepared["profile"] as ProfileState
		var bootstrap := prepared["bootstrap"] as RunItemBootstrap
		var committed_profile_document := ProfileCodec.encode(profile.copy())
		var context := _context_factory.call(participant_value._snapshot(), profile, bootstrap) as PlayerRunContext
		if not _context_matches_commit(participant_value, committed_profile_document, bootstrap, context):
			return []
		contexts.append(context)
	var next_registry := RunContextRegistry.new()
	for index: int in contexts.size():
		var registration := next_registry.register_context(contexts[index], sorted[index].device_id)
		if not registration.ok():
			return []
	next_registry.lock_arena_roster()
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
	return _assignment_guard.is_valid() and bool(_assignment_guard.call(participant_value._snapshot()))


func _preflight_ready_contexts(sorted: Array[LocalRunSetupParticipant]) -> Dictionary:
	var profiles: Dictionary = {}
	var devices: Dictionary = {}
	var slots: Dictionary = {}
	var run_players: Dictionary = {}
	var prepared: Dictionary = {}
	for participant_value: LocalRunSetupParticipant in sorted:
		if participant_value == null or not _assignment_is_current(participant_value):
			return {"error": "assignment changed"}
		if (
			profiles.has(participant_value.profile_id)
			or devices.has(participant_value.device_id)
			or slots.has(participant_value.player_slot)
		):
			return {"error": "participant registry identity collision"}
		profiles[participant_value.profile_id] = true
		devices[participant_value.device_id] = true
		slots[participant_value.player_slot] = true
		var loaded := _load_strict_profile(participant_value.profile_id)
		if not String(loaded.get("error", "")).is_empty():
			return {"error": loaded["error"]}
		var profile := loaded["profile"] as ProfileState
		var projection := _compatibility.project(
			profile,
			_catalog.class_by_id(participant_value.selected_class_id),
			_equipment,
			_foundation,
		)
		if projection == null or not projection.valid or not projection.incompatible_items.is_empty():
			return {"error": "profile compatibility is not ready"}
		var recovery := _checkout_recovery_by_profile.get(participant_value.profile_id, {}) as Dictionary
		var request: RunLoadoutCheckoutRequest
		var request_document: Dictionary
		if recovery.is_empty():
			var generated := _checkout_request_factory.call(participant_value._snapshot(), profile.copy()) as RunLoadoutCheckoutRequest
			if generated == null:
				return {"error": "checkout request unavailable"}
			request_document = generated.canonical_document().duplicate(true)
		else:
			request_document = (recovery.get("request", {}) as Dictionary).duplicate(true)
		var request_error := _validate_checkout_request_document(participant_value, profile, request_document)
		if not request_error.is_empty():
			return {"error": request_error}
		if recovery.is_empty():
			request = _owned_checkout_request(request_document)
			if request == null:
				return {"error": "checkout request ownership failed"}
		elif not _recovery_matches_profile(participant_value, profile, recovery, request_document):
			return {"error": "committed checkout recovery mismatch"}
		var run_player_id := StringName(request_document["run_player_id"])
		if run_players.has(run_player_id):
			return {"error": "duplicate run player"}
		run_players[run_player_id] = true
		prepared[participant_value.profile_id] = {
			"profile": profile.copy(),
			"request": request,
			"request_document": request_document.duplicate(true),
		}
	return {"error": "", "prepared": prepared}


func _validate_checkout_request_document(
	participant_value: LocalRunSetupParticipant,
	profile: ProfileState,
	request_document: Dictionary,
) -> String:
	if request_document.size() != CHECKOUT_REQUEST_FIELDS.size():
		return "checkout request must contain exact fields"
	for field: String in CHECKOUT_REQUEST_FIELDS:
		if not request_document.has(field):
			return "checkout request must contain exact fields"
	if (
		typeof(request_document["transaction_id"]) != TYPE_STRING
		or typeof(request_document["profile_id"]) != TYPE_STRING
		or typeof(request_document["run_id"]) != TYPE_STRING
		or typeof(request_document["run_player_id"]) != TYPE_STRING
		or typeof(request_document["selected_leader_class_id"]) != TYPE_STRING
		or typeof(request_document["run_seed"]) != TYPE_INT
		or typeof(request_document["leader_member_id"]) != TYPE_INT
		or typeof(request_document["bring_in_gear"]) != TYPE_BOOL
	):
		return "checkout request fields are malformed"
	var profile_id := String(request_document["profile_id"])
	var class_id := StringName(request_document["selected_leader_class_id"])
	if not ProfileCodec.validate_profile_id(profile_id).is_empty() or profile_id != participant_value.profile_id or profile_id != profile.profile_id:
		return "checkout request profile mismatch"
	if class_id != participant_value.selected_class_id or _catalog.class_by_id(class_id) == null:
		return "checkout request selected class mismatch"
	if bool(request_document["bring_in_gear"]) != ("bring_in_gear" in profile.permanent_feature_unlocks):
		return "checkout request bring-in policy mismatch"
	if String(request_document["transaction_id"]).strip_edges().is_empty():
		return "checkout request transaction id is empty"
	if String(request_document["run_id"]).strip_edges().is_empty():
		return "checkout request run id is empty"
	if String(request_document["run_player_id"]).strip_edges().is_empty():
		return "checkout request run player id is empty"
	if int(request_document["run_seed"]) <= 0:
		return "checkout request run seed must be positive"
	if int(request_document["leader_member_id"]) <= 0:
		return "checkout request leader member id must be positive"
	return ""


func _owned_checkout_request(request_document: Dictionary) -> RunLoadoutCheckoutRequest:
	return RunLoadoutCheckoutRequest.create(
		String(request_document["transaction_id"]),
		String(request_document["profile_id"]),
		StringName(request_document["run_id"]),
		int(request_document["run_seed"]),
		StringName(request_document["run_player_id"]),
		int(request_document["leader_member_id"]),
		StringName(request_document["selected_leader_class_id"]),
		bool(request_document["bring_in_gear"]),
	)


func _recovery_matches_profile(
	participant_value: LocalRunSetupParticipant,
	profile: ProfileState,
	recovery: Dictionary,
	request_document: Dictionary,
) -> bool:
	var expected_document := recovery.get("resumable_run", {}) as Dictionary
	if expected_document.is_empty() or profile.resumable_run != expected_document:
		return false
	return _bootstrap_matches_recovery(
		participant_value,
		_checkout_service.bootstrap_from(profile),
		request_document,
		expected_document,
	)


func _prepare_committed_checkout(
	participant_value: LocalRunSetupParticipant,
	profile: ProfileState,
	request: RunLoadoutCheckoutRequest,
	request_document: Dictionary,
) -> Dictionary:
	var recovery := _checkout_recovery_by_profile.get(participant_value.profile_id, {}) as Dictionary
	if recovery.is_empty():
		if request == null or request.canonical_document() != request_document:
			return {"error": "checkout request unavailable"}
		var result := _checkout_service.checkout(participant_value.profile_id, request, _profile_root)
		if result == null or not result.ok() or result.profile == null:
			return {"error": result.error if result != null else "checkout unavailable"}
		var committed_document := result.profile.resumable_run.duplicate(true)
		if committed_document.is_empty():
			return {"error": "committed resumable run unavailable"}
		recovery = {
			"request": request_document.duplicate(true),
			"resumable_run": committed_document.duplicate(true),
		}
		_checkout_recovery_by_profile[participant_value.profile_id] = recovery.duplicate(true)
	var loaded := _load_strict_profile(participant_value.profile_id)
	if not String(loaded.get("error", "")).is_empty():
		return {"error": loaded["error"]}
	var committed_profile := loaded["profile"] as ProfileState
	var expected_document := recovery.get("resumable_run", {}) as Dictionary
	if expected_document.is_empty() or committed_profile.resumable_run != expected_document:
		return {"error": "committed resumable run mismatch"}
	var bootstrap := _checkout_service.bootstrap_from(committed_profile)
	var recovery_request_document := recovery.get("request", {}) as Dictionary
	if not _bootstrap_matches_recovery(participant_value, bootstrap, recovery_request_document, expected_document):
		return {"error": "committed bootstrap identity mismatch"}
	committed_profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	return {
		"error": "",
		"profile": committed_profile,
		"bootstrap": bootstrap,
	}


func _context_matches_commit(
	participant_value: LocalRunSetupParticipant,
	committed_profile_document: String,
	bootstrap: RunItemBootstrap,
	context: PlayerRunContext,
) -> bool:
	if context == null or committed_profile_document.is_empty() or bootstrap == null:
		return false
	var context_profile := context.profile_snapshot
	var leader := context.party.member_by_id(bootstrap.leader_member_id) if context.party != null else null
	return (
		context.profile_id == participant_value.profile_id
		and context.player_slot_index == participant_value.player_slot
		and context.run_player_id == bootstrap.run_player_id
		and context.run_id == bootstrap.run_id
		and context.run_seed == bootstrap.run_seed
		and context_profile != null
		and ProfileCodec.encode(context_profile) == committed_profile_document
		and leader != null
		and leader.is_leader
		and leader.class_definition != null
		and leader.class_definition.id == participant_value.selected_class_id
		and context.item_state() != null
		and context.item_state().to_dictionary() == bootstrap.item_state().to_dictionary()
	)


func _bootstrap_matches_recovery(
	participant_value: LocalRunSetupParticipant,
	bootstrap: RunItemBootstrap,
	request_document: Dictionary,
	expected_document: Dictionary,
) -> bool:
	if bootstrap == null or participant_value == null or request_document.is_empty():
		return false
	var canonical := ResumableRunItemCodec.encode(bootstrap)
	var expected_bootstrap := ResumableRunItemCodec.decode(
		expected_document,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
	)
	var canonical_expected := ResumableRunItemCodec.encode(expected_bootstrap) if expected_bootstrap != null else {}
	return (
		not canonical.is_empty()
		and canonical == canonical_expected
		and String(request_document.get("profile_id", "")) == participant_value.profile_id
		and StringName(request_document.get("selected_leader_class_id", "")) == participant_value.selected_class_id
		and String(bootstrap.run_id) == String(request_document.get("run_id", ""))
		and bootstrap.run_seed == int(request_document.get("run_seed", 0))
		and String(bootstrap.run_player_id) == String(request_document.get("run_player_id", ""))
		and bootstrap.leader_member_id == int(request_document.get("leader_member_id", 0))
	)

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
	_checkout_recovery_by_profile.clear()
	_registry = null

func _array_of_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result

func _errors(detail: String) -> PackedStringArray:
	return PackedStringArray(["%s %s" % [ERROR_PREFIX, detail]])
