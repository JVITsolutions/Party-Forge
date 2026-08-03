class_name PassiveTreeScreen
extends CanvasLayer

signal tree_closed

const UNAVAILABLE_STATUS := "City passive tree unavailable"
const RESPEC_SERVICE_ID := "service:passive_respec"

var _tree_definition: PassiveTreeDefinition
var _profiles: ProfileManager
var _mutations: PassiveTreeMutationService
var _view_model: PassiveTreeViewModel
var _developer_context := false
var _profile_root := ProfileStore.DEFAULT_ROOT
var _views: Dictionary = {}
var _pause_lease := RunPauseLease.new()
var _return_focus: Control
var _pending_action := ""
var _transaction_serial := 0
var _processing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_canvas().selection_changed.connect(_on_selection_changed)
	_allocate_button().pressed.connect(_request_allocate)
	_refund_button().pressed.connect(_request_refund)
	_confirm_button().pressed.connect(_confirm_action)
	_cancel_button().pressed.connect(_cancel_confirmation)
	_close_button().pressed.connect(close)
	_confirmation().visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _pause_lease != null and _pause_lease.is_active():
		_pause_lease.release(Engine.get_main_loop() as SceneTree)


func configure(
	tree: PassiveTreeDefinition,
	profiles: ProfileManager,
	mutations: PassiveTreeMutationService,
	view_model: PassiveTreeViewModel,
	developer_context: bool,
	profile_root: String = ProfileStore.DEFAULT_ROOT,
) -> void:
	if is_open():
		close()
	_tree_definition = tree
	_profiles = profiles
	_mutations = mutations
	_view_model = view_model
	_developer_context = developer_context
	_profile_root = profile_root
	_rebuild()


func open(return_focus: Control = null) -> void:
	_return_focus = return_focus
	_rebuild(_canvas().selected_node_id())
	visible = true
	_pause_lease.acquire(Engine.get_main_loop() as SceneTree)
	var selected := _canvas().node_control(_canvas().selected_node_id())
	if selected != null and selected.is_inside_tree() and selected.is_visible_in_tree():
		selected.grab_focus()
	elif _close_button().is_inside_tree() and _close_button().is_visible_in_tree():
		_close_button().grab_focus()


func close() -> void:
	var was_open := is_open()
	_cancel_confirmation()
	visible = false
	_pause_lease.release(Engine.get_main_loop() as SceneTree)
	if is_inside_tree() and _return_focus != null and is_instance_valid(_return_focus) and _return_focus.is_inside_tree() and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null
	if was_open:
		tree_closed.emit()


func is_open() -> bool:
	return visible


func apply_viewport_size(size: Vector2) -> void:
	var compact := size.x < 1600.0 or size.y < 900.0
	var frame := get_node("Overlay/Frame") as Control
	frame.offset_left = 20.0 if compact else 48.0
	frame.offset_top = 16.0 if compact else 36.0
	frame.offset_right = -20.0 if compact else -48.0
	frame.offset_bottom = -16.0 if compact else -36.0
	var body := get_node("Overlay/Frame/Layout/Body") as SplitContainer
	body.split_offset = int(maxf(560.0, (size.x - absf(frame.offset_left) - absf(frame.offset_right)) * 0.68))


func layout_snapshot(viewport_size: Vector2) -> Dictionary:
	var compact := viewport_size.x < 1600.0 or viewport_size.y < 900.0
	var margin := Vector2(20, 16) if compact else Vector2(48, 36)
	var frame := Rect2(margin, viewport_size - margin * 2.0)
	var header_height := 64.0
	var status_height := 52.0
	var body_top := frame.position.y + header_height
	var body_height := maxf(1.0, frame.size.y - header_height - status_height)
	var canvas_width := frame.size.x * 0.68
	return {
		"frame": frame,
		"points": Rect2(frame.position + Vector2(frame.size.x * 0.55, 8), Vector2(frame.size.x * 0.25, 48)),
		"canvas": Rect2(Vector2(frame.position.x, body_top), Vector2(canvas_width, body_height)),
		"detail": Rect2(Vector2(frame.position.x + canvas_width, body_top), Vector2(frame.size.x - canvas_width, body_height)),
		"confirmation": Rect2(frame.get_center() - Vector2(230, 100), Vector2(460, 200)),
	}


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if _confirmation().visible and event.is_action_pressed(&"ui_cancel"):
		_cancel_confirmation()
		_mark_input_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		close()
		_mark_input_handled()


func _rebuild(preferred_id: StringName = &"") -> void:
	_views.clear()
	_canvas().rebuild([], [])
	_clear_detail()
	if _tree_definition == null or _profiles == null or _mutations == null or _view_model == null:
		_show_unavailable()
		return
	var profile := _profiles.active_profile()
	if profile == null:
		_show_unavailable()
		return
	var projection := _view_model.build(_tree_definition, profile, _developer_context)
	if not String(projection.get("status", "")).is_empty():
		_show_unavailable()
		return
	_title().text = String(projection.get("tree_name", "City Passive Tree"))
	_points().text = String(projection.get("points_text", "Passive Points: 0 / 0"))
	_status().text = ""
	var projected_nodes: Array = projection.get("nodes", []) as Array
	for value: Variant in projected_nodes:
		var view := value as PassiveTreeNodeViewData
		if view != null:
			_views[view.id] = view.copy()
	_canvas().rebuild(projected_nodes, projection.get("connections", []) as Array)
	var selection := preferred_id if _views.has(preferred_id) else _default_selection()
	if not selection.is_empty():
		_canvas().select_node(selection)
	else:
		_update_mutation_buttons(null)


func _show_unavailable() -> void:
	_title().text = "City Passive Tree"
	_points().text = "Passive Points: 0 / 0"
	_status().text = UNAVAILABLE_STATUS
	_allocate_button().disabled = true
	_refund_button().disabled = true


func _default_selection() -> StringName:
	var ids := _canvas().node_ids()
	for node_id: StringName in ids:
		var view := _views[node_id] as PassiveTreeNodeViewData
		if view.allocated:
			return node_id
	return ids[0] if not ids.is_empty() else &""


func _on_selection_changed(node_id: StringName) -> void:
	var view := _views.get(node_id) as PassiveTreeNodeViewData
	if view == null:
		_clear_detail()
		return
	if view.state == &"obscured":
		_detail_title().text = "???"
		_detail_description().text = "???"
		_detail_sections().text = ""
	else:
		_detail_title().text = view.display_name
		_detail_description().text = view.description
		var sections: Array[String] = []
		_append_section(sections, "Effects", view.effect_lines)
		_append_section(sections, "Requirements", view.requirement_lines)
		_append_section(sections, "Keywords", view.keyword_lines)
		_detail_sections().text = "\n\n".join(sections)
	_update_mutation_buttons(view)


func _append_section(sections: Array[String], title: String, lines: Array[String]) -> void:
	if not lines.is_empty():
		sections.append("%s\n%s" % [title, "\n".join(lines)])


func _clear_detail() -> void:
	_detail_title().text = "Select a node"
	_detail_description().text = ""
	_detail_sections().text = ""
	_update_mutation_buttons(null)


func _update_mutation_buttons(view: PassiveTreeNodeViewData) -> void:
	_allocate_button().disabled = view == null or not view.allocatable or _processing
	_refund_button().disabled = view == null or not view.allocated or view.permanent or _processing


func _request_allocate() -> void:
	_request_confirmation("allocate")


func _request_refund() -> void:
	_request_confirmation("refund")


func _request_confirmation(action: String) -> void:
	if _processing:
		return
	var view := _views.get(_canvas().selected_node_id()) as PassiveTreeNodeViewData
	if view == null or (action == "allocate" and not view.allocatable) or (action == "refund" and (not view.allocated or view.permanent)):
		return
	_pending_action = action
	_confirmation_text().text = "%s %s?" % ["Allocate" if action == "allocate" else "Refund", view.display_name]
	_confirmation().visible = true
	if _cancel_button().is_inside_tree() and _cancel_button().is_visible_in_tree():
		_cancel_button().grab_focus()


func _cancel_confirmation() -> void:
	_pending_action = ""
	_confirmation().visible = false
	_confirm_button().disabled = false
	var selected := _canvas().node_control(_canvas().selected_node_id())
	if selected != null and selected.is_inside_tree() and selected.is_visible_in_tree():
		selected.grab_focus()


func _confirm_action() -> void:
	if _processing or _pending_action.is_empty():
		return
	var profile := _profiles.active_profile() if _profiles != null else null
	var node_id := _canvas().selected_node_id()
	if profile == null or node_id.is_empty() or _mutations == null or _tree_definition == null:
		_status().text = UNAVAILABLE_STATUS
		_cancel_confirmation()
		return
	_processing = true
	_confirm_button().disabled = true
	_transaction_serial += 1
	var transaction_id := "passive-tree-screen-%s-%s-%d-%d" % [profile.profile_id, _pending_action, Time.get_ticks_usec(), _transaction_serial]
	var action := _pending_action
	var result: ProfileMutationResult
	if action == "allocate":
		result = _mutations.allocate(profile.profile_id, transaction_id, _tree_definition, node_id, _developer_context, _profile_root)
	else:
		var has_respec_service := RESPEC_SERVICE_ID in profile.permanent_feature_unlocks
		result = _mutations.refund(profile.profile_id, transaction_id, _tree_definition, node_id, _developer_context, has_respec_service, _profile_root)
	_processing = false
	if result == null or not result.ok():
		_status().text = result.error if result != null else UNAVAILABLE_STATUS
		_cancel_confirmation()
		_update_mutation_buttons(_views.get(node_id) as PassiveTreeNodeViewData)
		return
	var refresh_error := _profiles.refresh_profile(result.profile.profile_id)
	if not refresh_error.is_empty():
		_status().text = refresh_error
		_cancel_confirmation()
		return
	_pending_action = ""
	_confirmation().visible = false
	_confirm_button().disabled = false
	_rebuild(node_id)
	var rebuilt := _views.get(node_id) as PassiveTreeNodeViewData
	_status().text = "%s %s." % ["Allocated" if action == "allocate" else "Refunded", rebuilt.display_name if rebuilt != null else String(node_id)]


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _canvas() -> PassiveTreeCanvas:
	return get_node("Overlay/Frame/Layout/Body/Canvas") as PassiveTreeCanvas


func _title() -> Label:
	return get_node("Overlay/Frame/Layout/Header/Title") as Label


func _points() -> Label:
	return get_node("Overlay/Frame/Layout/Header/Points") as Label


func _status() -> Label:
	return get_node("Overlay/Frame/Layout/Status") as Label


func _detail_title() -> Label:
	return get_node("Overlay/Frame/Layout/Body/DetailScroll/DetailBody/DetailTitle") as Label


func _detail_description() -> Label:
	return get_node("Overlay/Frame/Layout/Body/DetailScroll/DetailBody/DetailDescription") as Label


func _detail_sections() -> Label:
	return get_node("Overlay/Frame/Layout/Body/DetailScroll/DetailBody/DetailSections") as Label


func _allocate_button() -> Button:
	return get_node("Overlay/Frame/Layout/Body/DetailScroll/DetailBody/Actions/AllocateButton") as Button


func _refund_button() -> Button:
	return get_node("Overlay/Frame/Layout/Body/DetailScroll/DetailBody/Actions/RefundButton") as Button


func _close_button() -> Button:
	return get_node("Overlay/Frame/Layout/Header/CloseButton") as Button


func _confirmation() -> Control:
	return get_node("Overlay/Confirmation") as Control


func _confirmation_text() -> Label:
	return get_node("Overlay/Confirmation/Content/ConfirmationText") as Label


func _confirm_button() -> Button:
	return get_node("Overlay/Confirmation/Content/Buttons/ConfirmButton") as Button


func _cancel_button() -> Button:
	return get_node("Overlay/Confirmation/Content/Buttons/CancelButton") as Button
