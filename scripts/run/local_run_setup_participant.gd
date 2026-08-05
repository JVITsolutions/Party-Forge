class_name LocalRunSetupParticipant
extends RefCounted

const EDITABLE: StringName = &"editable"
const DECISION_REQUIRED: StringName = &"decision_required"
const READY: StringName = &"ready"

var _profile_id := ""
var profile_id: String:
	get: return _profile_id
	set(_value): pass
var _device_id := -2
var device_id: int:
	get: return _device_id
	set(_value): pass
var _player_slot := -1
var player_slot: int:
	get: return _player_slot
	set(_value): pass
var _selected_class_id: StringName = &""
var selected_class_id: StringName:
	get: return _selected_class_id
	set(_value): pass
var _decision_state: StringName = EDITABLE
var decision_state: StringName:
	get: return _decision_state
	set(_value): pass
var _ready := false
var ready: bool:
	get: return _ready
	set(_value): pass
var _projection: LoadoutCompatibilityProjection
var projection: LoadoutCompatibilityProjection:
	get: return _copy_projection(_projection)
	set(_value): pass
var _context: PlayerRunContext
var context: PlayerRunContext:
	get: return _context
	set(_value): pass

func _init(
	profile_id_value: String = "",
	device_id_value: int = -2,
	player_slot_value: int = -1,
	selected_class_id_value: StringName = &"",
) -> void:
	_profile_id = profile_id_value
	_device_id = device_id_value
	_player_slot = player_slot_value
	_selected_class_id = selected_class_id_value

func _snapshot() -> LocalRunSetupParticipant:
	var result := LocalRunSetupParticipant.new(_profile_id, _device_id, _player_slot, _selected_class_id)
	result._decision_state = _decision_state
	result._ready = _ready
	result._projection = _copy_projection(_projection)
	result._context = _context
	return result

func _set_projection(value: LoadoutCompatibilityProjection) -> void:
	_projection = _copy_projection(value)
	_context = null
	_ready = value != null and value.valid and value.incompatible_items.is_empty()
	_decision_state = READY if _ready else DECISION_REQUIRED

func _set_context(value: PlayerRunContext) -> void:
	_context = value

static func _copy_projection(source: LoadoutCompatibilityProjection) -> LoadoutCompatibilityProjection:
	if source == null:
		return null
	if not source.valid:
		return LoadoutCompatibilityProjection.failure(source.error)
	return LoadoutCompatibilityProjection.success(
		source.selected_class_id,
		source.compatible_items,
		source.incompatible_items,
		source.planned_stash_destinations,
		source.overflow_item_ids,
		source.state_fingerprint,
	)
