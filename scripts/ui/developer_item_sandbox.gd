class_name DeveloperItemSandbox
extends CanvasLayer

signal closed
signal held_item_changed(held: bool, container_id: StringName, slot: int)

const INVENTORY_ID := &"developer-inventory"
const STASH_ID := &"developer-stash-000"
const OWNER_ID := "developer-item-sandbox"
const SLOT_DATA_KIND := "party_forge_developer_item_slot"
const EMPTY_INSPECTOR := "Focus or click a populated slot to inspect it."

class SandboxSlotButton extends Button:
	var sandbox: DeveloperItemSandbox

	func _get_drag_data(_at_position: Vector2) -> Variant:
		return sandbox._begin_mouse_drag(self) if sandbox != null else null

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return sandbox._can_drop_on(self, data) if sandbox != null else false

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if sandbox != null:
			sandbox._drop_on(self, data)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and sandbox != null and sandbox.is_holding_item():
			var viewport := get_viewport()
			sandbox._finish_drag(viewport != null and viewport.gui_is_drag_successful())

var _state := DeveloperItemSandboxState.new()
var _registry: ItemRegistry
var _inventory: ItemSlotContainer
var _stash: ItemSlotContainer
var _projection: Dictionary = {}
var _return_focus: Control
var _selected_container_id := StringName()
var _selected_slot := -1
var _held_container_id := StringName()
var _held_slot := -1
var _held_item_id := ""
var _last_focused_slot: Button
var _slot_buttons: Array[Button] = []
var _wired := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_initialized()
	visible = false
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_viewport_size_changed):
		viewport.size_changed.connect(_viewport_size_changed)


func _ensure_initialized() -> void:
	_build_slots()
	_wire_controls()
	_configure_focus_graph()
	_viewport_size_changed()


func open(return_focus: Control = null) -> bool:
	_ensure_initialized()
	if visible:
		return true
	_return_focus = return_focus
	var error := _state.reload()
	if not error.is_empty() and not FileAccess.file_exists(DeveloperItemSandboxStore.DOCUMENT_PATH):
		error = _state.reset()
	if error.is_empty():
		_refresh_projection()
		_set_status("OPEN")
	else:
		_set_status("OPEN", error)
	visible = true
	if is_inside_tree() and not _slot_buttons.is_empty():
		_slot_buttons[0].grab_focus()
	return true


func configure(state: DeveloperItemSandboxState) -> void:
	if visible or state == null:
		return
	_state = state
	_registry = null
	_inventory = null
	_stash = null
	_projection = {}


func close() -> void:
	if not visible:
		return
	_clear_held_item()
	visible = false
	closed.emit()
	if _return_focus != null and is_instance_valid(_return_focus) and _return_focus.is_inside_tree() and _return_focus.is_visible_in_tree() and _return_focus.focus_mode != Control.FOCUS_NONE:
		_return_focus.grab_focus()
	_return_focus = null


func is_open() -> bool:
	return visible


func projection() -> Dictionary:
	return _projection.duplicate(true)


func selected_item() -> Dictionary:
	var item := _item_at(_selected_container_id, _selected_slot)
	return item.to_dictionary() if item != null else {}


func is_holding_item() -> bool:
	return not _held_item_id.is_empty()


func _input(event: InputEvent) -> void:
	if not visible or not is_holding_item() or not event.is_action_pressed(&"ui_accept"):
		return
	var target := _focused_slot_button()
	if _is_slot_button(target):
		_perform_transfer(
			_held_container_id,
			_held_slot,
			StringName(String(target.get_meta("container_id", ""))),
			int(target.get_meta("slot", -1))
		)
	else:
		_clear_held_item()
		_set_status("PLACE", _ui_error("INVALID_DESTINATION"))
	_mark_input_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		if is_holding_item():
			_clear_held_item()
			_set_status("HELD_CANCELLED")
		else:
			close()
		_mark_input_handled()
		return
	if event.is_action_pressed(&"item_sandbox_pickup"):
		var source := _focused_slot_button()
		if _is_slot_button(source):
			_begin_held_item(source)
		else:
			_set_status("PICKUP", _ui_error("INVALID_SOURCE"))
		_mark_input_handled()


func _begin_mouse_drag(button: Button) -> Variant:
	if not _begin_held_item(button):
		return null
	var preview := Label.new()
	preview.text = "Held: %s" % _display_name_for(_held_item_id)
	preview.add_theme_font_size_override(&"font_size", 18)
	if button.is_inside_tree():
		button.set_drag_preview(preview)
	return {
		"kind": SLOT_DATA_KIND,
		"container_id": String(_held_container_id),
		"slot": _held_slot,
		"item_id": _held_item_id,
	}


func _can_drop_on(button: Button, data: Variant) -> bool:
	if not _is_slot_button(button) or not is_holding_item() or not data is Dictionary:
		return false
	var payload := data as Dictionary
	if String(payload.get("kind", "")) != SLOT_DATA_KIND:
		return false
	if String(payload.get("item_id", "")) != _held_item_id:
		return false
	var destination_id := StringName(String(button.get_meta("container_id", "")))
	var destination_slot := int(button.get_meta("slot", -1))
	return destination_id != _held_container_id or destination_slot != _held_slot


func _drop_on(button: Button, data: Variant) -> void:
	if not _can_drop_on(button, data):
		_finish_drag(false)
		return
	_perform_transfer(
		_held_container_id,
		_held_slot,
		StringName(String(button.get_meta("container_id", ""))),
		int(button.get_meta("slot", -1))
	)


func _finish_drag(successful: bool) -> void:
	if successful or not is_holding_item():
		return
	_clear_held_item()
	_set_status("DRAG_CANCELLED")


func _begin_held_item(button: Button) -> bool:
	if not _is_slot_button(button):
		_set_status("PICKUP", _ui_error("INVALID_SOURCE"))
		return false
	var item_id := String(button.get_meta("item_id", ""))
	if item_id.is_empty():
		_set_status("PICKUP", _ui_error("EMPTY_SOURCE"))
		return false
	_clear_held_item()
	_held_container_id = StringName(String(button.get_meta("container_id", "")))
	_held_slot = int(button.get_meta("slot", -1))
	_held_item_id = item_id
	_inspect_slot(_held_container_id, _held_slot)
	_sync_slot_affordances()
	held_item_changed.emit(true, _held_container_id, _held_slot)
	_set_status("HOLDING")
	return true


func _clear_held_item() -> void:
	if not is_holding_item():
		return
	_held_container_id = StringName()
	_held_slot = -1
	_held_item_id = ""
	_sync_slot_affordances()
	held_item_changed.emit(false, StringName(), -1)


func _perform_transfer(
	source_container_id: StringName,
	source_slot: int,
	destination_container_id: StringName,
	destination_slot: int
) -> void:
	var destination_item_id := _item_id_at(destination_container_id, destination_slot)
	var action := "SWAP" if not destination_item_id.is_empty() else "MOVE"
	var error := _state.transfer_slots(source_container_id, source_slot, destination_container_id, destination_slot)
	_clear_held_item()
	if not error.is_empty():
		_set_status(action, error)
		return
	_refresh_projection()
	_inspect_slot(destination_container_id, destination_slot)
	_set_status(action)


func _inspect_slot(container_id: StringName, slot: int) -> void:
	_selected_container_id = container_id
	_selected_slot = slot
	var item := _item_at(container_id, slot)
	_inspector().text = _inspector_text(item, container_id, slot) if item != null else EMPTY_INSPECTOR
	_sync_slot_affordances()


func _on_first_empty_inventory() -> void:
	_move_selected_to_first_empty(true)


func _on_first_empty_stash() -> void:
	_move_selected_to_first_empty(false)


func _move_selected_to_first_empty(inventory_destination: bool) -> void:
	var item := _item_at(_selected_container_id, _selected_slot)
	var action := "FIRST_EMPTY_INVENTORY" if inventory_destination else "FIRST_EMPTY_STASH"
	if item == null:
		_set_status(action, _ui_error("NO_SELECTED_ITEM"))
		return
	var error := _state.move_to_first_empty_inventory(item.instance_id) if inventory_destination else _state.move_to_first_empty_stash(item.instance_id)
	if not error.is_empty():
		_set_status(action, error)
		return
	_refresh_projection()
	var location := _location_for(item.instance_id)
	_inspect_slot(StringName(String(location.get("container_id", ""))), int(location.get("slot", -1)))
	_set_status(action)


func _on_save() -> void:
	_complete_state_action("SAVE", _state.save())


func _on_reload() -> void:
	_complete_state_action("RELOAD", _state.reload())


func _on_integrity_scan() -> void:
	_complete_state_action("INTEGRITY_SCAN", _state.scan_integrity())


func _on_reset() -> void:
	_complete_state_action("RESET", _state.reset())


func _complete_state_action(action: String, error: String) -> void:
	if not error.is_empty():
		_set_status(action, error)
		return
	_clear_held_item()
	_refresh_projection()
	if _item_at(_selected_container_id, _selected_slot) != null:
		_inspect_slot(_selected_container_id, _selected_slot)
	else:
		_selected_container_id = StringName()
		_selected_slot = -1
		_inspector().text = EMPTY_INSPECTOR
	_set_status(action)


func _refresh_projection() -> void:
	var registry := _state.registry()
	var inventory := _state.inventory()
	var stash := _state.stash()
	if registry == null or inventory == null or stash == null:
		return
	_registry = registry
	_inventory = inventory
	_stash = stash
	_projection = _state.to_dictionary()
	for button: Button in _slot_buttons:
		var container_id := StringName(String(button.get_meta("container_id", "")))
		var slot := int(button.get_meta("slot", -1))
		var item_id := _item_id_at(container_id, slot)
		button.set_meta("item_id", item_id)
		button.text = "%d\n%s" % [slot, _display_name_for(item_id) if not item_id.is_empty() else "Empty"]
	_sync_slot_affordances()


func _build_slots() -> void:
	if not _slot_buttons.is_empty():
		return
	for slot: int in 5:
		_add_slot_button(_inventory_grid(), INVENTORY_ID, slot, "InventorySlot_%02d" % slot)
	for slot: int in 100:
		_add_slot_button(_stash_grid(), STASH_ID, slot, "StashSlot_%03d" % slot)


func _add_slot_button(parent: GridContainer, container_id: StringName, slot: int, node_name: String) -> void:
	var button := SandboxSlotButton.new()
	button.name = node_name
	button.sandbox = self
	button.custom_minimum_size = Vector2(62, 54)
	button.focus_mode = Control.FOCUS_ALL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.set_meta("container_id", String(container_id))
	button.set_meta("slot", slot)
	button.set_meta("item_id", "")
	button.pressed.connect(_on_slot_inspected.bind(button))
	button.focus_entered.connect(_on_slot_inspected.bind(button))
	parent.add_child(button)
	_slot_buttons.append(button)


func _on_slot_inspected(button: Button) -> void:
	_last_focused_slot = button
	_inspect_slot(
		StringName(String(button.get_meta("container_id", ""))),
		int(button.get_meta("slot", -1))
	)


func _wire_controls() -> void:
	if _wired:
		return
	_wired = true
	_close_button().pressed.connect(close)
	_action_button("FirstEmptyInventory").pressed.connect(_on_first_empty_inventory)
	_action_button("FirstEmptyStash").pressed.connect(_on_first_empty_stash)
	_action_button("Save").pressed.connect(_on_save)
	_action_button("Reload").pressed.connect(_on_reload)
	_action_button("IntegrityScan").pressed.connect(_on_integrity_scan)
	_action_button("Reset").pressed.connect(_on_reset)


func _configure_focus_graph() -> void:
	var controls: Array[Control] = []
	for button: Button in _slot_buttons:
		controls.append(button)
	controls.append(_inspector())
	for action_name: String in ["FirstEmptyInventory", "FirstEmptyStash", "Save", "Reload", "IntegrityScan", "Reset"]:
		controls.append(_action_button(action_name))
	controls.append(_close_button())
	for index: int in controls.size():
		var control := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[posmod(index - 1, controls.size())]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_next = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_neighbor_right = control.get_path_to(next)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_top = control.get_path_to(previous)


func _sync_slot_affordances() -> void:
	for button: Button in _slot_buttons:
		button.set_meta("drop_target", false)
		button.modulate = Color.WHITE
		button.tooltip_text = "Click or focus to inspect. Drag a populated slot to move or swap."
		var container_id := StringName(String(button.get_meta("container_id", "")))
		var slot := int(button.get_meta("slot", -1))
		if is_holding_item():
			if container_id == _held_container_id and slot == _held_slot:
				button.modulate = Color(1.0, 0.78, 0.28)
				button.tooltip_text = "HELD source. Drop on another slot or cancel."
			else:
				button.modulate = Color(0.65, 0.82, 1.0)
				button.set_meta("drop_target", true)
				button.tooltip_text = "Drop target: move if empty, swap if occupied."
		elif container_id == _selected_container_id and slot == _selected_slot:
			button.modulate = Color(0.72, 1.0, 0.76)
		var item_id := String(button.get_meta("item_id", ""))
		var label := _display_name_for(item_id) if not item_id.is_empty() else "Empty"
		button.text = "%s%d\n%s" % ["HELD " if container_id == _held_container_id and slot == _held_slot else "", slot, label]


func _inspector_text(item: ItemInstance, container_id: StringName, slot: int) -> String:
	var base := GameCatalog.EQUIPMENT_CATALOG.definition(item.base_definition_id)
	var rarity := GameCatalog.ITEM_FOUNDATION_CATALOG.rarity(item.rarity_id)
	var lines: Array[String] = [
		"Base: %s" % (base.display_name if base != null else String(item.base_definition_id)),
		"Instance ID: %s" % item.instance_id,
		"Rarity: %s" % (rarity.display_name if rarity != null else String(item.rarity_id)),
		"Item Level: %d" % item.item_level,
	]
	if item.affixes.is_empty():
		lines.append("Affixes: None")
	for index: int in item.affixes.size():
		var affix := item.affixes[index]
		var definition := GameCatalog.ITEM_FOUNDATION_CATALOG.affix(affix.definition_id)
		lines.append("Affix %d: %s" % [index + 1, definition.display_name if definition != null else String(affix.definition_id)])
		lines.append("  Tier: %d" % affix.tier)
		for roll: ItemModifierRoll in affix.rolls:
			var operation_names := StatModifier.Operation.keys()
			var operation := String(operation_names[roll.operation]) if roll.operation >= 0 and roll.operation < operation_names.size() else "UNKNOWN"
			lines.append("  Operation: %s" % operation)
			lines.append("  Roll: %s = %s" % [roll.stat_id, str(roll.value)])
	lines.append("Owner: %s" % OWNER_ID)
	lines.append("Container: %s" % container_id)
	lines.append("Slot: %d" % slot)
	return "\n".join(lines)


func _item_at(container_id: StringName, slot: int) -> ItemInstance:
	var item_id := _item_id_at(container_id, slot)
	return _registry.item(item_id) if _registry != null and not item_id.is_empty() else null


func _item_id_at(container_id: StringName, slot: int) -> String:
	var container := _inventory if container_id == INVENTORY_ID else _stash if container_id == STASH_ID else null
	return container.item_id_at(slot) if container != null and slot >= 0 and slot < container.capacity else ""


func _display_name_for(item_id: String) -> String:
	if item_id.is_empty() or _registry == null:
		return ""
	var item := _registry.item(item_id)
	var base := GameCatalog.EQUIPMENT_CATALOG.definition(item.base_definition_id) if item != null else null
	return base.display_name if base != null else item_id


func _location_for(item_id: String) -> Dictionary:
	for container: ItemSlotContainer in [_inventory, _stash]:
		if container == null:
			continue
		for slot: int in container.occupied_slots():
			if container.item_id_at(slot) == item_id:
				return {"container_id": String(container.container_id), "slot": slot}
	return {}


func _is_slot_button(control: Control) -> bool:
	return control != null and control in _slot_buttons and control.has_meta("container_id") and control.has_meta("slot")


func _focused_slot_button() -> Button:
	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner() as Button if viewport != null else null
	return focused if _is_slot_button(focused) else _last_focused_slot if _is_slot_button(_last_focused_slot) else null


func _set_status(action: String, error: String = "") -> void:
	_status().text = "OK %s" % action if error.is_empty() else error
	_status().tooltip_text = error


func _ui_error(code: String) -> String:
	return "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_UI_ERROR code=%s" % code


func _viewport_size_changed() -> void:
	var body := get_node("Overlay/Frame/Layout/Body") as BoxContainer
	var viewport := get_viewport()
	if viewport != null:
		body.vertical = viewport.get_visible_rect().size.x < 1500.0


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _inventory_grid() -> GridContainer:
	return get_node("Overlay/Frame/Layout/Body/InventoryPanel/InventorySlots") as GridContainer


func _stash_grid() -> GridContainer:
	return get_node("Overlay/Frame/Layout/Body/StashPanel/StashScroll/StashSlots") as GridContainer


func _inspector() -> Label:
	return get_node("Overlay/Frame/Layout/Body/InspectorPanel/InspectorScroll/Inspector") as Label


func _status() -> Label:
	return get_node("Overlay/Frame/Layout/Header/Status") as Label


func _close_button() -> Button:
	return get_node("Overlay/Frame/Layout/Header/Close") as Button


func _action_button(button_name: String) -> Button:
	return get_node("Overlay/Frame/Layout/Actions/%s" % button_name) as Button
