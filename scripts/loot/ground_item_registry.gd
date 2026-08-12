class_name GroundItemRegistry
extends RefCounted

signal record_added(record: GroundItemRecord)
signal record_removed(record: GroundItemRecord)
signal cleared

const DEFAULT_CAPACITY := ItemSlotContainer.RUN_GROUND_ITEMS_CAPACITY * LocalPlayerIdentityService.MAX_LOCAL_PLAYERS

var capacity := DEFAULT_CAPACITY
var _by_drop_id: Dictionary = {}
var _drop_id_by_item_id: Dictionary = {}

func _init(capacity_value: int = DEFAULT_CAPACITY) -> void:
	capacity = maxi(capacity_value, 0)

func add(record_value: GroundItemRecord) -> bool:
	if not _preflight(record_value).is_empty():
		return false
	_commit_prevalidated(record_value)
	return true

func remove(drop_id: StringName) -> GroundItemRecord:
	var stored := _by_drop_id.get(drop_id) as GroundItemRecord
	if stored == null:
		return null
	_by_drop_id.erase(drop_id)
	_drop_id_by_item_id.erase(stored.item_id)
	var outward := stored.copy()
	record_removed.emit(outward.copy())
	return outward

func record(drop_id: StringName) -> GroundItemRecord:
	var stored := _by_drop_id.get(drop_id) as GroundItemRecord
	return stored.copy() if stored != null else null

func for_owner(run_player_id: StringName) -> Array[GroundItemRecord]:
	var result: Array[GroundItemRecord] = []
	for drop_id: StringName in _sorted_drop_ids():
		var stored := _by_drop_id[drop_id] as GroundItemRecord
		if stored.run_player_id == run_player_id:
			result.append(stored.copy())
	return result

func all_records() -> Array[GroundItemRecord]:
	var result: Array[GroundItemRecord] = []
	for drop_id: StringName in _sorted_drop_ids():
		result.append((_by_drop_id[drop_id] as GroundItemRecord).copy())
	return result

func clear() -> void:
	if _by_drop_id.is_empty():
		return
	_by_drop_id.clear()
	_drop_id_by_item_id.clear()
	cleared.emit()

func _preflight(record_value: GroundItemRecord) -> String:
	if record_value == null:
		return _error("record", "must not be null")
	var identity_error := _preflight_identity(record_value.drop_id, record_value.item_id)
	if not identity_error.is_empty():
		return identity_error
	if record_value.run_player_id.is_empty():
		return _error("run_player_id", "must not be empty")
	if record_value.profile_id.strip_edges().is_empty():
		return _error("profile_id", "must not be empty")
	if record_value.player_number < 1 or record_value.player_number > LocalPlayerIdentityService.MAX_LOCAL_PLAYERS:
		return _error("player_number", "must identify P1-P4")
	if not PlayerColorPalette.is_valid(record_value.color_id):
		return _error("color_id", "must be a supported player color")
	if not _finite_position(record_value.world_position):
		return _error("world_position", "must be finite")
	if record_value.rarity_id.is_empty():
		return _error("rarity_id", "must not be empty")
	if record_value.source_id.is_empty():
		return _error("source_id", "must not be empty")
	if record_value.ground_slot < 0 or record_value.ground_slot >= ItemSlotContainer.RUN_GROUND_ITEMS_CAPACITY:
		return _error("ground_slot", "must be within the run ground container")
	return ""

func _preflight_identity(drop_id: StringName, item_id: String) -> String:
	if drop_id.is_empty():
		return _error("drop_id", "must not be empty")
	if item_id.strip_edges().is_empty():
		return _error("item_id", "must not be empty")
	if _by_drop_id.size() >= capacity:
		return _error("capacity", "registry is full")
	if _by_drop_id.has(drop_id):
		return _error("drop_id", "duplicate %s" % drop_id)
	if _drop_id_by_item_id.has(item_id):
		return _error("item_id", "duplicate %s" % item_id)
	return ""

func _commit_prevalidated(record_value: GroundItemRecord) -> void:
	var owned := record_value.copy()
	_by_drop_id[owned.drop_id] = owned
	_drop_id_by_item_id[owned.item_id] = owned.drop_id
	record_added.emit(owned.copy())

func _sorted_drop_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in _by_drop_id:
		result.append(StringName(value))
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result

func _finite_position(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_GROUND_ITEM_REGISTRY_ERROR field=%s reason=%s" % [field, reason]
