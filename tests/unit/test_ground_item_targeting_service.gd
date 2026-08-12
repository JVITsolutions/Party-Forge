extends RefCounted

const INDEX_PATH := "res://scripts/loot/ground_item_spatial_index.gd"
const TARGETING_PATH := "res://scripts/loot/ground_item_targeting_service.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	for path: String in [INDEX_PATH, TARGETING_PATH]:
		TestAssertions.truthy(ResourceLoader.exists(path), "%s exists" % path.get_file(), failures)
	if failures.size() > 0:
		return failures
	var registry := GroundItemRegistry.new()
	var index := (load(INDEX_PATH) as Script).new(registry, 4.0) as RefCounted
	var targeting := (load(TARGETING_PATH) as Script).new() as RefCounted
	registry.add(_record(&"drop-b", &"player_1", Vector3(-2.0, 0.0, 0.0), 0))
	registry.add(_record(&"drop-a", &"player_1", Vector3(2.0, 0.0, 0.0), 1))
	registry.add(_record(&"drop-nearest", &"player_1", Vector3(1.0, 0.0, 0.0), 2))
	registry.add(_record(&"drop-hidden", &"player_1", Vector3(0.5, 0.0, 0.0), 3))
	registry.add(_record(&"drop-far", &"player_1", Vector3(20.0, 0.0, 0.0), 4))
	registry.add(_record(&"drop-foreign", &"player_2", Vector3(0.25, 0.0, 0.0), 0))
	var visible := func(record: GroundItemRecord) -> bool: return record.drop_id != &"drop-hidden"
	var ordered := targeting.call(&"ordered_for_owner", index, &"player_1", Vector3.ZERO, 5.0, visible) as Array
	TestAssertions.equal(_ids(ordered), [&"drop-nearest", &"drop-a", &"drop-b"], "ordering is squared distance then stable drop ID and excludes hidden far foreign records", failures)
	TestAssertions.equal(targeting.call(&"cycle", &"drop-nearest", 1, index, &"player_1", Vector3.ZERO, 5.0, visible), &"drop-a", "cycle advances in ordered owner set", failures)
	TestAssertions.equal(targeting.call(&"cycle", &"drop-b", 1, index, &"player_1", Vector3.ZERO, 5.0, visible), &"drop-nearest", "cycle wraps forward", failures)
	TestAssertions.equal(targeting.call(&"cycle", &"drop-nearest", -1, index, &"player_1", Vector3.ZERO, 5.0, visible), &"drop-b", "cycle wraps backward", failures)
	TestAssertions.equal(targeting.call(&"cycle", &"drop-foreign", 1, index, &"player_1", Vector3.ZERO, 5.0, visible), &"drop-nearest", "foreign current target never enters the owner cycle", failures)
	index.call(&"dispose")
	var precision_registry := GroundItemRegistry.new()
	var precision_index := (load(INDEX_PATH) as Script).new(precision_registry, 4.0) as RefCounted
	precision_registry.add(_record(&"z-closer", &"player_1", Vector3(1.000001, 0.0, 0.0), 0))
	precision_registry.add(_record(&"a-farther", &"player_1", Vector3(1.000002, 0.0, 0.0), 1))
	TestAssertions.equal(_ids(targeting.call(&"ordered_for_owner", precision_index, &"player_1", Vector3.ZERO, 5.0, Callable()) as Array), [&"z-closer", &"a-farther"], "distinct squared distances sort numerically before drop ID", failures)
	precision_index.call(&"dispose")
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
	return result
