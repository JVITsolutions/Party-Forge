extends SceneTree

const SINGLE_ROOT := "user://task10_item_storage_performance_single"
const MULTI_ROOT := "user://task10_item_storage_performance_multi"
const ITEM_COUNT := 99
const PROFILE_COUNT := 4
const REGRESSION_CEILING_MS := 15000.0
const REGRESSION_CEILING_BYTES := 8 * 1024 * 1024

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_cleanup()
	var single := _measure_profile("profile-task10-single", SINGLE_ROOT, 0)
	_assert(String(single.get("error", "")).is_empty(), "single-profile canonical measurement succeeds: %s" % single.get("error", ""))
	_assert(int(single.get("instances", -1)) == ITEM_COUNT, "single profile validates exactly 99 instances")
	_assert(int(single.get("containers", -1)) == 1, "single profile validates exactly one storage container")
	_assert(int(single.get("encoded_bytes", -1)) > 0, "single profile records positive encoded bytes")
	_assert_metrics(single, "single profile")

	var measured: Array[Dictionary] = []
	var all_item_owners: Dictionary = {}
	var total_items := 0
	var total_containers := 0
	var total_bytes := 0
	var total_ms := 0.0
	for index: int in PROFILE_COUNT:
		var profile_id := "profile-task10-perf-%d" % (index + 1)
		var metric := _measure_profile(profile_id, MULTI_ROOT, 1000 + index)
		measured.append(metric)
		_assert(String(metric.get("error", "")).is_empty(), "profile %d canonical measurement succeeds: %s" % [index + 1, metric.get("error", "")])
		_assert_metrics(metric, "profile %d" % (index + 1))
		total_items += int(metric.get("instances", 0))
		total_containers += int(metric.get("containers", 0))
		total_bytes += int(metric.get("encoded_bytes", 0))
		total_ms += _metric_total_ms(metric)
		for item_id: String in metric.get("item_ids", [] as Array[String]):
			_assert(not all_item_owners.has(item_id), "item instance %s does not cross profile domains" % item_id)
			all_item_owners[item_id] = profile_id
	_assert(measured.size() == PROFILE_COUNT, "four independent profile domains are measured")
	_assert(total_items == PROFILE_COUNT * ITEM_COUNT, "four profiles validate exactly 396 instances")
	_assert(total_containers == PROFILE_COUNT, "four profiles validate exactly four owner-bound containers")
	_assert(all_item_owners.size() == PROFILE_COUNT * ITEM_COUNT, "all 396 item IDs are globally unique across measured profiles")
	_assert(total_bytes > 0 and total_bytes <= REGRESSION_CEILING_BYTES, "aggregate encoded bytes remain within the 8 MiB regression ceiling")
	_assert(is_finite(total_ms) and total_ms >= 0.0 and total_ms <= REGRESSION_CEILING_MS, "aggregate canonical work remains within the 15000 ms headless regression ceiling")
	var single_bytes := int(single.get("encoded_bytes", 0))
	if single_bytes > 0:
		_assert(total_bytes <= single_bytes * (PROFILE_COUNT + 1), "four-profile encoded growth remains close to linear from the one-profile baseline")

	print("ITEM_STORAGE_PERFORMANCE_ONE profile=1 items=%d containers=%d encode_ms=%.3f decode_ms=%.3f validate_ms=%.3f save_ms=%.3f reload_ms=%.3f bytes=%d" % [
		int(single.get("instances", 0)),
		int(single.get("containers", 0)),
		float(single.get("encode_ms", 0.0)),
		float(single.get("decode_ms", 0.0)),
		float(single.get("validate_ms", 0.0)),
		float(single.get("save_ms", 0.0)),
		float(single.get("reload_ms", 0.0)),
		int(single.get("encoded_bytes", 0)),
	])
	print("ITEM_STORAGE_PERFORMANCE_FOUR profiles=4 items=%d containers=%d elapsed_ms=%.3f bytes=%d ceiling_ms=%.0f ceiling_bytes=%d headless_regression_only=true" % [
		total_items,
		total_containers,
		total_ms,
		total_bytes,
		REGRESSION_CEILING_MS,
		REGRESSION_CEILING_BYTES,
	])
	if _failures.is_empty():
		print("ITEM_STORAGE_PERFORMANCE_SUMMARY: PASS profiles=4 items=396")
		_cleanup()
		quit(0)
		return
	for failure: String in _failures:
		push_error("ITEM_STORAGE_PERFORMANCE_FAILURE: %s" % failure)
	print("ITEM_STORAGE_PERFORMANCE_SUMMARY: FAIL (%d failures)" % _failures.size())
	_cleanup()
	quit(1)


func _measure_profile(profile_id: String, root_path: String, seed_offset: int) -> Dictionary:
	var built := _build_profile(profile_id, seed_offset)
	var build_error := String(built.get("error", ""))
	if not build_error.is_empty():
		return {"error": build_error}
	var profile := built["profile"] as ProfileState
	var started := Time.get_ticks_usec()
	var encoded := ProfileCodec.encode(profile)
	var encode_ms := _elapsed_ms(started)
	started = Time.get_ticks_usec()
	var decoded := ProfileCodec.decode(encoded)
	var decode_ms := _elapsed_ms(started)
	if not decoded.ok():
		return {"error": decoded.error}
	started = Time.get_ticks_usec()
	var validation_error := ProfileCodec.validate_profile(decoded.profile)
	var validate_ms := _elapsed_ms(started)
	if not validation_error.is_empty():
		return {"error": validation_error}
	var store := ProfileStore.new()
	started = Time.get_ticks_usec()
	var save_error := store.save_profile(decoded.profile, root_path)
	var save_ms := _elapsed_ms(started)
	if not save_error.is_empty():
		return {"error": save_error}
	started = Time.get_ticks_usec()
	var loaded := store.load_profile(profile_id, root_path)
	var reload_ms := _elapsed_ms(started)
	if not loaded.ok():
		return {"error": loaded.error}
	var ownership := ItemOwnershipState.decode(
		{
			"schema_version": ItemOwnershipState.SCHEMA_VERSION,
			"owner_id": loaded.profile.profile_id,
			"registry": loaded.profile.item_records.duplicate(true),
			"containers": loaded.profile.stash_tabs.duplicate(true),
		},
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG
	)
	if not ownership.ok():
		return {"error": ownership.error}
	var registry := ownership.state.registry()
	var containers := ownership.state.containers()
	if ownership.state.owner_id != profile_id:
		return {"error": "ownership owner mismatch for %s" % profile_id}
	for container: ItemSlotContainer in containers:
		if container.owner_id != profile_id:
			return {"error": "container %s crosses owner boundary" % container.container_id}
		for slot: int in container.occupied_slots():
			if not registry.has(container.item_id_at(slot)):
				return {"error": "container %s references a foreign item" % container.container_id}
	if loaded.profile.to_dictionary() != decoded.profile.to_dictionary():
		return {"error": "atomic save/reload changed canonical profile %s" % profile_id}
	return {
		"profile_id": profile_id,
		"instances": registry.size(),
		"containers": containers.size(),
		"item_ids": registry.ids(),
		"encoded_bytes": encoded.to_utf8_buffer().size(),
		"encode_ms": encode_ms,
		"decode_ms": decode_ms,
		"validate_ms": validate_ms,
		"save_ms": save_ms,
		"reload_ms": reload_ms,
		"error": "",
	}


func _build_profile(profile_id: String, seed_offset: int) -> Dictionary:
	var items: Array[ItemInstance] = []
	var slots: Dictionary = {}
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	var foundation := GameCatalog.ITEM_FOUNDATION_CATALOG
	if equipment.definitions.size() != ITEM_COUNT:
		return {"error": "equipment catalog must contain exactly 99 definitions"}
	for index: int in equipment.definitions.size():
		var definition := equipment.definitions[index]
		var issued := ItemInstanceIssuer.issue(
			"profile:%s" % profile_id,
			index,
			"task10_performance_fixture",
			seed_offset + index,
			{
				"affixes": [],
				"base_definition_id": String(definition.id),
				"item_level": 1 + (index % 100),
				"rarity_id": "common",
			},
			equipment,
			foundation
		)
		if not issued.ok():
			return {"error": issued.error}
		items.append(issued.item)
		slots[index] = issued.item.instance_id
	var profile := ProfileState.new_profile(profile_id, "Task 10 Performance", 1000 + seed_offset)
	profile.item_records = ItemRegistry.new(items).to_dictionary()
	profile.stash_tabs = [ItemSlotContainer.create(
		&"stash-tab-000",
		ItemSlotContainer.PROFILE_STASH_TAB,
		profile_id,
		ItemSlotContainer.STASH_CAPACITY,
		slots
	).to_dictionary()]
	profile.next_item_sequence = ITEM_COUNT
	var validation_error := ProfileCodec.validate_profile(profile)
	return {"profile": profile, "error": validation_error}


func _assert_metrics(metric: Dictionary, label: String) -> void:
	for key: String in ["encode_ms", "decode_ms", "validate_ms", "save_ms", "reload_ms"]:
		var value := float(metric.get(key, -1.0))
		_assert(is_finite(value) and value >= 0.0, "%s records finite nonnegative %s" % [label, key])


func _metric_total_ms(metric: Dictionary) -> float:
	return (
		float(metric.get("encode_ms", 0.0))
		+ float(metric.get("decode_ms", 0.0))
		+ float(metric.get("validate_ms", 0.0))
		+ float(metric.get("save_ms", 0.0))
		+ float(metric.get("reload_ms", 0.0))
	)


func _elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _cleanup() -> void:
	ProfileTestSupport.remove_tree(SINGLE_ROOT)
	ProfileTestSupport.remove_tree(MULTI_ROOT)
