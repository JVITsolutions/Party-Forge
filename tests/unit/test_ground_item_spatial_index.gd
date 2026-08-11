extends RefCounted

const INDEX_PATH := "res://scripts/loot/ground_item_spatial_index.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(INDEX_PATH), "ground-item spatial index exists", failures)
	if not ResourceLoader.exists(INDEX_PATH):
		return failures
	var script := load(INDEX_PATH) as Script
	TestAssertions.truthy(script != null, "ground-item spatial index loads", failures)
	if script == null:
		return failures
	var registry := GroundItemRegistry.new()
	var index := script.new(registry, 4.0) as RefCounted
	TestAssertions.truthy(registry.add(_record(&"west", &"player_1", Vector3(3.99, 0.0, 0.0), 0)), "west boundary fixture registers", failures)
	TestAssertions.truthy(registry.add(_record(&"east", &"player_1", Vector3(4.01, 0.0, 0.0), 1)), "east boundary fixture registers", failures)
	TestAssertions.truthy(registry.add(_record(&"foreign", &"player_2", Vector3(4.0, 0.0, 0.0), 0)), "foreign fixture registers", failures)
	TestAssertions.equal(_ids(index.call(&"query", &"player_1", Vector3(4.0, 0.0, 0.0), 0.02)), [&"east", &"west"], "bounded query crosses adjacent spatial cells", failures)
	TestAssertions.equal(_ids(index.call(&"query", &"player_2", Vector3(4.0, 0.0, 0.0), 0.02)), [&"foreign"], "owner buckets stay isolated", failures)
	registry.remove(&"west")
	TestAssertions.equal(_ids(index.call(&"query", &"player_1", Vector3(4.0, 0.0, 0.0), 1.0)), [&"east"], "registry remove incrementally removes the indexed record", failures)
	registry.clear()
	TestAssertions.equal(index.call(&"query", &"player_1", Vector3.ZERO, 100.0), [], "registry clear empties every spatial bucket", failures)
	index.call(&"dispose")
	return failures

func _record(drop_id: StringName, owner: StringName, position: Vector3, slot: int) -> GroundItemRecord:
	var record := GroundItemRecord.new()
	record.drop_id = drop_id
	record.item_id = "item-%s" % drop_id
	record.run_player_id = owner
	record.profile_id = "profile-%s" % owner
	record.player_number = 1 if owner == &"player_1" else 2
	record.color_id = &"red" if owner == &"player_1" else &"blue"
	record.world_position = position
	record.rarity_id = &"common"
	record.source_id = &"test"
	record.ground_slot = slot
	return record

func _ids(records: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for record: GroundItemRecord in records:
		result.append(record.drop_id)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result
