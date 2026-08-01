class_name ProfileManager
extends RefCounted

signal profiles_changed
signal active_profile_changed(profile: ProfileState)

var _profiles: Dictionary = {}
var _index := ProfileIndex.new()
var _profile_store: ProfileStore
var _index_store: ProfileIndexStore
var _id_factory: Callable
var _root := ProfileStore.DEFAULT_ROOT

func _init(profile_store: ProfileStore = null, index_store: ProfileIndexStore = null, id_factory: Callable = Callable()) -> void:
	_profile_store = profile_store if profile_store != null else ProfileStore.new()
	_index_store = index_store if index_store != null else ProfileIndexStore.new()
	_id_factory = id_factory

func bootstrap(root: String = ProfileStore.DEFAULT_ROOT) -> String:
	_root = root
	_profiles.clear()
	_index = ProfileIndex.new()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_root))
	if mkdir_error not in [OK, ERR_ALREADY_EXISTS]:
		return "PROFILE_BOOTSTRAP_ERROR root=%s stage=mkdir code=%d" % [_root, mkdir_error]
	var diagnostics: Array[String] = []
	for profile_id: String in _profile_store.profile_ids(_root):
		var loaded := _profile_store.load_profile(profile_id, _root)
		if loaded.ok():
			_profiles[profile_id] = loaded.profile
		else:
			diagnostics.append("profile=%s error=%s" % [profile_id, loaded.error])
	var loaded_index := _index_store.load_index(_root)
	if loaded_index.ok():
		_index = loaded_index.index
	else:
		_index = ProfileIndex.new()
		if not loaded_index.error.is_empty():
			diagnostics.append(loaded_index.error)
	if not _profiles.has(_index.active_profile_id):
		_index.active_profile_id = _most_recent_profile_id()
	_rebuild_index()
	var save_error := _index_store.save_index(_index, _root)
	if not save_error.is_empty():
		diagnostics.append(save_error)
	return "" if diagnostics.is_empty() else "PROFILE_BOOTSTRAP_ERROR %s" % " | ".join(diagnostics)

func profiles() -> Array[ProfileState]:
	var result: Array[ProfileState] = []
	for profile: ProfileState in _profiles.values():
		result.append(profile.copy())
	result.sort_custom(func(a: ProfileState, b: ProfileState) -> bool: return a.updated_at_unix > b.updated_at_unix)
	return result

func active_profile() -> ProfileState:
	var profile := _profiles.get(_index.active_profile_id) as ProfileState
	return profile.copy() if profile != null else null

func create_profile(display_name: String, now_unix: int = -1) -> ProfileOperationResult:
	var result := ProfileOperationResult.new()
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 32:
		result.error = "PROFILE_CREATE_ERROR reason=name must contain 1-32 characters"
		return result
	var normalized := clean_name.to_lower()
	for profile: ProfileState in _profiles.values():
		if profile.display_name.strip_edges().to_lower() == normalized:
			result.error = "PROFILE_CREATE_ERROR reason=name already exists"
			return result
	var profile_id := _next_profile_id()
	if _profiles.has(profile_id):
		result.error = "PROFILE_CREATE_ERROR profile=%s reason=id collision" % profile_id
		return result
	var timestamp := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var profile := ProfileState.new_profile(profile_id, clean_name, timestamp)
	var save_error := _profile_store.save_profile(profile, _root)
	if not save_error.is_empty():
		result.error = save_error
		return result
	var previous_active := _index.active_profile_id
	_profiles[profile_id] = profile
	_index.active_profile_id = profile_id
	_rebuild_index()
	var index_error := _index_store.save_index(_index, _root)
	if not index_error.is_empty():
		_profiles.erase(profile_id)
		_index.active_profile_id = previous_active
		_rebuild_index()
		result.error = index_error
		return result
	result.profile = profile.copy()
	profiles_changed.emit()
	active_profile_changed.emit(profile.copy())
	return result

func select_profile(profile_id: String) -> String:
	if not _profiles.has(profile_id):
		return "PROFILE_SELECT_ERROR profile=%s reason=unknown profile" % profile_id
	var previous := _index.active_profile_id
	_index.active_profile_id = profile_id
	var save_error := _index_store.save_index(_index, _root)
	if not save_error.is_empty():
		_index.active_profile_id = previous
		return save_error
	active_profile_changed.emit((_profiles[profile_id] as ProfileState).copy())
	return ""

func refresh_profile(profile_id: String) -> String:
	var loaded := _profile_store.load_profile(profile_id, _root)
	if not loaded.ok():
		var reason := loaded.error if not loaded.error.is_empty() else "unknown profile"
		return "PROFILE_REFRESH_ERROR profile=%s error=%s" % [profile_id, reason]
	_profiles[profile_id] = loaded.profile
	_rebuild_index()
	var save_error := _index_store.save_index(_index, _root)
	if save_error.is_empty():
		profiles_changed.emit()
	return save_error

func _rebuild_index() -> void:
	_index.rebuild(profiles())

func _most_recent_profile_id() -> String:
	var available := profiles()
	return available[0].profile_id if not available.is_empty() else ""

func _next_profile_id() -> String:
	if _id_factory.is_valid():
		return str(_id_factory.call())
	return "profile-%s" % Crypto.new().generate_random_bytes(16).hex_encode()
