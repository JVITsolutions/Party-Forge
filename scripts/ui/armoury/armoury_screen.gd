class_name ArmouryScreen
extends CanvasLayer

const COMPARISON_RESOLVER := preload("res://scripts/ui/storage/item_comparison_resolver.gd")

signal close_requested
signal move_requested(item_id: String, destination_container_id: StringName, destination_slot: int)
signal equip_requested(item_id: String, equipment_slot_id: StringName, target_class_id: StringName)
signal loadout_class_change_requested(target_class_id: StringName)

var _projection := ArmouryProjection.new()
var _return_focus: Control
var _selected_tab := 0
var _held_item_id := ""
var _classes: Array[ClassDefinition] = []
var _pending_run_class_id: StringName
var _developer_mode := false
var _visual_settings := PartyForgeSettings.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_connect_controls()

func configure_classes(classes: Array[ClassDefinition]) -> void:
	_classes = classes.duplicate()


func configure_visual_settings(settings: PartyForgeSettings) -> void:
	_visual_settings = settings.copy() if settings != null else PartyForgeSettings.new()
	_apply_visual_settings()


func open(storage: ProfileStorageProjection, return_focus: Control = null, developer_mode: bool = false) -> void:
	_projection = ArmouryProjection.from_storage(storage)
	_pending_run_class_id = &""
	_return_focus = return_focus
	_developer_mode = developer_mode
	_selected_tab = mini(_selected_tab, maxi(0, _projection.stash_tabs.size() - 1))
	_held_item_id = ""
	visible = true
	_apply_visual_settings()
	_render_projection()
	if is_inside_tree():
		_first_focus().grab_focus()

func refresh(storage: ProfileStorageProjection) -> void:
	var focus_descriptor := _focused_storage_descriptor()
	_tooltip().call("force_dismiss")
	_projection = ArmouryProjection.from_storage(storage)
	_apply_visual_settings()
	_render_projection()
	_restore_storage_focus(focus_descriptor)

func close() -> void:
	_tooltip().call("force_dismiss")
	visible = false
	_held_item_id = ""
	_pending_run_class_id = &""
	if is_inside_tree() and _return_focus != null and is_instance_valid(_return_focus) and _return_focus.is_inside_tree() and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null

func is_open() -> bool: return visible
func equipment_button_count() -> int: return _equipment_grid().get_child_count()
func stash_tab_count() -> int: return _tab_bar().get_tab_count()
func selected_item_detail() -> Dictionary: return _projection.item(_held_item_id)
func projection() -> ArmouryProjection: return ArmouryProjection.from_storage(_projection.storage_projection())

func set_pending_run_class(class_id: StringName) -> void:
	_pending_run_class_id = class_id
	_render_class_label()

func choose_class(target_class_id: StringName) -> void:
	if target_class_id.is_empty(): return
	if not _projection.loadout_empty and target_class_id != _projection.active_class_id:
		loadout_class_change_requested.emit(target_class_id)
		return
	for index: int in _class_chooser().item_count:
		if StringName(_class_chooser().get_item_metadata(index)) == target_class_id:
			_class_chooser().select(index)
			return

func apply_viewport_size(size: Vector2i) -> void:
	var compact := size.x < 1400 or size.y < 850
	_body().vertical = compact
	_frame().offset_left = 16.0 if compact else 48.0
	_frame().offset_top = 12.0 if compact else 36.0
	_frame().offset_right = -_frame().offset_left
	_frame().offset_bottom = -_frame().offset_top
	_rebuild_focus_loop()

func request_drop(source_container_id: StringName, source_slot: int, item_id: String, destination_container_id: StringName, destination_slot: int) -> void:
	_handle_drop(source_container_id, source_slot, item_id, destination_container_id, destination_slot)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"item_sandbox_pickup"):
		var viewport := get_viewport()
		if viewport == null:
			return
		var focused := viewport.gui_get_focus_owner() as StorageSlotButton
		if (
			focused != null
			and not focused.item_id.is_empty()
			and String(focused.detail().get("move_locked_reason", "")).is_empty()
		):
			_held_item_id = focused.item_id
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and not _held_item_id.is_empty():
		var target := get_viewport().gui_get_focus_owner() as StorageSlotButton
		if target != null:
			var source := _locate(_held_item_id)
			var source_container_id := StringName(source.get("container_id", ""))
			var source_slot := int(source.get("slot", -1))
			if _drop_allowed(source_container_id, source_slot, _held_item_id, target.container_id, target.slot):
				_handle_drop(source_container_id, source_slot, _held_item_id, target.container_id, target.slot)
		get_viewport().set_input_as_handled()

func _render_projection() -> void:
	_render_class_label()
	_class_chooser().visible = _projection.loadout_empty
	_class_chooser().clear()
	for definition: ClassDefinition in _classes:
		_class_chooser().add_item(definition.display_name)
		_class_chooser().set_item_metadata(_class_chooser().item_count - 1, definition.id)
	_select_projected_class()
	_rebuild_equipment()
	_rebuild_tabs()
	_rebuild_stash()
	_rebuild_recovery_overflow()
	_rebuild_focus_loop()

func _render_class_label() -> void:
	_class_label().text = "Active Class: %s" % (String(_projection.active_class_id) if not _projection.active_class_id.is_empty() else "Unbound")
	if not _pending_run_class_id.is_empty():
		_class_label().text += " | Pending Run: %s" % String(_pending_run_class_id)

func _rebuild_equipment() -> void:
	_clear(_equipment_grid())
	for entry: Dictionary in _projection.leader_slots:
		var button := StorageSlotButton.new()
		var instance_id := String(entry["instance_id"])
		var detail := _projection.item(instance_id)
		button.name = "LeaderSlot_%02d_%s" % [int(entry["slot"]), String(entry["slot_id"])]
		button.bind_item(&"leader-loadout", int(entry["slot"]), instance_id, detail, String(entry["slot_id"]).capitalize())
		button.set_drop_policy(_drop_allowed)
		button.item_dropped.connect(_handle_drop)
		button.pressed.connect(_select_item.bind(instance_id))
		_wire_item_inspection(button)
		_equipment_grid().add_child(button)

func _rebuild_tabs() -> void:
	_tab_bar().clear_tabs()
	for index: int in _projection.stash_tabs.size():
		_tab_bar().add_tab("Tab %d" % (index + 1))
	_tab_bar().current_tab = _selected_tab if _tab_bar().tab_count > 0 else -1

func _rebuild_stash() -> void:
	_clear(_stash_grid())
	if _selected_tab < 0 or _selected_tab >= _projection.stash_tabs.size():
		return
	var tab := _projection.stash_tabs[_selected_tab]
	var slots := tab["slots"] as Dictionary
	for slot: int in int(tab["capacity"]):
		var item_id := String(slots.get(str(slot), slots.get(slot, "")))
		var button := StorageSlotButton.new()
		button.name = "StashSlot_%03d" % slot
		button.bind_item(StringName(tab["container_id"]), slot, item_id, _projection.item(item_id))
		button.set_drop_policy(_drop_allowed)
		button.item_dropped.connect(_handle_drop)
		button.pressed.connect(_select_item.bind(item_id))
		_wire_item_inspection(button)
		_stash_grid().add_child(button)

func _rebuild_recovery_overflow() -> void:
	_clear(_recovery_overflow_grid())
	var overflow := _projection.terminal_recovery_overflow
	if overflow.is_empty():
		return
	var slots := overflow.get("slots", {}) as Dictionary
	for slot: int in int(overflow.get("capacity", 0)):
		var item_id := String(slots.get(str(slot), slots.get(slot, "")))
		var button := StorageSlotButton.new()
		button.name = "RecoveryOverflowSlot_%02d" % slot
		button.bind_item(
			ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID,
			slot,
			item_id,
			_projection.item(item_id),
			"Recovery",
		)
		button.set_drop_policy(_drop_allowed)
		button.item_dropped.connect(_handle_drop)
		button.pressed.connect(_select_item.bind(item_id))
		_wire_item_inspection(button)
		_recovery_overflow_grid().add_child(button)

func _handle_drop(source_container_id: StringName, _source_slot: int, item_id: String, destination_container_id: StringName, destination_slot: int) -> void:
	if not _drop_allowed(source_container_id, _source_slot, item_id, destination_container_id, destination_slot):
		return
	if source_container_id == ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID:
		move_requested.emit(item_id, destination_container_id, destination_slot)
		_held_item_id = ""
		return
	if destination_container_id == &"leader-loadout":
		equip_requested.emit(item_id, EquipmentSlotIndex.slot_for(destination_slot), _selected_class_id())
	else:
		move_requested.emit(item_id, destination_container_id, destination_slot)
	_held_item_id = ""


func _drop_allowed(source_container_id: StringName, _source_slot: int, item_id: String, destination_container_id: StringName, destination_slot: int) -> bool:
	if source_container_id.is_empty() or item_id.is_empty():
		return false
	if destination_container_id == ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID:
		return false
	if not String(_projection.item(item_id).get("move_locked_reason", "")).is_empty():
		return false
	if source_container_id == ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID:
		return (
			destination_container_id != &"leader-loadout"
			and _is_ordinary_stash(destination_container_id)
			and _ordinary_stash_slot_is_empty(destination_container_id, destination_slot)
		)
	return destination_container_id == &"leader-loadout" or _is_ordinary_stash(destination_container_id)

func _on_class_selected(index: int) -> void:
	if index < 0 or index >= _class_chooser().item_count:
		return
	var target := StringName(_class_chooser().get_item_metadata(index))
	if not _projection.loadout_empty and target != _projection.active_class_id:
		loadout_class_change_requested.emit(target)

func _selected_class_id() -> StringName:
	if not _projection.active_class_id.is_empty() and not _projection.loadout_empty:
		return _projection.active_class_id
	var index := _class_chooser().selected
	return StringName(_class_chooser().get_item_metadata(index)) if index >= 0 and index < _class_chooser().item_count else _projection.active_class_id

func _select_item(item_id: String) -> void:
	if not String(_projection.item(item_id).get("move_locked_reason", "")).is_empty():
		_held_item_id = ""
		return
	_held_item_id = item_id


func _wire_item_inspection(button: StorageSlotButton) -> void:
	button.inspection_started.connect(_show_item_tooltip)
	button.inspection_ended.connect(_release_item_tooltip)
	button.focus_entered.connect(_ensure_focused_slot_visible.bind(button))


func _show_item_tooltip(source: StorageSlotButton) -> void:
	var detail := source.detail()
	if detail.is_empty():
		return
	var storage := _projection.storage_projection()
	var projected_by_slot := _projection.comparison_lines_by_slot(String(detail.get("instance_id", "")))
	var comparisons: Array[Dictionary] = COMPARISON_RESOLVER.resolve(detail, storage.leader_slots, storage.item_records, projected_by_slot)
	_tooltip().call("show_item", detail, comparisons, source, source.source_id(), _developer_mode)


func _release_item_tooltip(source: StorageSlotButton) -> void:
	_tooltip().call("release_item", source.source_id())


func _ensure_focused_slot_visible(button: StorageSlotButton) -> void:
	var ancestor := button.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).call_deferred(&"ensure_control_visible", button)
			return
		ancestor = ancestor.get_parent()

func _select_projected_class() -> void:
	if _class_chooser().item_count == 0:
		return
	var selected_index := 0
	if not _projection.active_class_id.is_empty():
		for index: int in _class_chooser().item_count:
			if StringName(_class_chooser().get_item_metadata(index)) == _projection.active_class_id:
				selected_index = index
				break
	_class_chooser().select(selected_index)

func _locate(item_id: String) -> Dictionary:
	for entry: Dictionary in _projection.leader_slots:
		if entry["instance_id"] == item_id: return {"container_id": "leader-loadout", "slot": entry["slot"]}
	for tab: Dictionary in _projection.stash_tabs:
		for key: Variant in (tab["slots"] as Dictionary):
			if String((tab["slots"] as Dictionary)[key]) == item_id: return {"container_id": tab["container_id"], "slot": int(key)}
	var overflow := _projection.terminal_recovery_overflow
	var overflow_slots := overflow.get("slots", {}) as Dictionary
	for key: Variant in overflow_slots:
		if String(overflow_slots[key]) == item_id:
			return {"container_id": String(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID), "slot": int(key)}
	return {}

func _is_ordinary_stash(container_id: StringName) -> bool:
	for tab: Dictionary in _projection.stash_tabs:
		if String(tab.get("container_id", "")) == String(container_id):
			return true
	return false

func _ordinary_stash_slot_is_empty(container_id: StringName, slot: int) -> bool:
	for tab: Dictionary in _projection.stash_tabs:
		if String(tab.get("container_id", "")) == String(container_id):
			if slot < 0 or slot >= int(tab.get("capacity", 0)):
				return false
			var slots := tab.get("slots", {}) as Dictionary
			return String(slots.get(str(slot), slots.get(slot, ""))).is_empty()
	return false

func _focused_storage_descriptor() -> Dictionary:
	if not is_inside_tree():
		return {}
	var focused := get_viewport().gui_get_focus_owner() as StorageSlotButton
	if focused == null or not is_ancestor_of(focused):
		return {}
	return {
		"container_id": String(focused.container_id),
		"slot": focused.slot,
		"item_id": focused.item_id,
	}

func _restore_storage_focus(descriptor: Dictionary) -> Control:
	var item_id := String(descriptor.get("item_id", ""))
	if not item_id.is_empty():
		for grid: GridContainer in [_equipment_grid(), _stash_grid(), _recovery_overflow_grid()]:
			for child: Node in grid.get_children():
				var item_button := child as StorageSlotButton
				if item_button != null and item_button.item_id == item_id:
					if item_button.is_inside_tree():
						item_button.grab_focus()
					return item_button

	var prior_container_id := String(descriptor.get("container_id", ""))
	var prior_slot := int(descriptor.get("slot", -1))
	var nearest_button: StorageSlotButton
	var nearest_distance := 2147483647
	for grid: GridContainer in [_equipment_grid(), _stash_grid(), _recovery_overflow_grid()]:
		for child: Node in grid.get_children():
			var button := child as StorageSlotButton
			if button == null or String(button.container_id) != prior_container_id:
				continue
			var distance := absi(button.slot - prior_slot)
			if nearest_button == null or distance < nearest_distance or (distance == nearest_distance and button.slot < nearest_button.slot):
				nearest_button = button
				nearest_distance = distance
	if nearest_button != null:
		if nearest_button.is_inside_tree():
			nearest_button.grab_focus()
		return nearest_button

	var safe_focus := _first_focus()
	if safe_focus == null or safe_focus.focus_mode == Control.FOCUS_NONE or not safe_focus.visible:
		safe_focus = _close_button()
	if safe_focus != null and safe_focus.is_inside_tree():
		safe_focus.grab_focus()
	return safe_focus

func _connect_controls() -> void:
	if not _close_button().pressed.is_connected(_on_close_pressed): _close_button().pressed.connect(_on_close_pressed)
	if not _tab_bar().tab_changed.is_connected(_on_tab_changed): _tab_bar().tab_changed.connect(_on_tab_changed)
	if not _class_chooser().item_selected.is_connected(_on_class_selected): _class_chooser().item_selected.connect(_on_class_selected)

func _on_close_pressed() -> void: close_requested.emit()
func _on_tab_changed(index: int) -> void: _selected_tab = index; _rebuild_stash(); _rebuild_focus_loop()
func _rebuild_focus_loop() -> void:
	var controls: Array[Control] = []
	if _class_chooser().visible: controls.append(_class_chooser())
	controls.append(_tab_bar())
	for child: Node in _equipment_grid().get_children(): controls.append(child as Control)
	for child: Node in _stash_grid().get_children(): controls.append(child as Control)
	for child: Node in _recovery_overflow_grid().get_children(): controls.append(child as Control)
	controls.append(_close_button())
	for index: int in controls.size():
		var current := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[posmod(index - 1, controls.size())]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_left = current.get_path_to(previous)
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_neighbor_right = current.get_path_to(next)
		current.focus_neighbor_bottom = current.get_path_to(next)


func _apply_visual_settings() -> void:
	var resolved := _visual_settings if _visual_settings != null else PartyForgeSettings.new()
	var resolved_theme := LivingForgeThemeCatalog.resolve(resolved.high_contrast, resolved.ui_scale_percent, resolved.text_scale_percent)
	(get_node("Overlay") as Control).theme = resolved_theme
	var action_minimum := 48
	if resolved_theme != null and resolved_theme.has_constant(&"action_minimum", &"LivingForgeMetrics"):
		action_minimum = maxi(48, resolved_theme.get_constant(&"action_minimum", &"LivingForgeMetrics"))
	_close_button().custom_minimum_size = Vector2(action_minimum, action_minimum)
func _clear(parent: Node) -> void:
	for child: Node in parent.get_children(): child.free()
func _first_focus() -> Control: return _equipment_grid().get_child(0) as Control if _equipment_grid().get_child_count() > 0 else _close_button()
func _frame() -> Control: return get_node("Overlay/Frame") as Control
func _body() -> BoxContainer: return get_node("Overlay/Frame/Layout/Body") as BoxContainer
func _equipment_grid() -> GridContainer: return get_node("Overlay/Frame/Layout/Body/Equipment/Slots") as GridContainer
func _stash_grid() -> GridContainer: return get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid") as GridContainer
func _recovery_overflow_grid() -> GridContainer: return get_node("Overlay/Frame/Layout/Body/RecoveryOverflow/Scroll/Grid") as GridContainer
func _tab_bar() -> TabBar: return get_node("Overlay/Frame/Layout/Body/Stash/Tabs") as TabBar
func _class_label() -> Label: return get_node("Overlay/Frame/Layout/Header/Class") as Label
func _class_chooser() -> OptionButton: return get_node("Overlay/Frame/Layout/Header/ClassChooser") as OptionButton
func _tooltip() -> Control: return get_node("Overlay/ItemTooltip") as Control
func _close_button() -> Button: return get_node("Overlay/Frame/Layout/Footer/Close") as Button
