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
	_test_bounded_camera_reprojection(controller_script, failures)
	_test_modal_anchor_transition_bounds(controller_script, failures)
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
	host.name = "GroundItemWorldControllerTestHost"
	var chests_parent := Node3D.new()
	chests_parent.name = "FirstChests"
	var camera := Camera3D.new()
	camera.name = "Camera"
	var tooltip_layer := Control.new()
	tooltip_layer.name = "FirstTooltipLayer"
	tooltip_layer.size = Vector2(1920.0, 1080.0)
	host.add_child(chests_parent)
	host.add_child(camera)
	host.add_child(tooltip_layer)
	var controller := Node.new()
	controller.set_script(controller_script)
	host.add_child(controller)
	var registry := GroundItemRegistry.new(80)
	var projection_calls := [0]
	var comparison_state: Array = [[_comparison_entry("equipped-ring-v1", 100.0, 125.0)]]
	var projector := func(record: GroundItemRecord) -> Dictionary:
		projection_calls[0] += 1
		return _detail_for(record)
	var comparison_projector := func(_record: GroundItemRecord, _detail: Dictionary) -> Array:
		return comparison_state[0] as Array
	var identities := {
		&"player_1": {"player_number": 1, "color_id": &"red", "color": PlayerColorPalette.color(&"red")},
		&"player_2": {"player_number": 2, "color_id": &"blue", "color": PlayerColorPalette.color(&"blue")},
	}
	controller.call(&"configure", registry, identities, projector, camera, chests_parent, tooltip_layer)
	TestAssertions.truthy((controller.get("_controller_focus_by_drop") as Dictionary).is_empty(), "configure starts with no retained controller-focus provenance", failures)
	TestAssertions.truthy(controller.has_method(&"configure_comparisons"), "controller accepts a dedicated production comparison projector", failures)
	if controller.has_method(&"configure_comparisons"):
		controller.call(&"configure_comparisons", comparison_projector)
	TestAssertions.equal(_tooltip_count(tooltip_layer), 1, "configure creates exactly one shared ItemTooltipPanel", failures)
	var first := _record(&"drop-a", &"player_1", 1, Vector3(3.0, 0.0, -4.0), &"uncommon", &"red")
	var second := _record(&"drop-b", &"player_2", 2, Vector3(0.0, 0.0, -8.0), &"legendary", &"blue")
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
	controller.call(&"_process", 0.016)
	TestAssertions.equal(projection_calls[0], 2, "ordinary process frames never rebuild cached item detail", failures)
	var first_chest := active[&"drop-a"] as Node3D
	TestAssertions.truthy(not (controller.get("_detail_by_drop") as Dictionary)[&"drop-a"].has("owner_leader_equipment"), "cached item detail contains no synthetic comparison-only field", failures)
	var first_anchor := first_chest.call(&"tooltip_anchor") as Control
	TestAssertions.equal(first_anchor.get_parent(), tooltip_layer, "3D chest projects to a lightweight screen anchor", failures)
	var anchor_before_camera_move := first_anchor.position
	camera.position = Vector3(1.0, 0.0, 0.0)
	controller.call(&"_process", 0.016)
	TestAssertions.truthy(first_anchor.position != anchor_before_camera_move, "camera transform changes immediately reproject the screen anchor", failures)
	TestAssertions.truthy(first_anchor.accessibility_name.contains("4.5 m"), "camera transform changes refresh accessibility distance", failures)
	TestAssertions.equal(projection_calls[0], 2, "camera motion never rebuilds cached item detail", failures)
	var anchor_before_projection_change := first_anchor.position
	camera.fov = 40.0
	controller.call(&"_process", 0.016)
	TestAssertions.truthy(first_anchor.position != anchor_before_projection_change, "camera projection changes immediately reproject the screen anchor", failures)
	TestAssertions.equal(projection_calls[0], 2, "camera projection changes never rebuild cached item detail", failures)
	camera.position = Vector3.ZERO
	camera.fov = 75.0
	controller.call(&"_process", 0.016)
	var tooltip := _shared_tooltip(tooltip_layer)

	# Mouse exit cannot dismiss while keyboard/controller focus still owns inspection.
	first_anchor.mouse_entered.emit()
	TestAssertions.truthy(tooltip.visible, "mouse hover opens the shared tooltip", failures)
	TestAssertions.equal(tooltip.card_count(), 1, "hover renders one inspected item card", failures)
	TestAssertions.truthy(not tooltip.get_global_rect().intersects(first_anchor.get_global_rect()), "shared tooltip sits beside the projected chest anchor when viewport space permits", failures)
	first_anchor.focus_entered.emit()
	first_anchor.mouse_exited.emit()
	tooltip.call(&"_process", 0.20)
	TestAssertions.truthy(tooltip.visible, "mouse exit preserves tooltip while the same anchor remains focused", failures)
	first_anchor.focus_exited.emit()
	tooltip.call(&"_process", 0.20)
	TestAssertions.truthy(not tooltip.visible, "tooltip dismisses after both mouse and focus leave", failures)

	# Focus exit cannot dismiss while the mouse still owns inspection.
	first_anchor.focus_entered.emit()
	first_anchor.mouse_entered.emit()
	first_anchor.focus_exited.emit()
	tooltip.call(&"_process", 0.20)
	TestAssertions.truthy(tooltip.visible, "focus exit preserves tooltip while the same anchor remains hovered", failures)
	first_anchor.mouse_exited.emit()
	tooltip.call(&"_process", 0.20)
	TestAssertions.truthy(not tooltip.visible, "tooltip dismisses after the remaining mouse inspection leaves", failures)

	# Comparisons resolve against current owning-leader state when inspection is invoked.
	first_anchor.mouse_entered.emit()
	tooltip.set_compare_active(true)
	TestAssertions.equal(tooltip.card_count(), 2, "Alt/LT renders the owning leader applicable-slot comparison", failures)
	TestAssertions.equal(_comparison_card_instance_id(tooltip), "equipped-ring-v1", "initial Alt/LT comparison uses the current owning leader item", failures)
	comparison_state[0] = [_comparison_entry("equipped-ring-v2", 110.0, 140.0)]
	var projection_calls_before_invalidation := int(projection_calls[0])
	TestAssertions.truthy(controller.has_method(&"invalidate_comparisons"), "controller exposes explicit live-comparison invalidation", failures)
	if controller.has_method(&"invalidate_comparisons"):
		controller.call(&"invalidate_comparisons", &"player_1")
	tooltip.set_compare_active(true)
	TestAssertions.equal(_comparison_card_instance_id(tooltip), "equipped-ring-v2", "invalidation refreshes Alt/LT against changed owning leader equipment and stats", failures)
	TestAssertions.truthy(projection_calls[0] > projection_calls_before_invalidation, "explicit invalidation requests a fresh owning-leader snapshot through the configured projector", failures)
	tooltip.set_advanced_active(true)
	TestAssertions.truthy(tooltip.comparison_active() and tooltip.advanced_active(), "Alt/LT and Shift/RT use the standard tooltip layers", failures)
	TestAssertions.truthy(projection_calls[0] > 2, "tooltip layers rebuild detail only through explicit inspection events", failures)
	first_anchor.mouse_exited.emit()
	tooltip.call(&"_process", 0.20)
	var first_instance := first_chest.get_instance_id()
	var removed := registry.remove(&"drop-a")
	TestAssertions.truthy(removed != null, "fixture removes one authoritative record", failures)
	TestAssertions.equal((controller.get("_chest_by_drop") as Dictionary).size(), 1, "remove releases exactly one active chest", failures)
	TestAssertions.equal((controller.get("_inactive_chests") as Array).size(), 1, "removed chest returns to the reusable pool exactly once", failures)
	registry.remove(&"drop-a")
	TestAssertions.equal((controller.get("_inactive_chests") as Array).size(), 1, "duplicate remove cannot return a chest twice", failures)
	var third := _record(&"drop-c", &"player_1", 1, Vector3(6.0, 0.0, -8.0), &"rare", &"red")
	var projection_calls_before_third := int(projection_calls[0])
	TestAssertions.truthy(registry.add(third), "replacement fixture enters registry", failures)
	var third_chest := (controller.get("_chest_by_drop") as Dictionary)[&"drop-c"] as Node3D
	TestAssertions.equal(third_chest.get_instance_id(), first_instance, "new records reuse an inactive chest before instantiating another", failures)
	TestAssertions.equal(chests_parent.get_child_count(), 2, "reuse preserves one active chest node per record", failures)
	TestAssertions.equal(projection_calls[0], projection_calls_before_third + 1, "adding a record projects only that changed record", failures)
	registry.remove(&"drop-b")
	TestAssertions.equal((controller.get("_inactive_chests") as Array).size(), 1, "second removal leaves one inactive chest for reconfigure coverage", failures)

	var second_chests_parent := Node3D.new()
	second_chests_parent.name = "SecondChests"
	var second_tooltip_layer := Control.new()
	second_tooltip_layer.name = "SecondTooltipLayer"
	second_tooltip_layer.size = Vector2(1920.0, 1080.0)
	host.add_child(second_chests_parent)
	host.add_child(second_tooltip_layer)
	controller.call(&"configure", registry, identities, projector, camera, second_chests_parent, second_tooltip_layer)
	TestAssertions.truthy((controller.get("_controller_focus_by_drop") as Dictionary).is_empty(), "reconfigure clears controller-focus provenance", failures)
	if controller.has_method(&"configure_comparisons"):
		controller.call(&"configure_comparisons", comparison_projector)
	var reconfigured_active := controller.get("_chest_by_drop") as Dictionary
	TestAssertions.equal(reconfigured_active.size(), 1, "reconfigure preserves exactly one active chest per registry record", failures)
	var reconfigured_chest := reconfigured_active[&"drop-c"] as Node3D
	TestAssertions.equal(reconfigured_chest.get_parent(), second_chests_parent, "reconfigure moves active chest to the new chest parent", failures)
	TestAssertions.equal((reconfigured_chest.call(&"tooltip_anchor") as Control).get_parent(), second_tooltip_layer, "reconfigure moves active anchor to the new tooltip layer", failures)
	for pooled_value: Variant in controller.get("_inactive_chests") as Array:
		var pooled := pooled_value as Node3D
		TestAssertions.equal(pooled.get_parent(), second_chests_parent, "reconfigure moves every pooled chest to the new chest parent", failures)
		TestAssertions.equal((pooled.call(&"tooltip_anchor") as Control).get_parent(), second_tooltip_layer, "reconfigure moves every pooled anchor to the new tooltip layer", failures)
	TestAssertions.equal(chests_parent.get_child_count(), 0, "reconfigure leaves no chest under the old parent", failures)
	TestAssertions.equal(tooltip_layer.get_child_count(), 0, "reconfigure leaves no anchor or owned tooltip in the old layer", failures)
	TestAssertions.equal(_tooltip_count(second_tooltip_layer), 1, "reconfigure still owns exactly one shared tooltip", failures)
	TestAssertions.truthy(int(controller_script.get_script_constant_map().get("MAX_INACTIVE_CHESTS", 0)) > 0, "controller declares an explicit bounded inactive pool", failures)
	TestAssertions.truthy((controller.get("_inactive_chests") as Array).size() <= int(controller_script.get_script_constant_map().get("MAX_INACTIVE_CHESTS", 0)), "inactive pool stays within its bound", failures)

	controller.call(&"clear_projection")
	controller.free()
	TestAssertions.equal(second_chests_parent.get_child_count(), 0, "controller teardown destroys every active and pooled chest", failures)
	TestAssertions.equal(second_tooltip_layer.get_child_count(), 0, "controller teardown destroys detached anchors and its owned shared tooltip", failures)
	TestAssertions.equal(tooltip_layer.get_child_count(), 0, "controller teardown leaves old tooltip layers empty", failures)
	var post_teardown := _record(&"drop-after-teardown", &"player_1", 1, Vector3(0.0, 0.0, -3.0), &"common", &"red")
	TestAssertions.truthy(registry.add(post_teardown), "registry remains authoritative after projection teardown", failures)
	TestAssertions.equal(second_chests_parent.get_child_count(), 0, "teardown disconnects registry signals and cannot recreate projections", failures)
	host.free()
	RenderingServer.force_sync()


func _test_bounded_camera_reprojection(controller_script: Script, failures: Array[String]) -> void:
	var host := Node.new()
	var chests_parent := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(1920.0, 1080.0)
	var camera := Camera3D.new()
	host.add_child(chests_parent)
	host.add_child(tooltip_layer)
	host.add_child(camera)
	var controller := Node.new()
	controller.set_script(controller_script)
	host.add_child(controller)
	var registry := GroundItemRegistry.new(256)
	controller.call(&"configure", registry, {}, func(record: GroundItemRecord) -> Dictionary: return _detail_for(record), camera, chests_parent, tooltip_layer)
	for index: int in range(160):
		registry.add(_record(StringName("batch-%03d" % index), &"player_1", 1, Vector3(float(index % 20), 0.0, -float(4 + index / 20)), &"common", &"red"))
	controller.call(&"_process", 0.0)
	camera.position.x = 3.0
	controller.call(&"_process", 0.0)
	TestAssertions.truthy(controller.has_method(&"projection_diagnostics"), "controller exposes production bounded-projection diagnostics", failures)
	if controller.has_method(&"projection_diagnostics"):
		var first_frame := controller.call(&"projection_diagnostics") as Dictionary
		var limit := int(controller_script.get_script_constant_map().get("MAX_PROJECTIONS_PER_FRAME", 0))
		TestAssertions.truthy(limit > 0 and int(first_frame.get("last_frame_work", 0)) <= limit, "camera motion reprojects no more than the declared per-frame bound", failures)
		TestAssertions.truthy(int(first_frame.get("pending", 0)) > 0, "camera motion leaves bounded projection work queued", failures)
		var guard := 0
		while int((controller.call(&"projection_diagnostics") as Dictionary).get("pending", 0)) > 0 and guard < 32:
			controller.call(&"_process", 0.0)
			guard += 1
		TestAssertions.equal(int((controller.call(&"projection_diagnostics") as Dictionary).get("pending", 0)), 0, "bounded camera reprojection reaches eventual correctness", failures)
	controller.call(&"clear_projection")
	controller.free()
	host.free()
	RenderingServer.force_sync()


func _test_modal_anchor_transition_bounds(controller_script: Script, failures: Array[String]) -> void:
	var host := Node.new()
	var chests_parent := Node3D.new()
	var tooltip_layer := Control.new()
	tooltip_layer.size = Vector2(1920.0, 1080.0)
	var camera := Camera3D.new()
	host.add_child(chests_parent)
	host.add_child(tooltip_layer)
	host.add_child(camera)
	var controller := Node.new()
	controller.set_script(controller_script)
	host.add_child(controller)
	var registry := GroundItemRegistry.new()
	registry.add(_record(&"modal-active", &"player_1", 1, Vector3(0.0, 0.0, -3.0), &"common", &"red"))
	registry.add(_record(&"modal-pooled", &"player_1", 1, Vector3(1.0, 0.0, -3.0), &"common", &"red"))
	controller.call(&"configure", registry, {}, func(record: GroundItemRecord) -> Dictionary: return _detail_for(record), camera, chests_parent, tooltip_layer)
	var modal := [false]
	controller.call(&"configure_interaction", null, null, null, null, 20.0, Callable(), func() -> bool: return modal[0])
	var active_chest := (controller.get("_chest_by_drop") as Dictionary).get(&"modal-active") as Node3D
	var pooled_chest := (controller.get("_chest_by_drop") as Dictionary).get(&"modal-pooled") as Node3D
	var active_anchor := active_chest.call(&"tooltip_anchor") as Control
	var pooled_anchor := pooled_chest.call(&"tooltip_anchor") as Control
	TestAssertions.equal(active_anchor.mouse_filter, Control.MOUSE_FILTER_STOP, "ground anchor starts pointer-active while the modal filter is false", failures)
	registry.remove(&"modal-pooled")
	pooled_anchor.mouse_filter = Control.MOUSE_FILTER_PASS
	modal[0] = true
	controller.call(&"_process", 0.0)
	TestAssertions.equal(active_anchor.mouse_filter, Control.MOUSE_FILTER_IGNORE, "modal transition suppresses active ground-anchor pointer capture", failures)
	TestAssertions.equal(pooled_anchor.mouse_filter, Control.MOUSE_FILTER_PASS, "modal transition does not scan or rewrite inactive pooled anchors", failures)
	active_anchor.mouse_filter = Control.MOUSE_FILTER_PASS
	controller.call(&"_process", 0.0)
	TestAssertions.equal(active_anchor.mouse_filter, Control.MOUSE_FILTER_PASS, "stable modal state performs no repeated active-anchor rewrite", failures)
	modal[0] = false
	controller.call(&"_process", 0.0)
	TestAssertions.equal(active_anchor.mouse_filter, Control.MOUSE_FILTER_STOP, "modal close transition restores active ground-anchor pointer capture", failures)
	TestAssertions.equal(pooled_anchor.mouse_filter, Control.MOUSE_FILTER_PASS, "modal close still leaves inactive pooled anchors untouched", failures)
	controller.call(&"clear_projection")
	controller.free()
	host.free()
	RenderingServer.force_sync()


func _detail_for(record: GroundItemRecord) -> Dictionary:
	return {
		"instance_id": record.item_id,
		"name": "Projected %s" % record.item_id,
		"rarity_id": String(record.rarity_id),
		"rarity_name": String(record.rarity_id).capitalize(),
		"item_level": 22,
		"compatible_slot_ids": ["ring_left"],
		"affixes": [{"display_name": "Stout", "tier": 2, "rolls": []}],
		"modifier_totals": {"max_health|0": 25.0},
	}


func _comparison_entry(instance_id: String, current_health: float, candidate_health: float) -> Dictionary:
	var current_stats := ResolvedStatSnapshot.new()
	var candidate_stats := ResolvedStatSnapshot.new()
	current_stats.set_resolved(&"max_health", current_health, [])
	candidate_stats.set_resolved(&"max_health", candidate_health, [])
	return {
		"slot_id": "ring_left",
		"item": {
			"instance_id": instance_id,
			"name": instance_id,
			"rarity_id": "common",
			"rarity_name": "Common",
			"item_level": 10,
			"affixes": [],
			"modifier_totals": {},
		},
		"current_stats": current_stats,
		"candidate_stats": candidate_stats,
	}


func _comparison_card_instance_id(tooltip: ItemTooltipPanel) -> String:
	var cards := tooltip.get_node("Layout/BodyScroll/Cards") as HBoxContainer
	if cards.get_child_count() < 2:
		return ""
	return String(cards.get_child(1).call(&"displayed_instance_id"))


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
