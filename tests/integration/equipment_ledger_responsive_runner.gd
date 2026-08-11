extends SceneTree

const PAGE_PATH := "Overlay/Frame/Layout/Body/PageHost/EquipmentInventoryLedgerPage"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if not ResourceLoader.exists("res://scenes/ui/ledger/equipment_inventory_ledger_page.tscn"):
		push_error("TASK10_EQUIPMENT_LEDGER_INTEGRATION_FAILURE: page scene is absent")
		print("TASK10_EQUIPMENT_LEDGER_RESPONSIVE_SUMMARY: FAIL (1 failures)")
		quit(1)
		return
	for viewport_size: Vector2i in SIZES:
		await _exercise_resolution(viewport_size)
	print("TASK10_EQUIPMENT_LEDGER_MEMBER_24_PASS") if not _failures.any(func(value: String) -> bool: return "member 24" in value) else null
	for failure: String in _failures:
		push_error("TASK10_EQUIPMENT_LEDGER_INTEGRATION_FAILURE: %s" % failure)
	print("TASK10_EQUIPMENT_LEDGER_RESPONSIVE_SUMMARY: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _exercise_resolution(viewport_size: Vector2i) -> void:
	root.content_scale_size = viewport_size
	root.size = viewport_size
	var fixture := _fixture()
	var party := fixture.party as PartyManager
	var run_context := fixture.run_context as PlayerRunContext
	var catalog := fixture.catalog as GameCatalog
	var run := GameRun.new()
	run.start_run()
	var context := LedgerPlayerContext.new(0)
	context.active_page_id = &"equipment_inventory"
	var ledger := (load("res://scenes/ui/ledger/character_ledger.tscn") as PackedScene).instantiate() as CharacterLedger
	root.add_child(ledger)
	var features: Array[StringName] = [&"stats", &"current_upgrades", &"equipment_inventory"]
	var unlocks: Array[StringName] = [&"equipment_inventory"]
	ledger.configure(run, party, catalog, Callable(), [context], FeatureAccessPolicy.new(false, true, features, unlocks, unlocks), Callable(), run_context)
	ledger.apply_viewport_size(viewport_size)
	_assert(ledger.open_for_player(), "ledger opens at %s" % viewport_size)
	await _layout()
	var page := ledger.get_node(PAGE_PATH) as CharacterLedgerPage
	var frame := ledger.get_node("Overlay/Frame") as Control
	_assert(_inside_safe_margin(frame.get_global_rect(), viewport_size), "frame honors 24px safe margin at %s" % viewport_size)
	var inventory := page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
	await _exercise_live_tooltip_layers(page, inventory, viewport_size)
	_assert_visible_controls_within_safe_margin(page, viewport_size)
	var doll := page.get_node("Layout/Body/EquipmentRegion/Doll") as Control
	var protected_center := doll.get_node("PreviewProtectedCenter") as Control
	var slots := doll.get_node("Slots") as Control
	var slot_rects: Array[Rect2] = []
	for child: Node in slots.get_children():
		var slot := child as StorageSlotButton
		_assert(slot != null and _inside_safe_margin(slot.get_global_rect(), viewport_size), "%s stays inside safe margin at %s" % [child.name, viewport_size])
		if slot == null:
			continue
		_assert(not slot.get_global_rect().intersects(protected_center.get_global_rect()), "%s avoids protected preview center at %s" % [slot.name, viewport_size])
		for prior: Rect2 in slot_rects:
			_assert(not slot.get_global_rect().intersects(prior), "%s does not overlap another equipment slot at %s" % [slot.name, viewport_size])
		slot_rects.append(slot.get_global_rect())
	_assert(inventory.get_child_count() == run_context.run_inventory().capacity, "inventory exposes full capacity at %s" % viewport_size)
	_assert((page.initial_focus() as Control) != null, "page provides initial focus at %s" % viewport_size)
	_assert(ledger.select_member(24), "member 24 selects at %s" % viewport_size)
	await _layout()
	_assert((slots.get_node("Slot_helmet") as StorageSlotButton).item_id == "responsive-helmet-24", "member 24 refreshes equipment at %s" % viewport_size)
	if viewport_size == SIZES[0]:
		await _exercise_controller_and_region_scroll(ledger, page, context, run_context)
	print("TASK10_EQUIPMENT_LEDGER_RESOLUTION_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])
	ledger.close()
	paused = false
	ledger.free()
	run.free()
	party.free()
	await process_frame


func _fixture() -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for member_id: int in range(2, 25):
		party.members.append(PartyMemberState.new(member_id, catalog.class_by_id(&"fighter"), false, "Member %d" % member_id))
	var profile := ProfileState.new_profile("task10-responsive", "Task 10 Responsive", 1000)
	profile.inventory_columns = 8
	var run_context := PlayerRunContext.new()
	var errors := run_context.configure(&"task10_responsive_owner", 0, profile, 202020, party, 100)
	_assert(errors.is_empty(), "responsive run context configures")
	if errors.is_empty():
		for row: Dictionary in [
			{"id": "responsive-helmet-1", "sequence": 0, "member": 1, "base": &"dawn_bulwark_crown", "slot": &"helmet"},
			{"id": "responsive-helmet-24", "sequence": 1, "member": 24, "base": &"dawn_bulwark_crown", "slot": &"helmet"},
			{"id": "responsive-ring-equipped", "sequence": 2, "member": 1, "base": &"windrunner_band", "slot": &"ring_left"},
			{"id": "responsive-ring", "sequence": 3, "member": 0, "base": &"windrunner_band", "slot": &"ring_left"},
		]:
			var item := _item(run_context, int(row.sequence), String(row.id), row.base as StringName)
			_assert(run_context.apply_item_transaction(ItemTransactionRequest.create("responsive-create-%s" % row.id, String(run_context.run_player_id), &"run-inventory", int(row.sequence), item), catalog.equipment_catalog, catalog.item_foundation_catalog).ok(), "responsive item %s creates" % row.id)
			if int(row.member) > 0:
				_assert(run_context.assign_equipment(int(row.member), item.instance_id, row.slot as StringName, catalog.equipment_catalog, catalog.item_foundation_catalog).ok(), "responsive item %s equips" % row.id)
	return {"catalog": catalog, "party": party, "run_context": run_context}


func _item(context: PlayerRunContext, sequence: int, instance_id: String, base_id: StringName) -> ItemInstance:
	var affixes: Array = []
	if instance_id == "responsive-ring":
		affixes.append({
			"definition_id": "stout",
			"affix_kind": "prefix",
			"tier": 1,
			"rolls": [{
				"stat_id": "constitution",
				"operation": StatModifier.Operation.FLAT,
				"value": 3.0,
				"required_tags": [],
			}],
		})
	var decoded := ItemInstanceCodec.decode({
		"schema_version": ItemInstance.SCHEMA_VERSION, "instance_id": instance_id,
		"base_definition_id": String(base_id), "base_damage_components": [], "item_level": 15,
		"rarity_id": "common", "affixes": affixes,
		"origin": {"issuer_namespace": "run:%s:%d:%s" % [context.profile_id, context.run_seed, context.run_player_id], "seed": context.run_seed + sequence, "sequence": sequence, "source": "task10-responsive"},
	}, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	assert(decoded.ok())
	return decoded.item


func _exercise_controller_and_region_scroll(
	ledger: CharacterLedger,
	page: CharacterLedgerPage,
	context: LedgerPlayerContext,
	run_context: PlayerRunContext,
) -> void:
	_assert(ledger.select_member(1), "controller fixture reselects member 1")
	await _layout()
	var inventory := page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
	var equipment := page.get_node("Layout/Body/EquipmentRegion/Doll/Slots") as Control
	var helmet := equipment.get_node("Slot_helmet") as StorageSlotButton
	var empty_destination := inventory.get_node("InventorySlot_004") as StorageSlotButton
	await _gui_drag_drop(helmet, empty_destination)
	_assert(run_context.run_inventory().item_id_at(4) == "responsive-helmet-1", "real shared-button drop reaches the exact page transaction")
	var ring := _button_for_item(inventory, "responsive-ring")
	_assert(ring != null, "controller fixture exposes the inventory ring")
	if ring == null:
		return
	ring.grab_focus()
	await _layout()
	await _parse_action(&"item_sandbox_pickup")
	_assert(context.held_item_id == "responsive-ring", "controller west holds the focused item")
	var slots := equipment
	var invalid_target := slots.get_node("Slot_body_armour") as StorageSlotButton
	var before_invalid := run_context.item_state().to_dictionary()
	invalid_target.grab_focus()
	await _layout()
	await _parse_action(&"ui_accept")
	_assert(run_context.item_state().to_dictionary() == before_invalid, "controller invalid target keeps ownership unchanged")
	_assert(context.held_item_id == "responsive-ring", "controller invalid target retains the held item")
	var valid_target := slots.get_node("Slot_ring_left") as StorageSlotButton
	valid_target.grab_focus()
	await _layout()
	await _parse_action(&"ui_accept")
	_assert(run_context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"ring_left")) == "responsive-ring", "controller south places into a valid focused target")
	_assert(run_context.run_inventory().item_id_at(3) == "responsive-ring-equipped", "occupied equipment swap returns the displaced item to the exact inventory source cell")
	_assert(context.held_item_id.is_empty(), "accepted controller placement releases held state")
	valid_target = slots.get_node("Slot_ring_left") as StorageSlotButton
	valid_target.grab_focus()
	await _layout()
	await _parse_action(&"item_sandbox_pickup")
	await _parse_action(&"item_sandbox_pickup")
	_assert(context.held_item_id.is_empty(), "second controller west press releases the held slot")

	(page.get_node("ItemTooltipPanel") as ItemTooltipPanel).force_dismiss()
	page.apply_compact(true)
	await _layout()
	var inventory_scroll := page.get_node("Layout/Body/InventoryRegion/InventoryScroll") as ScrollContainer
	var last_inventory_slot := inventory.get_child(inventory.get_child_count() - 1) as StorageSlotButton
	last_inventory_slot.grab_focus()
	await _layout()
	inventory_scroll.scroll_vertical = 0
	await _parse_axis(1.0)
	_assert(inventory_scroll.scroll_vertical > 0, "right stick scrolls the focused inventory region (scroll=%d max=%d focus=%s)" % [inventory_scroll.scroll_vertical, int(inventory_scroll.get_v_scroll_bar().max_value), str(root.gui_get_focus_owner())])
	page.apply_compact(false)
	await _layout()

	var party_scroll := ledger.get_node("Overlay/Frame/Layout/Body/PartyColumn/PartyScroll") as ScrollContainer
	var member_24 := ledger.get_node("Overlay/Frame/Layout/Body/PartyColumn/PartyScroll/PartyEntries/Member_24") as Button
	party_scroll.scroll_vertical = 0
	member_24.grab_focus()
	await _layout()
	party_scroll.scroll_vertical = 0
	await _parse_axis(1.0)
	_assert(party_scroll.scroll_vertical > 0, "right stick scrolls the focused party region")


func _exercise_live_tooltip_layers(page: CharacterLedgerPage, inventory: GridContainer, viewport_size: Vector2i) -> void:
	var source := _button_for_item(inventory, "responsive-ring")
	_assert(source != null, "tooltip fixture exposes comparison ring at %s" % viewport_size)
	if source == null:
		return
	source.grab_focus()
	await _layout()
	var tooltip := page.get_node("ItemTooltipPanel") as ItemTooltipPanel
	_assert(tooltip.visible, "tooltip is visible before live layer toggles at %s" % viewport_size)
	var equipped_ring := page.get_node("Layout/Body/EquipmentRegion/Doll/Slots/Slot_ring_left") as StorageSlotButton
	var comparison_rows: Array[Dictionary] = []
	for slot_id: StringName in [&"ring_left", &"ring_right"]:
		comparison_rows.append({
			"item": equipped_ring.detail(),
			"slot_id": slot_id,
			"delta_lines": [],
		})
	var regression_anchor := Control.new()
	regression_anchor.name = "TooltipRegressionAnchor"
	regression_anchor.size = Vector2(78.0, 78.0)
	page.add_child(regression_anchor)
	regression_anchor.global_position = Vector2(viewport_size.x * 0.5 - regression_anchor.size.x * 0.5, viewport_size.y * 0.5)
	tooltip.force_dismiss()
	_assert(tooltip.show_item(source.detail(), comparison_rows, regression_anchor, source.source_id()), "shared tooltip accepts a live comparison fixture at %s" % viewport_size)
	await _layout()
	page.call("_clamp_tooltip_to_safe_margin", source.source_id())
	_assert(_inside_safe_margin(tooltip.get_global_rect(), viewport_size), "initial tooltip rect=%s stays inside the 24px safe margin at %s" % [tooltip.get_global_rect(), viewport_size])
	Input.parse_input_event(_key(KEY_ALT, true))
	Input.parse_input_event(_key(KEY_SHIFT, true))
	await _layout()
	_assert(tooltip.comparison_active() and tooltip.advanced_active(), "Alt and Shift activate live tooltip layers at %s" % viewport_size)
	_assert(tooltip.card_count() == 3, "live comparison renders the inspected and both equipped ring cards at %s" % viewport_size)
	_assert(_inside_safe_margin(tooltip.get_global_rect(), viewport_size), "expanded tooltip rect=%s stays inside the 24px safe margin at %s" % [tooltip.get_global_rect(), viewport_size])
	Input.parse_input_event(_key(KEY_SHIFT, false))
	Input.parse_input_event(_key(KEY_ALT, false))
	await _layout()
	tooltip.force_dismiss()
	regression_anchor.free()


func _button_for_item(grid: GridContainer, item_id: String) -> StorageSlotButton:
	for child: Node in grid.get_children():
		var button := child as StorageSlotButton
		if button != null and button.item_id == item_id:
			return button
	return null


func _parse_action(action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


func _parse_axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = JOY_AXIS_RIGHT_Y
	event.axis_value = value
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventJoypadMotion
	release.axis_value = 0.0
	Input.parse_input_event(release)
	await process_frame


func _gui_drag_drop(source: Control, destination: Control) -> void:
	var source_position := source.get_global_rect().get_center()
	var destination_position := destination.get_global_rect().get_center()
	root.push_input(_mouse_motion(source_position, Vector2.ZERO, 0))
	root.push_input(_mouse_button(source_position, true))
	await process_frame
	root.push_input(_mouse_motion(source_position + Vector2(32.0, 0.0), Vector2(32.0, 0.0), MOUSE_BUTTON_MASK_LEFT))
	await process_frame
	_assert(root.gui_is_dragging(), "public GUI mouse flow starts a shared-button drag")
	root.push_input(_mouse_motion(destination_position, destination_position - source_position, MOUSE_BUTTON_MASK_LEFT))
	await process_frame
	root.push_input(_mouse_button(destination_position, false))
	await _layout()


func _mouse_motion(position: Vector2, relative: Vector2, button_mask: MouseButtonMask) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = button_mask
	return event


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	return event


func _inside_safe_margin(rect: Rect2, viewport_size: Vector2i) -> bool:
	return rect.position.x >= 24.0 and rect.position.y >= 24.0 and rect.end.x <= viewport_size.x - 24.0 and rect.end.y <= viewport_size.y - 24.0


func _assert_visible_controls_within_safe_margin(parent: Node, viewport_size: Vector2i) -> void:
	for child: Node in parent.get_children():
		var control := child as Control
		if control != null and control.is_visible_in_tree():
			_assert(_inside_safe_margin(control.get_global_rect(), viewport_size), "%s rect=%s stays inside the 24px safe margin at %s" % [control.name, control.get_global_rect(), viewport_size])
		_assert_visible_controls_within_safe_margin(child, viewport_size)


func _layout() -> void:
	await process_frame
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
