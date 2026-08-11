class_name EquipmentInventoryLedgerPage
extends CharacterLedgerPage

const PAPER_DOLL_POSITIONS := {
	&"helmet": Vector2(0.18, 0.08), &"amulet": Vector2(0.82, 0.06),
	&"main_hand": Vector2(0.06, 0.46), &"body_armour": Vector2(0.18, 0.30), &"off_hand": Vector2(0.94, 0.46),
	&"gloves": Vector2(0.82, 0.22), &"belt": Vector2(0.82, 0.70), &"ring_left": Vector2(0.82, 0.38),
	&"legs": Vector2(0.18, 0.52), &"ring_right": Vector2(0.82, 0.54), &"boots": Vector2(0.18, 0.74),
}

const SCROLL_STEP := 96
const STICK_DEADZONE := 0.15
const SAFE_MARGIN := 24.0

var _equipment_buttons: Dictionary = {}
var _inventory_buttons: Array[StorageSlotButton] = []
var _transaction_sequence := 0
var _compact := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _doll().resized.is_connected(_position_equipment_slots):
		_doll().resized.connect(_position_equipment_slots)


func _process(_delta: float) -> void:
	var tooltip := _tooltip()
	if tooltip.visible:
		_clamp_tooltip_to_safe_margin(tooltip.current_source_id())


func activate() -> void:
	super()
	call_deferred(&"_position_equipment_slots")


func deactivate() -> void:
	_tooltip().force_dismiss()
	_clear_held_item()
	super()


func refresh() -> void:
	_refresh_page(true)


func _refresh_page(refresh_preview: bool) -> void:
	_tooltip().force_dismiss()
	var equipment_rows := _rebuild_equipment()
	_rebuild_inventory()
	_render_member_summary()
	_render_combat_summary()
	if refresh_preview:
		_refresh_preview(equipment_rows)
	_rebuild_focus_graph()
	_sync_held_styles()
	call_deferred(&"_position_equipment_slots")


func initial_focus() -> Control:
	for slot_id: StringName in EquipmentSlotCatalog.SHEET_SLOT_IDS:
		var button := _equipment_buttons.get(slot_id) as StorageSlotButton
		if button != null:
			return button
	return _inventory_buttons[0] if not _inventory_buttons.is_empty() else null


func apply_compact(compact: bool) -> void:
	_compact = compact
	_body().vertical = compact
	_equipment_region().custom_minimum_size = Vector2(0.0, 300.0) if compact else Vector2(620.0, 0.0)
	_inventory_region().custom_minimum_size = Vector2(0.0, 180.0) if compact else Vector2(420.0, 0.0)
	_inventory_grid().columns = 6 if compact else 8
	call_deferred(&"_position_equipment_slots")


func pin_active_detail() -> bool:
	if not _tooltip().visible:
		return false
	if not _tooltip().is_pinned():
		_tooltip().toggle_pin()
	return true


func dismiss_pinned_detail() -> bool:
	if not _tooltip().visible or not _tooltip().is_pinned():
		return false
	_tooltip().force_dismiss()
	return true


func _input(event: InputEvent) -> void:
	if not visible or context == null:
		return
	if event.is_action_pressed(&"item_sandbox_pickup"):
		var focused := _focused_slot()
		if not context.held_item_id.is_empty():
			_clear_held_item()
		elif focused != null and not focused.item_id.is_empty():
			context.held_source_container_id = focused.container_id
			context.held_source_slot = focused.slot
			context.held_item_id = focused.item_id
			_sync_held_styles()
		_mark_input_handled()
		return
	if event.is_action_pressed(&"ui_accept") and not context.held_item_id.is_empty():
		var destination := _focused_slot()
		if destination != null:
			_handle_drop(
				context.held_source_container_id,
				context.held_source_slot,
				context.held_item_id,
				destination.container_id,
				destination.slot,
			)
		_mark_input_handled()
		return
	if _tooltip().visible:
		return
	var axis := event.get_action_strength(&"tooltip_scroll_down") - event.get_action_strength(&"tooltip_scroll_up")
	if absf(axis) < STICK_DEADZONE:
		return
	var focused_control := get_viewport().gui_get_focus_owner() as Control if is_inside_tree() else null
	if focused_control != null and _inventory_scroll().is_ancestor_of(focused_control):
		_inventory_scroll().scroll_vertical += int(roundf(axis * SCROLL_STEP))
		_mark_input_handled()


func _rebuild_equipment() -> Array[Dictionary]:
	_equipment_buttons.clear()
	var rows := provider.equipment_rows(context.selected_member_id) if provider != null and context != null else [] as Array[Dictionary]
	var rows_by_slot: Dictionary = {}
	for row: Dictionary in rows:
		rows_by_slot[StringName(String(row.get("slot_id", "")))] = row
	var create_buttons := _slots().get_child_count() != EquipmentSlotCatalog.SHEET_SLOT_IDS.size()
	if create_buttons:
		_clear(_slots())
	for slot_id: StringName in EquipmentSlotCatalog.SHEET_SLOT_IDS:
		var row := rows_by_slot.get(slot_id, {
			"container_id": StringName("run-equipment-%03d" % (context.selected_member_id if context != null else 0)),
			"slot": EquipmentSlotIndex.index_for(slot_id),
			"item_id": "",
			"detail": {},
		}) as Dictionary
		var button := StorageSlotButton.new() if create_buttons else _slots().get_node("Slot_%s" % slot_id) as StorageSlotButton
		if create_buttons:
			button.name = "Slot_%s" % slot_id
			button.set_meta("slot_id", slot_id)
			button.set_meta("normalized_position", PAPER_DOLL_POSITIONS[slot_id])
		button.bind_item(StringName(String(row.container_id)), int(row.slot), String(row.item_id), row.detail as Dictionary)
		if button.item_id.is_empty():
			button.accessibility_name = "%s equipment slot, empty" % String(slot_id).replace("_", " ").capitalize()
		if create_buttons:
			button.item_dropped.connect(_handle_drop)
			button.inspection_started.connect(_show_item_tooltip)
			button.inspection_ended.connect(_release_item_tooltip)
			_slots().add_child(button)
		_equipment_buttons[slot_id] = button
	return rows


func _refresh_preview(rows: Array[Dictionary]) -> void:
	var member := provider.party.member_by_id(context.selected_member_id) if provider != null and provider.party != null and context != null else null
	if member == null:
		_preview().call(&"clear")
		return
	var preview_rows: Array[Dictionary] = []
	for row: Dictionary in rows:
		var preview_row := row.duplicate(true)
		var detail := row.get("detail", {}) as Dictionary
		var base_id := StringName(String(detail.get("base_definition_id", "")))
		preview_row["base_definition"] = provider.equipment_catalog.definition(base_id) if provider.equipment_catalog != null and not base_id.is_empty() else null
		preview_rows.append(preview_row)
	_preview().call(&"show_member", member, preview_rows)


func _rebuild_inventory() -> void:
	_inventory_buttons.clear()
	var rows := provider.inventory_rows() if provider != null else [] as Array[Dictionary]
	var create_buttons := _inventory_grid().get_child_count() != rows.size()
	if create_buttons:
		_clear(_inventory_grid())
	var occupied := 0
	for row: Dictionary in rows:
		var button := StorageSlotButton.new() if create_buttons else _inventory_grid().get_node("InventorySlot_%03d" % int(row.slot)) as StorageSlotButton
		if create_buttons:
			button.name = "InventorySlot_%03d" % int(row.slot)
		button.bind_item(StringName(String(row.container_id)), int(row.slot), String(row.item_id), row.detail as Dictionary)
		if create_buttons:
			button.item_dropped.connect(_handle_drop)
			button.inspection_started.connect(_show_item_tooltip)
			button.inspection_ended.connect(_release_item_tooltip)
			_inventory_grid().add_child(button)
		_inventory_buttons.append(button)
		if not button.item_id.is_empty():
			occupied += 1
	_inventory_count().text = "Run Inventory  %d / %d" % [occupied, rows.size()]


func _render_member_summary() -> void:
	var selected: Dictionary = {}
	if provider != null and context != null:
		for row: Dictionary in provider.member_rows():
			if int(row.member_id) == context.selected_member_id:
				selected = row
				break
	if selected.is_empty():
		_member_summary().text = "No party member selected."
		return
	var member_name := String(selected.get("character_name", "")).strip_edges()
	if member_name.is_empty():
		member_name = "Member %d" % int(selected.member_id)
	_member_summary().text = "%s  |  %s  |  Level %d" % [member_name, String(selected.class_name), int(selected.character_level)]


func _render_combat_summary() -> void:
	var lines := PackedStringArray(["Combat Summary"])
	var estimates := provider.combat_estimate_rows(context.selected_member_id) if provider != null and context != null else [] as Array[ActionCombatEstimate]
	if estimates.is_empty():
		lines.append("No combat estimate available.")
	for estimate: ActionCombatEstimate in estimates:
		if not estimate.available:
			lines.append("%s  Unavailable" % estimate.display_name)
		elif estimate.is_healing:
			lines.append("%s  HPS %s" % [estimate.display_name, _number(estimate.estimated_hps)])
		else:
			lines.append("%s  DPS %s" % [estimate.display_name, _number(estimate.estimated_dps)])
	_combat_summary().text = "\n".join(lines)


func _handle_drop(
	source_container_id: StringName,
	source_slot: int,
	item_id: String,
	destination_container_id: StringName,
	destination_slot: int,
) -> void:
	if provider == null or context == null or item_id.is_empty():
		return
	var result: Dictionary = {"accepted": false}
	if String(destination_container_id).begins_with("run-equipment-"):
		result = provider.move_or_equip(_exact_transition_request(
			source_container_id,
			source_slot,
			item_id,
			destination_container_id,
			destination_slot,
		))
	elif destination_container_id == &"run-inventory":
		if String(source_container_id).begins_with("run-equipment-"):
			result = provider.move_or_equip(_exact_transition_request(
				source_container_id,
				source_slot,
				item_id,
				destination_container_id,
				destination_slot,
			))
		elif source_container_id == &"run-inventory" and source_slot != destination_slot:
			var destination := _inventory_button_at(destination_slot)
			var request := _inventory_request(source_container_id, source_slot, item_id, destination_container_id, destination_slot, destination != null and not destination.item_id.is_empty())
			result = provider.move_or_equip({"member_id": context.selected_member_id, "transaction": request})
	if not bool(result.get("accepted", false)):
		return
	_clear_held_item()
	var equipment_changed := String(source_container_id).begins_with("run-equipment-") or String(destination_container_id).begins_with("run-equipment-")
	_refresh_page(equipment_changed)


func _exact_transition_request(
	source_container_id: StringName,
	source_slot: int,
	item_id: String,
	destination_container_id: StringName,
	destination_slot: int,
) -> Dictionary:
	return {
		"member_id": context.selected_member_id,
		"item_id": item_id,
		"source_container_id": source_container_id,
		"source_slot": source_slot,
		"destination_container_id": destination_container_id,
		"destination_slot": destination_slot,
	}


func _inventory_request(
	source_container_id: StringName,
	source_slot: int,
	item_id: String,
	destination_container_id: StringName,
	destination_slot: int,
	swap: bool,
) -> ItemTransactionRequest:
	_transaction_sequence += 1
	var transaction_id := "ledger-item-%s-%d" % [item_id, _transaction_sequence]
	var owner_id := String(provider.item_context.run_player_id)
	if swap:
		return ItemTransactionRequest.swap(transaction_id, owner_id, source_container_id, source_slot, item_id, destination_container_id, destination_slot)
	return ItemTransactionRequest.move(transaction_id, owner_id, source_container_id, source_slot, item_id, destination_container_id, destination_slot)


func _show_item_tooltip(source: StorageSlotButton) -> void:
	var detail := source.detail()
	if detail.is_empty() or provider == null or context == null:
		return
	if _tooltip().show_item(detail, provider.comparison_rows(source.item_id, context.selected_member_id), source, source.source_id()):
		call_deferred(&"_clamp_tooltip_to_safe_margin", source.source_id())


func _clamp_tooltip_to_safe_margin(source_id: StringName) -> void:
	var tooltip := _tooltip()
	if not tooltip.visible or not tooltip.is_current_source(source_id):
		return
	var viewport_size := get_viewport_rect().size
	var maximum := Vector2(
		maxf(SAFE_MARGIN, viewport_size.x - tooltip.size.x - SAFE_MARGIN),
		maxf(SAFE_MARGIN, viewport_size.y - tooltip.size.y - SAFE_MARGIN),
	)
	tooltip.global_position = Vector2(
		clampf(tooltip.global_position.x, SAFE_MARGIN, maximum.x),
		clampf(tooltip.global_position.y, SAFE_MARGIN, maximum.y),
	)


func _release_item_tooltip(source: StorageSlotButton) -> void:
	_tooltip().release_item(source.source_id())


func _rebuild_focus_graph() -> void:
	var controls: Array[Control] = []
	for slot_id: StringName in EquipmentSlotCatalog.SHEET_SLOT_IDS:
		var equipment_button := _equipment_buttons.get(slot_id) as StorageSlotButton
		if equipment_button != null:
			controls.append(equipment_button)
	for inventory_button: StorageSlotButton in _inventory_buttons:
		controls.append(inventory_button)
	if controls.is_empty():
		return
	for index: int in controls.size():
		var current := controls[index]
		var previous := controls[posmod(index - 1, controls.size())]
		var next := controls[(index + 1) % controls.size()]
		current.focus_previous = current.get_path_to(previous)
		current.focus_next = current.get_path_to(next)
		current.focus_neighbor_left = current.get_path_to(previous)
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_neighbor_right = current.get_path_to(next)
		current.focus_neighbor_bottom = current.get_path_to(next)


func _position_equipment_slots() -> void:
	var doll_size := _doll().size
	if doll_size.x <= 0.0 or doll_size.y <= 0.0:
		return
	for slot_id: StringName in _equipment_buttons:
		var button := _equipment_buttons[slot_id] as StorageSlotButton
		var button_size := button.custom_minimum_size
		button.size = button_size
		var center := (PAPER_DOLL_POSITIONS[slot_id] as Vector2) * doll_size
		button.position = Vector2(
			clampf(center.x - button_size.x * 0.5, 0.0, maxf(0.0, doll_size.x - button_size.x)),
			clampf(center.y - button_size.y * 0.5, 0.0, maxf(0.0, doll_size.y - button_size.y)),
		)


func _sync_held_styles() -> void:
	if context == null:
		return
	for button: StorageSlotButton in _all_buttons():
		button.set_held(not context.held_item_id.is_empty() and button.item_id == context.held_item_id and button.container_id == context.held_source_container_id and button.slot == context.held_source_slot)


func _clear_held_item() -> void:
	if context == null:
		return
	context.held_source_container_id = &""
	context.held_source_slot = -1
	context.held_item_id = ""
	_sync_held_styles()


func _focused_slot() -> StorageSlotButton:
	var focused := get_viewport().gui_get_focus_owner() as StorageSlotButton if is_inside_tree() else null
	return focused if focused != null and is_ancestor_of(focused) else null


func _inventory_button_at(slot: int) -> StorageSlotButton:
	for button: StorageSlotButton in _inventory_buttons:
		if button.slot == slot:
			return button
	return null


func _all_buttons() -> Array[StorageSlotButton]:
	var result: Array[StorageSlotButton] = []
	for value: Variant in _equipment_buttons.values():
		result.append(value as StorageSlotButton)
	result.append_array(_inventory_buttons)
	return result


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.free()


func _number(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _body() -> BoxContainer:
	return get_node("Layout/Body") as BoxContainer


func _equipment_region() -> VBoxContainer:
	return get_node("Layout/Body/EquipmentRegion") as VBoxContainer


func _inventory_region() -> VBoxContainer:
	return get_node("Layout/Body/InventoryRegion") as VBoxContainer


func _doll() -> Control:
	return get_node("Layout/Body/EquipmentRegion/Doll") as Control


func _slots() -> Control:
	return get_node("Layout/Body/EquipmentRegion/Doll/Slots") as Control


func _member_summary() -> Label:
	return get_node("Layout/MemberSummary") as Label


func _combat_summary() -> Label:
	return get_node("Layout/Body/EquipmentRegion/CombatSummary") as Label


func _inventory_count() -> Label:
	return get_node("Layout/Body/InventoryRegion/InventoryCount") as Label


func _inventory_scroll() -> ScrollContainer:
	return get_node("Layout/Body/InventoryRegion/InventoryScroll") as ScrollContainer


func _inventory_grid() -> GridContainer:
	return get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer


func _tooltip() -> ItemTooltipPanel:
	return get_node("ItemTooltipPanel") as ItemTooltipPanel


func _preview() -> Control:
	return get_node("Layout/Body/EquipmentRegion/Doll/PreviewProtectedCenter/CharacterEquipmentPreview") as Control
