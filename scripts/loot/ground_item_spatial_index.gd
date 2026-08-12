class_name GroundItemSpatialIndex
extends RefCounted

const DEFAULT_CELL_SIZE := 8.0

var cell_size := DEFAULT_CELL_SIZE
var _registry: GroundItemRegistry
var _buckets_by_owner: Dictionary = {}
var _location_by_drop: Dictionary = {}

func _init(registry: GroundItemRegistry = null, cell_size_value: float = DEFAULT_CELL_SIZE) -> void:
	cell_size = maxf(cell_size_value, 0.001)
	configure(registry)

func configure(registry: GroundItemRegistry) -> void:
	dispose()
	_registry = registry
	if _registry == null:
		return
	_registry.record_added.connect(_on_record_added)
	_registry.record_removed.connect(_on_record_removed)
	_registry.cleared.connect(_on_cleared)
	for record: GroundItemRecord in _registry.all_records():
		_on_record_added(record)

func query(run_player_id: StringName, center: Vector3, radius: float) -> Array[GroundItemRecord]:
	var result: Array[GroundItemRecord] = []
	if run_player_id.is_empty() or radius < 0.0:
		return result
	var owner_buckets := _buckets_by_owner.get(run_player_id, {}) as Dictionary
	if owner_buckets.is_empty():
		return result
	var minimum := _cell_for(center - Vector3(radius, 0.0, radius))
	var maximum := _cell_for(center + Vector3(radius, 0.0, radius))
	for cell_x: int in range(minimum.x, maximum.x + 1):
		for cell_y: int in range(minimum.y, maximum.y + 1):
			var bucket := owner_buckets.get(Vector2i(cell_x, cell_y), {}) as Dictionary
			for value: Variant in bucket.values():
				result.append((value as GroundItemRecord).copy())
	return result

func dispose() -> void:
	if _registry != null:
		if _registry.record_added.is_connected(_on_record_added):
			_registry.record_added.disconnect(_on_record_added)
		if _registry.record_removed.is_connected(_on_record_removed):
			_registry.record_removed.disconnect(_on_record_removed)
		if _registry.cleared.is_connected(_on_cleared):
			_registry.cleared.disconnect(_on_cleared)
	_registry = null
	_buckets_by_owner.clear()
	_location_by_drop.clear()

func _on_record_added(record: GroundItemRecord) -> void:
	if record == null or record.drop_id.is_empty() or record.run_player_id.is_empty():
		return
	var cell := _cell_for(record.world_position)
	var owner_buckets := _buckets_by_owner.get_or_add(record.run_player_id, {}) as Dictionary
	var bucket := owner_buckets.get_or_add(cell, {}) as Dictionary
	bucket[record.drop_id] = record.copy()
	_location_by_drop[record.drop_id] = {"owner": record.run_player_id, "cell": cell}

func _on_record_removed(record: GroundItemRecord) -> void:
	if record == null:
		return
	var location := _location_by_drop.get(record.drop_id, {}) as Dictionary
	if location.is_empty():
		return
	var owner := StringName(location["owner"])
	var cell := location["cell"] as Vector2i
	var owner_buckets := _buckets_by_owner.get(owner, {}) as Dictionary
	var bucket := owner_buckets.get(cell, {}) as Dictionary
	bucket.erase(record.drop_id)
	if bucket.is_empty():
		owner_buckets.erase(cell)
	if owner_buckets.is_empty():
		_buckets_by_owner.erase(owner)
	_location_by_drop.erase(record.drop_id)

func _on_cleared() -> void:
	_buckets_by_owner.clear()
	_location_by_drop.clear()

func _cell_for(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.z / cell_size))
