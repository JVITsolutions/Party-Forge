class_name DeveloperItemSandbox
extends CanvasLayer

signal closed
signal held_item_changed(held: bool, container_id: StringName, slot: int)

const INVENTORY_ID := &"developer-inventory"
const STASH_ID := &"developer-stash-000"
const OWNER_ID := "developer-item-sandbox"
const SLOT_DATA_KIND := "party_forge_developer_item_slot"
const RESPONSIVE_LAYOUT := preload("res://scripts/ui/ledger/ledger_responsive_layout.gd")
const PRESENTATION_PROJECTOR := preload("res://scripts/ui/storage/item_presentation_projector.gd")
const COMPARISON_RESOLVER := preload("res://scripts/ui/storage/item_comparison_resolver.gd")
const COMPARISON_BASELINE_BY_SLOT := {
	&"helmet": &"forge_vanguard_helmet",
	&"body_armour": &"forge_vanguard_armour",
	&"legs": &"forge_vanguard_greaves",
	&"gloves": &"forge_vanguard_gauntlets",
	&"boots": &"forge_vanguard_boots",
	&"amulet": &"forge_vanguard_amulet",
	&"ring_left": &"forge_vanguard_ring_left",
	&"ring_right": &"forge_vanguard_ring_right",
	&"belt": &"forge_vanguard_belt",
	&"main_hand": &"forge_vanguard_sword",
	&"off_hand": &"forge_vanguard_shield",
}

class SandboxSlotButton extends StorageSlotButton:
	var sandbox: DeveloperItemSandbox

	func _get_drag_data(at_position: Vector2) -> Variant:
		return sandbox._begin_mouse_drag(self) if sandbox != null else super(at_position)

	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		return sandbox._can_drop_on(self, data) if sandbox != null else super(at_position, data)

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if sandbox != null:
			sandbox._drop_on(self, data)
		else:
			super(at_position, data)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and sandbox != null and sandbox.is_holding_item():
			var viewport := get_viewport()
			sandbox._finish_drag(viewport != null and viewport.gui_is_drag_successful())

var _state := DeveloperItemSandboxState.new()
var _registry: ItemRegistry
var _inventory: ItemSlotContainer
var _stash: ItemSlotContainer
var _projection: Dictionary = {}
var _comparison_projection: ProfileStorageProjection
var _return_focus: Control
var _selected_container_id := StringName()
var _selected_slot := -1
var _held_container_id := StringName()
var _held_slot := -1
var _held_item_id := ""
var _last_focused_slot: Button
var _slot_buttons: Array[Button] = []
var _wired := false
var _presentation_projection_override: Callable
var _loot_lab_session := LootLabSessionController.new()
var _current_tab := 1
var _active_scroll_target: Control


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
	_configure_loot_lab()
	_configure_focus_graph()
	_viewport_size_changed()


func open(return_focus: Control = null) -> bool:
	_ensure_initialized()
	if visible:
		return true
	_return_focus = return_focus
	var candidate_validator := Callable(self, "_candidate_projection_error")
	var error := _state.reload(candidate_validator)
	if not error.is_empty() and not FileAccess.file_exists(DeveloperItemSandboxStore.DOCUMENT_PATH):
		error = _state.reset(candidate_validator)
	if error.is_empty():
		error = _refresh_projection()
	if error.is_empty():
		_set_status("OPEN")
	else:
		_set_status("OPEN", error)
	_tabs().current_tab = 1
	_on_tab_changed(1)
	visible = true
	if is_inside_tree():
		_focus_first_active_control()
	return true


func configure(state: DeveloperItemSandboxState, presentation_projection: Callable = Callable()) -> void:
	if visible or state == null:
		return
	_state = state
	_presentation_projection_override = presentation_projection
	_registry = null
	_inventory = null
	_stash = null
	_projection = {}
	_configure_loot_lab()


func close() -> void:
	if not visible:
		return
	if _loot_lab() != null and not _loot_lab().request_parent_close():
		return
	_close_immediately()


func cancel_and_clear() -> void:
	if _loot_lab() != null:
		_loot_lab().cancel_and_clear()
	if visible:
		_close_immediately()


func _close_immediately() -> void:
	_tooltip().call("force_dismiss")
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


func slot_button_count() -> int:
	_ensure_initialized()
	return _slot_buttons.size()


func selected_item_detail() -> Dictionary:
	return selected_item()


func integrity_error() -> String:
	return _state.integrity_error()


func apply_viewport_size(size: Vector2i) -> void:
	var compact := RESPONSIVE_LAYOUT.mode_for_size(Vector2(size)) == RESPONSIVE_LAYOUT.Mode.COMPACT
	var body := get_node("Overlay/Frame/Layout/Tabs/Equipment/Body") as BoxContainer
	body.vertical = compact
	var frame := get_node("Overlay/Frame") as Control
	frame.offset_left = 16.0 if compact else 48.0
	frame.offset_top = 12.0 if compact else 36.0
	frame.offset_right = -16.0 if compact else -48.0
	frame.offset_bottom = -12.0 if compact else -36.0
	var inventory_panel := get_node("Overlay/Frame/Layout/Tabs/Equipment/Body/InventoryPanel") as Control
	var stash_panel := get_node("Overlay/Frame/Layout/Tabs/Equipment/Body/StashPanel") as Control
	inventory_panel.custom_minimum_size = Vector2(0.0, 64.0) if compact else Vector2(220.0, 0.0)
	stash_panel.custom_minimum_size = Vector2(0.0, 220.0) if compact else Vector2(660.0, 0.0)
	_inventory_grid().columns = 5 if compact else 1
	_loot_lab().apply_viewport_size(size)


func is_holding_item() -> bool:
	return not _held_item_id.is_empty()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"item_sandbox_previous_tab"):
		_cycle_tab(-1)
		_mark_input_handled()
		return
	if event.is_action_pressed(&"item_sandbox_next_tab"):
		_cycle_tab(1)
		_mark_input_handled()
		return
	if event.is_action_pressed(&"item_sandbox_scroll_up"):
		_scroll_focused(-1.0)
		_mark_input_handled()
		return
	if event.is_action_pressed(&"item_sandbox_scroll_down"):
		_scroll_focused(1.0)
		_mark_input_handled()
		return
	if not is_holding_item() or not event.is_action_pressed(&"ui_accept"):
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
		elif _current_tab == 2 and _loot_lab().cancel_active_job():
			_set_status("LOOT_LAB_JOB_CANCELLED")
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
	var slot_button := button as StorageSlotButton
	var preview: Control
	if slot_button != null and slot_button.icon != null:
		var texture := TextureRect.new()
		texture.texture = slot_button.icon
		texture.custom_minimum_size = Vector2(64.0, 64.0)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview = texture
	else:
		var fallback := Label.new()
		fallback.text = "?"
		fallback.custom_minimum_size = Vector2(64.0, 64.0)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview = fallback
	var viewport := button.get_viewport() if button.is_inside_tree() else null
	if viewport != null and viewport.gui_is_dragging():
		button.set_drag_preview(preview)
	else:
		preview.free()
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
	var error := _state.transfer_slots(
		source_container_id, source_slot, destination_container_id, destination_slot,
		Callable(self, "_candidate_projection_error"),
	)
	_clear_held_item()
	if not error.is_empty():
		_set_status(action, error)
		return
	var projection_error := _refresh_projection()
	if not projection_error.is_empty():
		_set_status(action, projection_error)
		return
	_inspect_slot(destination_container_id, destination_slot)
	_set_status(action)


func _inspect_slot(container_id: StringName, slot: int) -> void:
	_selected_container_id = container_id
	_selected_slot = slot
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
	var candidate_validator := Callable(self, "_candidate_projection_error")
	var error := _state.move_to_first_empty_inventory(item.instance_id, candidate_validator) if inventory_destination else _state.move_to_first_empty_stash(item.instance_id, candidate_validator)
	if not error.is_empty():
		_set_status(action, error)
		return
	var projection_error := _refresh_projection()
	if not projection_error.is_empty():
		_set_status(action, projection_error)
		return
	var location := _location_for(item.instance_id)
	_inspect_slot(StringName(String(location.get("container_id", ""))), int(location.get("slot", -1)))
	_set_status(action)


func _on_save() -> void:
	_complete_state_action("SAVE", _state.save(Callable(self, "_candidate_projection_error")))


func _on_reload() -> void:
	_complete_state_action("RELOAD", _state.reload(Callable(self, "_candidate_projection_error")))


func _on_integrity_scan() -> void:
	_complete_state_action("INTEGRITY_SCAN", _state.scan_integrity())


func _on_reset() -> void:
	_complete_state_action("RESET", _state.reset(Callable(self, "_candidate_projection_error")))


func _complete_state_action(action: String, error: String) -> void:
	if not error.is_empty():
		_set_status(action, error)
		return
	_clear_held_item()
	var projection_error := _refresh_projection()
	if not projection_error.is_empty():
		_set_status(action, projection_error)
		return
	if _item_at(_selected_container_id, _selected_slot) != null:
		_inspect_slot(_selected_container_id, _selected_slot)
	else:
		_selected_container_id = StringName()
		_selected_slot = -1
	_set_status(action)


func _refresh_projection() -> String:
	var registry := _state.registry()
	var inventory := _state.inventory()
	var stash := _state.stash()
	var staged := _stage_projection(registry, inventory, stash, _state.to_dictionary())
	var error := String(staged.get("error", ""))
	if not error.is_empty():
		return error
	_tooltip().call("force_dismiss")
	_registry = staged["registry"] as ItemRegistry
	_inventory = staged["inventory"] as ItemSlotContainer
	_stash = staged["stash"] as ItemSlotContainer
	_projection = (staged["projection"] as Dictionary).duplicate(true)
	_comparison_projection = staged["comparison"] as ProfileStorageProjection
	var slot_bindings := staged["slot_bindings"] as Array[Dictionary]
	for index: int in _slot_buttons.size():
		var binding := slot_bindings[index]
		var button := _slot_buttons[index]
		var container_id := binding["container_id"] as StringName
		var slot := int(binding["slot"])
		var item_id := String(binding["item_id"])
		var shared := button as StorageSlotButton
		shared.bind_item(container_id, slot, item_id, binding["detail"] as Dictionary)
		if container_id == STASH_ID:
			shared.custom_minimum_size.y = maxf(shared.custom_minimum_size.y, 88.0)
		button.set_meta("item_id", item_id)
	_sync_slot_affordances()
	return ""


func _candidate_projection_error(candidate_state: ItemOwnershipState, document: Dictionary) -> String:
	if candidate_state == null:
		return "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR reason=projection state is unavailable"
	var staged := _stage_projection(
		candidate_state.registry(),
		candidate_state.container(INVENTORY_ID),
		candidate_state.container(STASH_ID),
		document,
	)
	return String(staged.get("error", ""))


func _stage_projection(
	registry: ItemRegistry,
	inventory: ItemSlotContainer,
	stash: ItemSlotContainer,
	serialized: Dictionary,
) -> Dictionary:
	if registry == null or inventory == null or stash == null:
		return {"error": "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR reason=projection state is unavailable"}
	var comparison := _build_comparison_projection(registry)
	if comparison == null or not comparison.valid:
		var comparison_error := comparison.error if comparison != null else "comparison projection is unavailable"
		return {"error": "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_ERROR field=comparison reason=%s" % comparison_error}
	var fixture_class := GameCatalog.load_defaults().class_by_id(&"fighter")
	var slot_bindings: Array[Dictionary] = []
	for button: Button in _slot_buttons:
		var container_id := StringName(String(button.get_meta("container_id", "")))
		var slot := int(button.get_meta("slot", -1))
		var container := inventory if container_id == INVENTORY_ID else stash if container_id == STASH_ID else null
		var item_id := container.item_id_at(slot) if container != null and slot >= 0 and slot < container.capacity else ""
		var item := registry.item(item_id) if not item_id.is_empty() else null
		var detail := _project_presentation(item, fixture_class) if item != null else {}
		if detail.has("error"):
			return {"error": String(detail.get("error", "PARTY_FORGE_ITEM_PRESENTATION_ERROR reason=presentation data is invalid"))}
		elif not detail.is_empty():
			detail = _bindable_presentation_detail(detail, container_id, slot)
		slot_bindings.append({
			"container_id": container_id,
			"slot": slot,
			"item_id": item_id,
			"detail": detail,
		})
	return {
		"error": "",
		"registry": registry,
		"inventory": inventory,
		"stash": stash,
		"projection": serialized.duplicate(true),
		"comparison": comparison,
		"slot_bindings": slot_bindings,
	}


func _project_presentation(item: ItemInstance, fixture_class: ClassDefinition) -> Dictionary:
	if _presentation_projection_override.is_valid():
		var projected: Variant = _presentation_projection_override.call(
			item,
			GameCatalog.EQUIPMENT_CATALOG,
			GameCatalog.ITEM_FOUNDATION_CATALOG,
			GameCatalog.STAT_CATALOG,
			fixture_class,
		)
		return projected as Dictionary if projected is Dictionary else {
			"error": "PARTY_FORGE_ITEM_PRESENTATION_ERROR item=%s reason=projector returned non-dictionary data" % item.instance_id,
		}
	return PRESENTATION_PROJECTOR.project(
		item,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
		fixture_class,
	)


func _bindable_presentation_detail(detail: Dictionary, container_id: StringName, slot: int) -> Dictionary:
	if detail.has("error"):
		return {}
	var result := detail.duplicate(true)
	result["owner_id"] = OWNER_ID
	result["container_id"] = String(container_id)
	result["slot"] = slot
	return result


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
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("container_id", String(container_id))
	button.set_meta("slot", slot)
	button.set_meta("item_id", "")
	button.pressed.connect(_on_slot_inspected.bind(button))
	button.focus_entered.connect(_on_slot_inspected.bind(button))
	button.inspection_started.connect(_show_item_tooltip)
	button.inspection_ended.connect(_release_item_tooltip)
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
	_tabs().tab_changed.connect(_on_tab_changed)
	_bind_scroll_targets(self)
	_current_tab = _tabs().current_tab


func _configure_focus_graph() -> void:
	for control: Control in _all_focus_controls():
		control.focus_mode = Control.FOCUS_NONE
	var controls := _active_focus_controls()
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


func _all_focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for button: Button in _slot_buttons:
		controls.append(button)
	for action_name: String in ["FirstEmptyInventory", "FirstEmptyStash", "Save", "Reload", "IntegrityScan", "Reset"]:
		controls.append(_action_button(action_name))
	for control: Control in _loot_lab().focus_controls():
		controls.append(control)
	controls.append(_tabs())
	controls.append(_close_button())
	return controls


func _active_focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	match _current_tab:
		0:
			controls.append(_action_button("IntegrityScan"))
			controls.append(_action_button("Reset"))
		1:
			for button: Button in _slot_buttons:
				controls.append(button)
			for action_name: String in ["FirstEmptyInventory", "FirstEmptyStash", "Save", "Reload"]:
				controls.append(_action_button(action_name))
		2:
			for control: Control in _loot_lab().focus_controls():
				controls.append(control)
	controls.append(_tabs())
	controls.append(_close_button())
	return controls


func _focus_first_active_control() -> void:
	var controls := _active_focus_controls()
	if not controls.is_empty() and controls[0].is_inside_tree() and controls[0].is_visible_in_tree():
		controls[0].grab_focus()


func _on_tab_changed(tab: int) -> void:
	_tooltip().call("force_dismiss")
	if _current_tab == 1 and tab != 1:
		_clear_held_item()
	_current_tab = tab
	_configure_focus_graph()
	if visible:
		_focus_first_active_control()


func _cycle_tab(direction: int) -> void:
	var tabs := _tabs()
	if tabs.get_tab_count() <= 0:
		return
	tabs.current_tab = posmod(tabs.current_tab + direction, tabs.get_tab_count())


func _bind_scroll_targets(node: Node) -> void:
	for child: Node in node.get_children():
		if child is ScrollContainer or child is Tree:
			var control := child as Control
			if not control.mouse_entered.is_connected(_set_active_scroll_target.bind(control)):
				control.mouse_entered.connect(_set_active_scroll_target.bind(control))
		_bind_scroll_targets(child)


func _set_active_scroll_target(control: Control) -> void:
	_active_scroll_target = control


func _scroll_focused(direction: float) -> void:
	var target := _focused_scroll_target()
	if target is ScrollContainer:
		var scroll := target as ScrollContainer
		scroll.scroll_vertical += roundi(direction * 72.0)
		return
	if target is Tree:
		_scroll_tree(target as Tree, direction)


func _focused_scroll_target() -> Control:
	var viewport := get_viewport()
	var current: Node = viewport.gui_get_focus_owner() if viewport != null else null
	while current != null:
		if current is ScrollContainer or current is Tree:
			return current as Control
		current = current.get_parent()
	return _active_scroll_target if _active_scroll_target != null and is_instance_valid(_active_scroll_target) and _active_scroll_target.is_visible_in_tree() else null


func _scroll_tree(tree: Tree, direction: float) -> void:
	var selected := tree.get_selected()
	if selected == null:
		var root_item := tree.get_root()
		selected = root_item.get_first_child() if root_item != null else null
	elif direction > 0.0:
		selected = selected.get_next_visible()
	else:
		selected = selected.get_prev_visible()
	if selected != null:
		selected.select(0)
		tree.scroll_to_item(selected, true)


func _configure_loot_lab() -> void:
	var lab := _loot_lab()
	if lab == null:
		return
	lab.configure(_loot_lab_session, _state, _tooltip() as ItemTooltipPanel, _presentation_projection_override)
	lab.set_preview_comparison_provider(Callable(self, "_loot_lab_preview_comparisons"))
	if not lab.sandbox_item_issued.is_connected(_on_loot_lab_item_issued):
		lab.sandbox_item_issued.connect(_on_loot_lab_item_issued)
	if not lab.close_requested.is_connected(close):
		lab.close_requested.connect(close)
	if not lab.focus_controls_changed.is_connected(_configure_focus_graph):
		lab.focus_controls_changed.connect(_configure_focus_graph)


func _on_loot_lab_item_issued() -> void:
	var error := _refresh_projection()
	_set_status("LOOT_LAB_ISSUE", error)


func _sync_slot_affordances() -> void:
	for button: Button in _slot_buttons:
		button.set_meta("drop_target", false)
		var container_id := StringName(String(button.get_meta("container_id", "")))
		var slot := int(button.get_meta("slot", -1))
		var shared := button as StorageSlotButton
		var selected := not is_holding_item() and container_id == _selected_container_id and slot == _selected_slot
		var held := is_holding_item() and container_id == _held_container_id and slot == _held_slot
		var drop_target := is_holding_item() and not held
		shared.set_selected(selected)
		shared.set_held(held)
		shared.set_drop_target(drop_target, true)
		if is_holding_item():
			if not held:
				button.set_meta("drop_target", true)


func _item_at(container_id: StringName, slot: int) -> ItemInstance:
	var item_id := _item_id_at(container_id, slot)
	return _registry.item(item_id) if _registry != null and not item_id.is_empty() else null


func _item_id_at(container_id: StringName, slot: int) -> String:
	var container := _inventory if container_id == INVENTORY_ID else _stash if container_id == STASH_ID else null
	return container.item_id_at(slot) if container != null and slot >= 0 and slot < container.capacity else ""


func _location_for(item_id: String) -> Dictionary:
	for container: ItemSlotContainer in [_inventory, _stash]:
		if container == null:
			continue
		for slot: int in container.occupied_slots():
			if container.item_id_at(slot) == item_id:
				return {"container_id": String(container.container_id), "slot": slot}
	return {}


func _is_slot_button(control: Control) -> bool:
	return control is Button and control in _slot_buttons and control.has_meta("container_id") and control.has_meta("slot")


func _focused_slot_button() -> Button:
	var viewport := get_viewport()
	var focused := viewport.gui_get_focus_owner() if viewport != null else null
	if focused != null:
		return focused as Button if _is_slot_button(focused) else null
	return _last_focused_slot if _is_slot_button(_last_focused_slot) else null


func _set_status(action: String, error: String = "") -> void:
	_status().text = "OK %s" % action if error.is_empty() else error
	_status().tooltip_text = error


func _ui_error(code: String) -> String:
	return "PARTY_FORGE_DEVELOPER_ITEM_SANDBOX_UI_ERROR code=%s" % code


func _viewport_size_changed() -> void:
	var viewport := get_viewport()
	if viewport != null:
		apply_viewport_size(Vector2i(viewport.get_visible_rect().size))


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _inventory_grid() -> GridContainer:
	return get_node("Overlay/Frame/Layout/Tabs/Equipment/Body/InventoryPanel/InventorySlots") as GridContainer


func _stash_grid() -> GridContainer:
	return get_node("Overlay/Frame/Layout/Tabs/Equipment/Body/StashPanel/StashScroll/StashSlots") as GridContainer


func _show_item_tooltip(source: StorageSlotButton) -> void:
	var detail := source.detail()
	if detail.is_empty():
		return
	var comparisons: Array[Dictionary] = []
	if _comparison_projection != null and _comparison_projection.valid:
		var projected_by_slot := _comparison_projection.comparison_lines_by_slot(String(detail.get("instance_id", "")))
		comparisons = COMPARISON_RESOLVER.resolve(
			detail,
			_comparison_projection.leader_slots,
			_comparison_projection.item_records,
			projected_by_slot,
		)
	_tooltip().call("show_item", detail, comparisons, source, source.source_id(), true)

func _loot_lab_preview_comparisons(detail: Dictionary) -> Array[Dictionary]:
	if _comparison_projection == null or not _comparison_projection.valid:
		return []
	var projected_by_slot := _comparison_projection.comparison_lines_by_slot(String(detail.get("instance_id", "")))
	return COMPARISON_RESOLVER.resolve(
		detail,
		_comparison_projection.leader_slots,
		_comparison_projection.item_records,
		projected_by_slot,
	)


func _build_comparison_projection(registry: ItemRegistry) -> ProfileStorageProjection:
	if registry == null:
		return null
	var profile := ProfileState.new_profile(OWNER_ID, "Developer Fixture", 0)
	profile.item_records = registry.to_dictionary()
	var leader_slots: Dictionary = {}
	var baseline_ids: Array[String] = []
	for slot_id: StringName in COMPARISON_BASELINE_BY_SLOT:
		var baseline_id := _instance_id_for_base(COMPARISON_BASELINE_BY_SLOT[slot_id], registry)
		if baseline_id.is_empty():
			continue
		leader_slots[EquipmentSlotIndex.index_for(slot_id)] = baseline_id
		baseline_ids.append(baseline_id)
	var preview_slots: Dictionary = {}
	for instance_id: String in registry.ids():
		if instance_id not in baseline_ids:
			preview_slots[preview_slots.size()] = instance_id
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout",
		ItemSlotContainer.PROFILE_LEADER_EQUIPMENT,
		OWNER_ID,
		EquipmentSlotIndex.capacity(),
		leader_slots,
	).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	profile.stash_tabs = [
		ItemSlotContainer.create(&"sandbox-preview-stash", ItemSlotContainer.PROFILE_STASH_TAB, OWNER_ID, 100, preview_slots).to_dictionary(),
	]
	var fixture_class := GameCatalog.load_defaults().class_by_id(&"fighter")
	return ProfileStorageProjection.from_profile(
		profile,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
		fixture_class,
	)


func _instance_id_for_base(base_id: StringName, registry: ItemRegistry) -> String:
	if registry == null:
		return ""
	for instance_id: String in registry.ids():
		var item := registry.item(instance_id)
		if item != null and item.base_definition_id == base_id:
			return instance_id
	return ""


func _release_item_tooltip(source: StorageSlotButton) -> void:
	_tooltip().call("release_item", source.source_id())


func _tooltip() -> Control:
	return get_node("Overlay/ItemTooltip") as Control


func _status() -> Label:
	return get_node("Overlay/Frame/Layout/Header/Status") as Label


func _close_button() -> Button:
	return get_node("Overlay/Frame/Layout/Header/Close") as Button


func _action_button(button_name: String) -> Button:
	var page := "Fixtures" if button_name in ["IntegrityScan", "Reset"] else "Equipment"
	return get_node("Overlay/Frame/Layout/Tabs/%s/Actions/%s" % [page, button_name]) as Button


func _tabs() -> TabContainer:
	return get_node("Overlay/Frame/Layout/Tabs") as TabContainer


func _loot_lab() -> DeveloperLootLab:
	return get_node("Overlay/Frame/Layout/Tabs/Loot Lab") as DeveloperLootLab
