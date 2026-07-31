class_name FeatureAccessPolicy
extends RefCounted

enum State { HIDDEN, COMING_SOON, DEVELOPER_PREVIEW, AVAILABLE }

var _developer_mode := false
var _unlock_all := false
var _known_features: Array[StringName] = []
var _known_unlocks: Array[StringName] = []
var _unlocked: Array[StringName] = []

func _init(developer_mode: bool, unlock_all: bool, known_features: Array[StringName] = [], known_unlocks: Array[StringName] = [], unlocked: Array[StringName] = []) -> void:
	_developer_mode = developer_mode
	_unlock_all = unlock_all
	_known_features = known_features.duplicate()
	_known_unlocks = known_unlocks.duplicate()
	_unlocked = unlocked.duplicate()

func resolve(feature_id: StringName, development_state: int, unlock_id: StringName = &"") -> State:
	if feature_id.is_empty() or feature_id not in _known_features:
		push_error("PARTY_FORGE_FEATURE_ACCESS_ERROR feature=%s reason=unknown feature" % feature_id)
		return State.HIDDEN
	if not unlock_id.is_empty() and unlock_id not in _known_unlocks:
		push_error("PARTY_FORGE_FEATURE_ACCESS_ERROR feature=%s unlock=%s reason=unknown unlock" % [feature_id, unlock_id])
		return State.HIDDEN
	match development_state:
		State.HIDDEN: return State.HIDDEN
		State.COMING_SOON: return State.COMING_SOON
		State.DEVELOPER_PREVIEW: return State.AVAILABLE if _developer_mode else State.HIDDEN
		State.AVAILABLE:
			return State.AVAILABLE if unlock_id.is_empty() or unlock_id in _unlocked or _unlock_all else State.HIDDEN
		_: return State.HIDDEN
