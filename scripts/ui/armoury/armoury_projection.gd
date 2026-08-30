class_name ArmouryProjection
extends RefCounted

var _storage: ProfileStorageProjection

var active_class_id: StringName: get = _get_active_class_id
var leader_slots: Array[Dictionary]: get = _get_leader_slots
var stash_tabs: Array[Dictionary]: get = _get_stash_tabs
var terminal_recovery_overflow: Dictionary: get = _get_terminal_recovery_overflow
var loadout_empty: bool: get = _get_loadout_empty

static func from_storage(storage: ProfileStorageProjection) -> ArmouryProjection:
	var result := ArmouryProjection.new()
	result._storage = storage.copy() if storage != null else ProfileStorageProjection.new()
	return result

func item(instance_id: String) -> Dictionary:
	return _storage.item(instance_id) if _storage != null else {}

func storage_projection() -> ProfileStorageProjection:
	return _storage.copy() if _storage != null else ProfileStorageProjection.new()

func comparison_lines_by_slot(instance_id: String) -> Dictionary:
	return _storage.comparison_lines_by_slot(instance_id) if _storage != null else {}

func _get_active_class_id() -> StringName: return _storage.active_class_id if _storage != null else &""
func _get_leader_slots() -> Array[Dictionary]: return _storage.leader_slots if _storage != null else []
func _get_stash_tabs() -> Array[Dictionary]: return _storage.stash_tabs if _storage != null else []
func _get_terminal_recovery_overflow() -> Dictionary: return _storage.terminal_recovery_overflow if _storage != null else {}
func _get_loadout_empty() -> bool: return _storage == null or _storage.is_loadout_empty()
