extends RefCounted

const CONTROLLER_PATH := "res://scripts/world/ground_item_world_controller.gd"
const MAIN_SCENE_PATH := "res://scenes/game/main.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(CONTROLLER_PATH), "ground-item world controller exists", failures)
	if not ResourceLoader.exists(CONTROLLER_PATH):
		return failures
	var controller_script := load(CONTROLLER_PATH) as Script
	TestAssertions.truthy(controller_script != null, "ground-item world controller loads", failures)
	if controller_script == null:
		return failures
	_test_main_scene_wiring(failures)
	_test_projection_pool_tooltip_and_ownership(controller_script, failures)
	return failures


func _test_main_scene_wiring(failures: Array[String]) -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	var main := packed.instantiate() if packed != null else null
	TestAssertions.truthy(main != null, "main scene remains loadable with world-loot projection nodes", failures)
	if main == null:
		return
	TestAssertions.truthy(main.get_node_or_null("GroundItems") is Node3D, "main owns a dedicated ground-item parent", failures)
	TestAssertions.truthy(main.get_node_or_null("GroundItemWorldController") != null, "main owns one ground-item world controller", failures)
	TestAssertions.truthy(main.get_node_or_null("GroundItemTooltipLayer") is CanvasLayer, "main owns a lightweight screen projection layer", failures)
	TestAssertions.truthy(main.get_node_or_null("GroundItemTooltipLayer/ItemTooltipPanel") is ItemTooltipPanel, "main provides exactly one shared item tooltip", failures)
	main.free()


func _test_projection_pool_tooltip_and_ownership(controller_script: Script, failures: Array[String]) -> void:
	var host := Node.new()
	var chests_parent := Node3D.new()
	var camera := Camera3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(1920.0, 1080.0)
	host.add_child(chests_parent)
	host.add_child(camera)
	host.add_child(tooltip_layer)
	var controller := Node.new()
	controller.set_script(controller_script)
	host.add_child(controller)
	var registry := GroundItemRegistry.new(80)
	var projection_calls := [0]
	var current_stats := ResolvedStatSnapshot.new()
	var candidate_stats := ResolvedStatSnapshot.new()
	current_stats.set_resolved(&"max_health", 100.0, [])
	candidate_stats.set_resolved(&"max_health", 125.0, [])
	var projector := func(record: GroundItemRecord) -> Dictionary:
		projection_calls[0] += 1
		return _detail_for(record, current_stats, candidate_stats)
	var identities := {
		&"player_1": {"player_number": 1, "color_id": &"red", "color": PlayerColorPalette.color(&"red")},
		&"player_2": {"player_number": 2, "color_id": &"blue", "color": PlayerColorPalette.color(&"blue")},
	}
	controller.call(&"configure", registry, identities, projector, camera, chests_parent, tooltip_layer)
	TestAssertions.equal(_tooltip_count(tooltip_layer), 1, "configure creates exactly one shared ItemTooltipPanel", failures)
	var first := _record(&"drop-a", &"player_1", 1, Vector3(3.0, 0.0, 4.0), &"uncommon", &"red")
	var second := _record(&"drop-b", &"player_2", 2, Vector3(0.0, 0.0, 8.0), &"legendary", &"blue")
	TestAssertions.truthy(registry.add(first), "first fixture enters authoritative registry", failures)
	TestAssertions.truthy(registry.add(second), "second fixture enters authoritative registry", failures)
	var active := controller.get("_chest_by_drop") as Dictionary
	TestAssertions.equal(active.size(), 2, "all observers receive one active chest for every owner record", failures)
	TestAssertions.equal(chests_parent.get_child_count(), 2, "two records activate exactly two chest nodes", failures)
	TestAssertions.equal(projection_calls[0], 2, "each new record projects detail exactly once", failures)
	for chest_value: Variant in active.values():
		TestAssertions.truthy((chest_value as Node3D).visible, "other-owner chests stay visible rather than being filtered", failures)
	var second_chest := active[&"drop-b"] as Node3D
	TestAssertions.equal((second_chest.get_node("OwnerMarker/OwnerLabel") as Label3D).text, "P2", "controller binds the identity service player number", failures)
	TestAssertions.equal((second_chest.get_node("OwnerMarker/Pennant") as Label3D).modulate, PlayerColorPalette.color(&"blue"), "controller binds the exact identity color", failures)
	for _index: int in 10:
		controller.call(&"_process", 0.016)
	TestAssertions.equal(projection_calls[0], 2, "ordinary process frames never rebuild cached item detail", failures)
	var first_chest := active[&"drop-a"] as Node3D
	var first_anchor := first_chest.call(&"tooltip_anchor") as Control
	TestAssertions.equal(first_anchor.get_parent(), tooltip_layer, "3D chest projects to a lightweight screen anchor", failures)
	first_anchor.mouse_entered.emit()
	var tooltip := _shared_tooltip(tooltip_layer)
	TestAssertions.truthy(tooltip.visible, "mouse hover opens the shared tooltip", failures)
	TestAssertions.equal(tooltip.card_count(), 1, "hover renders one inspected item card", failures)
	tooltip.set_compare_active(true)
	TestAssertions.equal(tooltip.card_count(), 2, "Alt/LT renders the owning leader applicable-slot comparison", failures)
	tooltip.set_advanced_active(true)
	TestAssertions.truthy(tooltip.comparison_active() and tooltip.advanced_active(), "Alt/LT and Shift/RT use the standard tooltip layers", failures)
	TestAssertions.equal(projection_calls[0], 2, "tooltip layers consume cached detail instead of re-projecting it", failures)
	first_anchor.mouse_exited.emit()
	first_anchor.focus_entered.emit()
	TestAssertions.truthy(tooltip.visible, "controller focus uses the same shared tooltip behavior as hover", failures)
	var forwarded: Array[Array] = []
	controller.connect(&"pickup_requested", func(drop_id: StringName, input_owner: StringName) -> void:
		forwarded.append([drop_id, input_owner])
	)
	first_chest.call(&"request_pickup", &"player_2")
	first_chest.call(&"request_pickup", &"player_1")
	TestAssertions.equal(forwarded, [[&"drop-a", &"player_1"]], "controller forwards pickup only for the record owner", failures)
	var first_instance := first_chest.get_instance_id()
	var removed := registry.remove(&"drop-a")
	TestAssertions.truthy(removed != null, "fixture removes one authoritative record", failures)
	TestAssertions.equal((controller.get("_chest_by_drop") as Dictionary).size(), 1, "remove releases exactly one active chest", failures)
	TestAssertions.equal((controller.get("_inactive_chests") as Array).size(), 1, "removed chest returns to the reusable pool exactly once", failures)
	registry.remove(&"drop-a")
	TestAssertions.equal((controller.get("_inactive_chests") as Array).size(), 1, "duplicate remove cannot return a chest twice", failures)
	var third := _record(&"drop-c", &"player_1", 1, Vector3(6.0, 0.0, 8.0), &"rare", &"red")
	TestAssertions.truthy(registry.add(third), "replacement fixture enters registry", failures)
	var third_chest := (controller.get("_chest_by_drop") as Dictionary)[&"drop-c"] as Node3D
	TestAssertions.equal(third_chest.get_instance_id(), first_instance, "new records reuse an inactive chest before instantiating another", failures)
	TestAssertions.equal(chests_parent.get_child_count(), 2, "reuse preserves one active chest node per record", failures)
	TestAssertions.equal(projection_calls[0], 3, "only the changed record receives fresh detail", failures)
	registry.clear()
	TestAssertions.equal((controller.get("_chest_by_drop") as Dictionary).size(), 0, "registry clear releases every active projection", failures)
	TestAssertions.equal((controller.get("_inactive_chests") as Array).size(), 2, "clear returns every active chest once", failures)
	TestAssertions.truthy(int(controller_script.get_script_constant_map().get("MAX_INACTIVE_CHESTS", 0)) > 0, "controller declares an explicit bounded inactive pool", failures)
	TestAssertions.truthy((controller.get("_inactive_chests") as Array).size() <= int(controller_script.get_script_constant_map().get("MAX_INACTIVE_CHESTS", 0)), "inactive pool stays within its bound", failures)
	tooltip.force_dismiss()
	host.free()
	RenderingServer.force_sync()


func _detail_for(record: GroundItemRecord, current_stats: ResolvedStatSnapshot, candidate_stats: ResolvedStatSnapshot) -> Dictionary:
	return {
		"instance_id": record.item_id,
		"name": "Projected %s" % record.item_id,
		"rarity_id": String(record.rarity_id),
		"rarity_name": String(record.rarity_id).capitalize(),
		"item_level": 22,
		"compatible_slot_ids": ["ring_left"],
		"affixes": [{"display_name": "Stout", "tier": 2, "rolls": []}],
		"modifier_totals": {"max_health|0": 25.0},
		"owner_leader_equipment": [{
			"slot_id": "ring_left",
			"item": {
				"instance_id": "equipped-ring",
				"name": "Equipped Ring",
				"rarity_id": "common",
				"rarity_name": "Common",
				"item_level": 10,
				"affixes": [],
				"modifier_totals": {},
			},
			"current_stats": current_stats,
			"candidate_stats": candidate_stats,
		}],
	}


func _record(drop_id: StringName, owner_id: StringName, player_number: int, position: Vector3, rarity_id: StringName, color_id: StringName) -> GroundItemRecord:
	var record := GroundItemRecord.new()
	record.drop_id = drop_id
	record.item_id = "item-%s" % drop_id
	record.run_player_id = owner_id
	record.profile_id = "profile-%s" % owner_id
	record.player_number = player_number
	record.color_id = color_id
	record.world_position = position
	record.rarity_id = rarity_id
	record.source_id = &"test-source"
	record.ground_slot = player_number - 1
	return record


func _tooltip_count(root: Node) -> int:
	var count := 0
	for child: Node in root.get_children():
		if child is ItemTooltipPanel:
			count += 1
	return count


func _shared_tooltip(root: Node) -> ItemTooltipPanel:
	for child: Node in root.get_children():
		if child is ItemTooltipPanel:
			return child as ItemTooltipPanel
	return null
