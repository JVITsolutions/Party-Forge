class_name WarehouseScreen
extends CanvasLayer

const COMPARISON_RESOLVER := preload("res://scripts/ui/storage/item_comparison_resolver.gd")

signal close_requested
signal move_requested(item_id: String, destination_container_id: StringName, destination_slot: int)
signal bulk_action_requested(action_id: StringName, item_ids: PackedStringArray)

var _projection := WarehouseProjection.new()
var _return_focus: Control
var _selected_tab := 0
var _selected_item_id := ""
var _held_item_id := ""
var _selected_ids := PackedStringArray()
var _developer_mode := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_connect_controls()

func open(storage: ProfileStorageProjection, return_focus: Control = null, developer_mode: bool = false) -> void:
	_projection = WarehouseProjection.from_storage(storage)
	_return_focus = return_focus
	_developer_mode = developer_mode
	_selected_tab = mini(_selected_tab, maxi(0, _projection.stash_tabs.size() - 1))
	_selected_ids.clear()
	_held_item_id = ""
	visible = true
	_render_projection()
	if is_inside_tree(): _initial_focus().grab_focus()

func refresh(storage: ProfileStorageProjection) -> void:
	_tooltip().call("force_dismiss")
	_projection = WarehouseProjection.from_storage(storage)
	_render_projection()

func close() -> void:
	_tooltip().call("force_dismiss")
	visible = false
	_held_item_id = ""
	_selected_item_id = ""
	_selected_ids.clear()
	_bulk_status().text = "0 selected"
	if is_inside_tree() and _return_focus != null and is_instance_valid(_return_focus) and _return_focus.is_inside_tree() and _return_focus.is_visible_in_tree(): _return_focus.grab_focus()
	_return_focus = null

func is_open() -> bool: return visible
func stash_tab_count() -> int: return _tabs().tab_count
func slot_button_count() -> int: return _grid().get_child_count()
func selected_item_detail() -> Dictionary: return _projection.item(_selected_item_id)
func projection() -> WarehouseProjection: return WarehouseProjection.from_storage(_projection.storage_projection())

func apply_viewport_size(size: Vector2i) -> void:
	var compact := size.x < 1400 or size.y < 850
	_body().vertical = compact
	_frame().offset_left = 16.0 if compact else 48.0
	_frame().offset_top = 12.0 if compact else 36.0
	_frame().offset_right = -_frame().offset_left
	_frame().offset_bottom = -_frame().offset_top

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed(&"ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"item_sandbox_pickup"):
		var focused := get_viewport().gui_get_focus_owner() as StorageSlotButton
		if focused != null and not focused.item_id.is_empty():
			_held_item_id = focused.item_id
			_selected_item_id = focused.item_id
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and not _held_item_id.is_empty():
		var target := get_viewport().gui_get_focus_owner() as StorageSlotButton
		if target != null:
			_on_drop(&"", -1, _held_item_id, target.container_id, target.slot)
			get_viewport().set_input_as_handled()

func _render_projection() -> void:
	_tabs().clear_tabs()
	for index: int in _projection.stash_tabs.size(): _tabs().add_tab("Tab %d" % (index + 1))
	_tabs().current_tab = _selected_tab if _tabs().tab_count > 0 else -1
	_populate_filters()
	_rebuild_grid()
	_rebuild_focus_loop()

func _populate_filters() -> void:
	if _rarity().item_count == 0:
		_rarity().add_item("All Rarities"); _rarity().set_item_metadata(0, &"")
		for id: StringName in GameCatalog.ITEM_FOUNDATION_CATALOG.supported_rarity_ids(): _rarity().add_item(String(id).capitalize()); _rarity().set_item_metadata(_rarity().item_count - 1, id)
	if _item_type().item_count == 0:
		_item_type().add_item("All Item Types"); _item_type().set_item_metadata(0, &"")
		var types: Array[StringName] = []
		for definition: EquipmentBaseDefinition in GameCatalog.EQUIPMENT_CATALOG.definitions:
			if definition.item_type_id not in types: types.append(definition.item_type_id)
		types.sort()
		for id: StringName in types: _item_type().add_item(String(id).capitalize()); _item_type().set_item_metadata(_item_type().item_count - 1, id)
	if _sort().item_count == 0:
		for entry: Array in [["Stored Position", &""], ["Name", &"name"], ["Item Level", &"item_level"]]: _sort().add_item(entry[0]); _sort().set_item_metadata(_sort().item_count - 1, entry[1])

func _rebuild_grid() -> void:
	_clear(_grid())
	if _selected_tab < 0 or _selected_tab >= _projection.stash_tabs.size(): return
	var tab := _projection.stash_tabs[_selected_tab]
	var displayed: Array[Dictionary] = []
	for detail: Dictionary in _projection.displayed_items(_search().text, _selected_meta(_rarity()), _selected_meta(_item_type()), _selected_meta(_sort())):
		if String(detail["container_id"]) == String(tab["container_id"]): displayed.append(detail)
	var occupied_slots := tab["slots"] as Dictionary
	for slot: int in int(tab["capacity"]):
		if not occupied_slots.has(str(slot)) and not occupied_slots.has(slot):
			displayed.append({"container_id": tab["container_id"], "slot": slot})
	for display_index: int in displayed.size():
		var detail := displayed[display_index]
		var slot := int(detail["slot"])
		var item_id := String(detail.get("instance_id", ""))
		var button := StorageSlotButton.new()
		button.name = "WarehouseCard_%03d" % display_index
		button.bind_item(StringName(tab["container_id"]), slot, item_id, _projection.item(item_id))
		button.item_dropped.connect(_on_drop)
		button.pressed.connect(_select_item.bind(item_id))
		_wire_item_inspection(button)
		_grid().add_child(button)
	_rebuild_focus_loop()

func _on_drop(_source_container: StringName, _source_slot: int, item_id: String, destination_container: StringName, destination_slot: int) -> void:
	if not item_id.is_empty(): move_requested.emit(item_id, destination_container, destination_slot)
	_held_item_id = ""

func _select_item(item_id: String) -> void: _selected_item_id = item_id
func _toggle_bulk(item_id: String) -> void:
	if item_id in _selected_ids: _selected_ids.remove_at(_selected_ids.find(item_id))
	else: _selected_ids.append(item_id)
	_bulk_status().text = "%d selected" % _selected_ids.size()
func _emit_bulk(action: StringName) -> void: bulk_action_requested.emit(action, _selected_ids.duplicate())

func _wire_item_inspection(button: StorageSlotButton) -> void:
	button.inspection_started.connect(_show_item_tooltip)
	button.inspection_ended.connect(_release_item_tooltip)


func _show_item_tooltip(source: StorageSlotButton) -> void:
	var detail := source.detail()
	if detail.is_empty():
		return
	var storage := _projection.storage_projection()
	var comparisons: Array[Dictionary] = COMPARISON_RESOLVER.resolve(detail, storage.leader_slots, storage.item_records)
	_tooltip().call("show_item", detail, comparisons, source, source.source_id(), _developer_mode)


func _release_item_tooltip(source: StorageSlotButton) -> void:
	_tooltip().call("release_item", source.source_id())

func _connect_controls() -> void:
	_close_button().pressed.connect(func() -> void: close_requested.emit())
	_tabs().tab_changed.connect(func(index: int) -> void: _selected_tab = index; _rebuild_grid())
	_search().text_changed.connect(func(_text: String) -> void: _rebuild_grid())
	_rarity().item_selected.connect(func(_index: int) -> void: _rebuild_grid())
	_item_type().item_selected.connect(func(_index: int) -> void: _rebuild_grid())
	_sort().item_selected.connect(func(_index: int) -> void: _rebuild_grid())
	get_node("Overlay/Frame/Layout/Footer/Category") .pressed.connect(_emit_bulk.bind(&"category"))
	get_node("Overlay/Frame/Layout/Footer/BulkMove") .pressed.connect(_emit_bulk.bind(&"move"))
	get_node("Overlay/Frame/Layout/Footer/BulkSelect") .pressed.connect(_toggle_focused_bulk)

func _toggle_focused_bulk() -> void:
	var focused := get_viewport().gui_get_focus_owner() as StorageSlotButton
	if focused != null and not focused.item_id.is_empty(): _toggle_bulk(focused.item_id)

func _selected_meta(control: OptionButton) -> StringName:
	return StringName(control.get_item_metadata(control.selected)) if control.selected >= 0 and control.selected < control.item_count else &""
func _rebuild_focus_loop() -> void:
	var controls: Array[Control] = [_search(), _rarity(), _item_type(), _sort(), _tabs()]
	for child: Node in _grid().get_children(): controls.append(child as Control)
	controls.append(get_node("Overlay/Frame/Layout/Footer/Category") as Control)
	controls.append(get_node("Overlay/Frame/Layout/Footer/BulkMove") as Control)
	controls.append(get_node("Overlay/Frame/Layout/Footer/BulkSelect") as Control)
	controls.append(_close_button())
	for index: int in controls.size():
		var current := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[posmod(index - 1, controls.size())]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
func _clear(parent: Node) -> void:
	for child: Node in parent.get_children(): child.free()
func _initial_focus() -> Control: return _search()
func _frame() -> Control: return get_node("Overlay/Frame") as Control
func _body() -> BoxContainer: return get_node("Overlay/Frame/Layout/Body") as BoxContainer
func _tabs() -> TabBar: return get_node("Overlay/Frame/Layout/Tabs") as TabBar
func _grid() -> GridContainer: return get_node("Overlay/Frame/Layout/Body/Storage/Scroll/Grid") as GridContainer
func _search() -> LineEdit: return get_node("Overlay/Frame/Layout/Organization/Search") as LineEdit
func _rarity() -> OptionButton: return get_node("Overlay/Frame/Layout/Organization/Rarity") as OptionButton
func _item_type() -> OptionButton: return get_node("Overlay/Frame/Layout/Organization/ItemType") as OptionButton
func _sort() -> OptionButton: return get_node("Overlay/Frame/Layout/Organization/Sort") as OptionButton
func _bulk_status() -> Label: return get_node("Overlay/Frame/Layout/Footer/BulkStatus") as Label
func _tooltip() -> Control: return get_node("Overlay/ItemTooltip") as Control
func _close_button() -> Button: return get_node("Overlay/Frame/Layout/Footer/Close") as Button
