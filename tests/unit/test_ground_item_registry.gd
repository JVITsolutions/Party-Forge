extends RefCounted

const RECORD_PATH := "res://scripts/loot/ground_item_record.gd"
const REGISTRY_PATH := "res://scripts/loot/ground_item_registry.gd"

var _record_script: Script
var _registry_script: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	_load_contracts(failures)
	if _record_script == null or _registry_script == null:
		return failures
	_test_duplicate_identity_rejection(failures)
	_test_stable_owner_queries_and_outward_copies(failures)
	_test_signals_removal_and_session_clear(failures)
	return failures

func _load_contracts(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(RECORD_PATH), "ground item record script exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(REGISTRY_PATH), "ground item registry script exists", failures)
	if ResourceLoader.exists(RECORD_PATH):
		_record_script = load(RECORD_PATH) as Script
	if ResourceLoader.exists(REGISTRY_PATH):
		_registry_script = load(REGISTRY_PATH) as Script
	TestAssertions.truthy(_record_script != null, "ground item record script loads", failures)
	TestAssertions.truthy(_registry_script != null, "ground item registry script loads", failures)

func _test_duplicate_identity_rejection(failures: Array[String]) -> void:
	var registry := _registry_script.new() as RefCounted
	var first := _record(&"drop:alpha:7", "item-alpha", &"alpha", 2, Vector3(2.0, 0.0, 1.0))
	TestAssertions.truthy(bool(registry.call(&"add", first)), "first unique ground record is accepted", failures)
	TestAssertions.truthy(
		not bool(registry.call(&"add", _record(&"drop:alpha:7", "item-beta", &"alpha", 3, Vector3.ZERO))),
		"duplicate drop ID is rejected",
		failures,
	)
	TestAssertions.truthy(
		not bool(registry.call(&"add", _record(&"drop:beta:7", "item-alpha", &"beta", 4, Vector3.ZERO))),
		"duplicate item ID is rejected",
		failures,
	)
	TestAssertions.equal((registry.call(&"all_records") as Array).size(), 1, "duplicate rejection preserves the original record count", failures)
	TestAssertions.equal((registry.call(&"record", &"drop:alpha:7") as RefCounted).get(&"item_id"), "item-alpha", "duplicate rejection preserves original identity", failures)

func _test_stable_owner_queries_and_outward_copies(failures: Array[String]) -> void:
	var registry := _registry_script.new() as RefCounted
	registry.call(&"add", _record(&"drop:alpha:9", "item-z", &"alpha", 9, Vector3(9.0, 0.0, 0.0)))
	registry.call(&"add", _record(&"drop:beta:2", "item-b", &"beta", 2, Vector3(2.0, 0.0, 0.0)))
	registry.call(&"add", _record(&"drop:alpha:1", "item-a", &"alpha", 1, Vector3(1.0, 0.0, 0.0)))

	var owned := registry.call(&"for_owner", &"alpha") as Array
	TestAssertions.equal(_drop_ids(owned), PackedStringArray(["drop:alpha:1", "drop:alpha:9"]), "owner query is sorted by stable drop ID", failures)
	(owned[0] as RefCounted).set(&"item_id", "escaped-mutation")
	owned.clear()
	var second := registry.call(&"for_owner", &"alpha") as Array
	TestAssertions.equal(second.size(), 2, "mutating an owner result array cannot alter registry membership", failures)
	TestAssertions.equal((second[0] as RefCounted).get(&"item_id"), "item-a", "mutating an owner record copy cannot alter registry state", failures)

	var direct := registry.call(&"record", &"drop:alpha:1") as RefCounted
	direct.set(&"world_position", Vector3(99.0, 99.0, 99.0))
	TestAssertions.equal(
		(registry.call(&"record", &"drop:alpha:1") as RefCounted).get(&"world_position"),
		Vector3(1.0, 0.0, 0.0),
		"direct lookup returns an outward copy",
		failures,
	)
	TestAssertions.equal(
		_drop_ids(registry.call(&"all_records") as Array),
		PackedStringArray(["drop:alpha:1", "drop:alpha:9", "drop:beta:2"]),
		"all-record projection has stable drop-ID order",
		failures,
	)

func _test_signals_removal_and_session_clear(failures: Array[String]) -> void:
	var registry := _registry_script.new() as RefCounted
	var added := PackedStringArray()
	var removed := PackedStringArray()
	var clear_count := [0]
	registry.connect(&"record_added", func(record: RefCounted) -> void: added.append(String(record.get(&"drop_id"))))
	registry.connect(&"record_removed", func(record: RefCounted) -> void: removed.append(String(record.get(&"drop_id"))))
	registry.connect(&"cleared", func() -> void: clear_count[0] += 1)
	registry.call(&"add", _record(&"drop:alpha:3", "item-c", &"alpha", 3, Vector3.ZERO))
	registry.call(&"add", _record(&"drop:beta:4", "item-d", &"beta", 4, Vector3.ZERO))
	var removed_record := registry.call(&"remove", &"drop:alpha:3") as RefCounted
	TestAssertions.equal(removed_record.get(&"item_id"), "item-c", "remove returns the removed record copy", failures)
	removed_record.set(&"item_id", "mutated-after-remove")
	TestAssertions.equal(added, PackedStringArray(["drop:alpha:3", "drop:beta:4"]), "accepted records each emit one add signal", failures)
	TestAssertions.equal(removed, PackedStringArray(["drop:alpha:3"]), "accepted removal emits the removed record identity", failures)
	registry.call(&"clear")
	TestAssertions.equal((registry.call(&"all_records") as Array).size(), 0, "clear discards only the registry session projection", failures)
	TestAssertions.equal(clear_count[0], 1, "clear emits once for a populated session registry", failures)

func _record(drop_id: StringName, item_id: String, owner: StringName, slot: int, position: Vector3) -> RefCounted:
	var record := _record_script.new() as RefCounted
	record.set(&"drop_id", drop_id)
	record.set(&"item_id", item_id)
	record.set(&"run_player_id", owner)
	record.set(&"profile_id", "profile-%s" % owner)
	record.set(&"player_number", 1)
	record.set(&"color_id", &"red")
	record.set(&"world_position", position)
	record.set(&"rarity_id", &"common")
	record.set(&"source_id", &"ordinary_enemy")
	record.set(&"ground_slot", slot)
	return record

func _drop_ids(records: Array) -> PackedStringArray:
	var ids := PackedStringArray()
	for record: RefCounted in records:
		ids.append(String(record.get(&"drop_id")))
	return ids
