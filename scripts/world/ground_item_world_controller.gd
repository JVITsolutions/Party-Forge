class_name GroundItemWorldController
extends Node

signal pickup_requested(drop_id: StringName, input_owner: StringName)
signal status_changed(status: String)
signal projection_diagnostics_changed(diagnostics: Dictionary)

const CHEST_SCENE := preload("res://scenes/world/ground_item_chest.tscn")
const TOOLTIP_SCENE := preload("res://scenes/ui/storage/item_tooltip_panel.tscn")
const COMPARISON_PROJECTOR := preload("res://scripts/ui/storage/equipment_comparison_projection_service.gd")
const SPATIAL_INDEX := preload("res://scripts/loot/ground_item_spatial_index.gd")
const TARGETING_SERVICE := preload("res://scripts/loot/ground_item_targeting_service.gd")
const PICKUP_RESULT := preload("res://scripts/loot/ground_item_pickup_result.gd")
const MAX_INACTIVE_CHESTS := 64
const MAX_PROJECTIONS_PER_FRAME := 32
const DEFAULT_TARGET_RADIUS := 12.0

var _registry: GroundItemRegistry
var _identities: Dictionary = {}
var _presentation_projector: Variant
var _comparison_projector := Callable()
var _camera: Camera3D
var _chests_parent: Node3D
var _tooltip_layer: Node
var _tooltip: ItemTooltipPanel
var _owns_tooltip := false
var _chest_by_drop: Dictionary = {}
var _inactive_chests: Array[Node3D] = []
var _record_by_drop: Dictionary = {}
var _detail_by_drop: Dictionary = {}
var _dirty_drop_ids: Dictionary = {}
var _mouse_inside_by_drop: Dictionary = {}
var _focus_inside_by_drop: Dictionary = {}
var _last_camera_signature: Array = []
var _batch_camera_signature: Array = []
var _pending_reprojection_ids: Array[StringName] = []
var _last_projection_work_count := 0
var _peak_projection_work_count := 0
var _spatial_index: RefCounted
var _targeting_service: RefCounted
var _pickup_service: RefCounted
var _context_registry: RunContextRegistry
var _selection_by_owner: Dictionary = {}
var _status_by_owner: Dictionary = {}
var _target_radius := DEFAULT_TARGET_RADIUS
var _visibility_filter := Callable()
var _modal_filter := Callable()


func configure(
	registry: GroundItemRegistry,
	identities: Dictionary,
	presentation_projector: Variant,
	camera: Camera3D,
	chests_parent: Node3D,
	tooltip_layer: Node,
) -> void:
	_disconnect_registry()
	if _spatial_index != null:
		_spatial_index.call(&"dispose")
	_release_all()
	_release_shared_tooltip()
	_selection_by_owner.clear()
	_status_by_owner.clear()
	_registry = registry
	_spatial_index = SPATIAL_INDEX.new(_registry)
	_targeting_service = TARGETING_SERVICE.new()
	_identities = identities.duplicate(true)
	_presentation_projector = presentation_projector
	_comparison_projector = Callable()
	_camera = camera
	_chests_parent = chests_parent
	_tooltip_layer = tooltip_layer
	_tooltip = _resolve_shared_tooltip()
	_reparent_inactive_projections()
	_last_camera_signature = _camera_signature()
	_batch_camera_signature = _last_camera_signature.duplicate(true)
	_pending_reprojection_ids.clear()
	_last_projection_work_count = 0
	_peak_projection_work_count = 0
	if _registry == null or _chests_parent == null or _tooltip_layer == null or _tooltip == null:
		status_changed.emit("GROUND_ITEM_WORLD_UNAVAILABLE")
		return
	_registry.record_added.connect(_on_record_added)
	_registry.record_removed.connect(_on_record_removed)
	_registry.cleared.connect(_on_registry_cleared)
	for record: GroundItemRecord in _registry.all_records():
		_on_record_added(record)
	_publish_projection_diagnostics()
	status_changed.emit("GROUND_ITEM_WORLD_READY")


func configure_comparisons(projector: Callable) -> void:
	_comparison_projector = projector


func configure_interaction(
	spatial_index: RefCounted,
	targeting_service: RefCounted,
	pickup_service: RefCounted,
	context_registry: RunContextRegistry,
	target_radius: float = DEFAULT_TARGET_RADIUS,
	visibility_filter: Callable = Callable(),
	modal_filter: Callable = Callable(),
) -> void:
	if _spatial_index != null and _spatial_index != spatial_index:
		_spatial_index.call(&"dispose")
	_spatial_index = spatial_index
	_targeting_service = targeting_service
	_pickup_service = pickup_service
	_context_registry = context_registry
	_target_radius = maxf(target_radius, 0.0)
	_visibility_filter = visibility_filter
	_modal_filter = modal_filter


func clear_projection() -> void:
	_disconnect_registry()
	if _spatial_index != null:
		_spatial_index.call(&"dispose")
	_destroy_all_projections()
	_release_shared_tooltip()
	_registry = null
	_identities.clear()
	_presentation_projector = null
	_comparison_projector = Callable()
	_camera = null
	_chests_parent = null
	_tooltip_layer = null
	_last_camera_signature.clear()
	_batch_camera_signature.clear()
	_pending_reprojection_ids.clear()
	_last_projection_work_count = 0
	_peak_projection_work_count = 0
	_spatial_index = null
	_targeting_service = null
	_pickup_service = null
	_context_registry = null
	_selection_by_owner.clear()
	_status_by_owner.clear()
	_visibility_filter = Callable()
	_modal_filter = Callable()


func selection_for_owner(run_player_id: StringName) -> StringName:
	return StringName(_selection_by_owner.get(run_player_id, &""))


func _input(event: InputEvent) -> void:
	if _modal_input_suppressed() or event == null:
		return
	var direction := 0
	if event.is_action_pressed(&"world_loot_previous"):
		direction = -1
	elif event.is_action_pressed(&"world_loot_next"):
		direction = 1
	var owner := _owner_for_event(event)
	if owner.is_empty():
		return
	if direction != 0:
		_cycle_for_owner(owner, direction)
		_mark_input_handled()
	elif event.is_action_pressed(&"ui_accept") and not selection_for_owner(owner).is_empty():
		_collect_for_owner(selection_for_owner(owner), owner)
		_mark_input_handled()


func set_selected(drop_id: StringName, active: bool) -> void:
	var chest := _chest_by_drop.get(drop_id) as Node3D
	if chest == null:
		return
	chest.call(&"set_selected", active)
	_project_anchor(drop_id)


func invalidate_comparisons(run_player_id: StringName = &"") -> void:
	if _tooltip == null or not is_instance_valid(_tooltip) or not _tooltip.visible:
		return
	for drop_value: Variant in _chest_by_drop:
		var drop_id := StringName(drop_value)
		var chest := _chest_by_drop.get(drop_id) as Node3D
		if chest == null or (not run_player_id.is_empty() and StringName(chest.get("run_player_id")) != run_player_id):
			continue
		if not _tooltip.is_current_source(_source_id(drop_id)):
			continue
		var inspection_active := bool(_mouse_inside_by_drop.get(drop_id, false)) or bool(_focus_inside_by_drop.get(drop_id, false))
		_tooltip.force_dismiss()
		if inspection_active:
			_present_tooltip(chest)
		return


func _process(_delta: float) -> void:
	_last_projection_work_count = 0
	var camera_signature := _camera_signature()
	var camera_changed := camera_signature != _last_camera_signature
	if camera_changed:
		_last_camera_signature = camera_signature
		if _pending_reprojection_ids.is_empty():
			_begin_reprojection_batch(camera_signature)
	var projected: Dictionary = {}
	if camera_changed:
		for drop_id: StringName in _critical_projection_ids():
			if _last_projection_work_count >= MAX_PROJECTIONS_PER_FRAME:
				break
			if not _chest_by_drop.has(drop_id):
				continue
			_project_anchor(drop_id)
			projected[drop_id] = true
			_dirty_drop_ids.erase(drop_id)
			_pending_reprojection_ids.erase(drop_id)
			_last_projection_work_count += 1
	var dirty := _dirty_drop_ids.keys()
	_dirty_drop_ids.clear()
	for drop_value: Variant in dirty:
		var dirty_id := StringName(drop_value)
		if projected.has(dirty_id):
			continue
		if _last_projection_work_count >= MAX_PROJECTIONS_PER_FRAME:
			_dirty_drop_ids[dirty_id] = true
			continue
		_project_anchor(dirty_id)
		projected[dirty_id] = true
		_pending_reprojection_ids.erase(dirty_id)
		_last_projection_work_count += 1
	while _last_projection_work_count < MAX_PROJECTIONS_PER_FRAME and not _pending_reprojection_ids.is_empty():
		var drop_id: StringName = _pending_reprojection_ids.pop_front()
		if projected.has(drop_id) or not _chest_by_drop.has(drop_id):
			continue
		_project_anchor(drop_id)
		projected[drop_id] = true
		_last_projection_work_count += 1
	if _pending_reprojection_ids.is_empty() and _batch_camera_signature != _last_camera_signature:
		_begin_reprojection_batch(_last_camera_signature)
	_peak_projection_work_count = maxi(_peak_projection_work_count, _last_projection_work_count)
	_publish_projection_diagnostics()


func projection_diagnostics() -> Dictionary:
	return {
		"last_frame_work": _last_projection_work_count,
		"peak_work": _peak_projection_work_count,
		"pending": _pending_projection_count(),
		"limit": MAX_PROJECTIONS_PER_FRAME,
	}


func _publish_projection_diagnostics() -> void:
	projection_diagnostics_changed.emit(projection_diagnostics())


func _pending_projection_count() -> int:
	var pending: Dictionary = {}
	for drop_id: StringName in _pending_reprojection_ids:
		pending[drop_id] = true
	for value: Variant in _dirty_drop_ids:
		pending[StringName(value)] = true
	return pending.size()


func _critical_projection_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	for source: Dictionary in [_selection_by_owner, _mouse_inside_by_drop, _focus_inside_by_drop]:
		var ids: Array[StringName] = []
		if source == _selection_by_owner:
			for value: Variant in source.values():
				ids.append(StringName(value))
		else:
			for value: Variant in source.keys():
				ids.append(StringName(value))
		ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
		for drop_id: StringName in ids:
			if drop_id.is_empty() or seen.has(drop_id):
				continue
			seen[drop_id] = true
			result.append(drop_id)
	return result


func _begin_reprojection_batch(signature: Array) -> void:
	_pending_reprojection_ids.clear()
	for value: Variant in _chest_by_drop.keys():
		_pending_reprojection_ids.append(StringName(value))
	_pending_reprojection_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	_batch_camera_signature = signature.duplicate(true)


func _on_record_added(record: GroundItemRecord) -> void:
	if record == null or record.drop_id.is_empty() or _chests_parent == null:
		status_changed.emit("GROUND_ITEM_WORLD_RECORD_REJECTED")
		return
	if _chest_by_drop.has(record.drop_id):
		status_changed.emit("GROUND_ITEM_WORLD_DUPLICATE drop_id=%s" % record.drop_id)
		return
	var identity := _identities.get(record.run_player_id, {}) as Dictionary
	var owner_color: Variant = identity.get("color")
	if not owner_color is Color:
		owner_color = PlayerColorPalette.color(record.color_id)
		status_changed.emit("GROUND_ITEM_WORLD_IDENTITY_FALLBACK drop_id=%s" % record.drop_id)
	var detail := _detail_for(record)
	_decorate_detail(detail, record, identity)
	var visual_record := record.copy()
	visual_record.player_number = int(identity.get("player_number", record.player_number))
	var chest: Node3D = _take_chest()
	_chest_by_drop[record.drop_id] = chest
	_record_by_drop[record.drop_id] = record.copy()
	_detail_by_drop[record.drop_id] = detail.duplicate(true)
	chest.call(&"bind", visual_record, detail, owner_color as Color)
	var anchor := chest.call(&"tooltip_anchor") as Control
	if anchor.get_parent() != _tooltip_layer:
		anchor.get_parent().remove_child(anchor)
		_tooltip_layer.add_child(anchor)
	_project_anchor(record.drop_id)


func _on_record_removed(record: GroundItemRecord) -> void:
	if record == null:
		return
	var was_selected := selection_for_owner(record.run_player_id) == record.drop_id
	var next_drop_id := _nearest_remaining_visible(record.run_player_id, record.drop_id) if was_selected else &""
	if was_selected:
		_selection_by_owner.erase(record.run_player_id)
		_status_by_owner.erase(record.run_player_id)
	_release_chest(record.drop_id)
	if not next_drop_id.is_empty():
		_apply_selection(record.run_player_id, next_drop_id)


func _on_registry_cleared() -> void:
	_selection_by_owner.clear()
	_status_by_owner.clear()
	_release_all()


func _take_chest() -> Node3D:
	var chest := _inactive_chests.pop_back() as Node3D if not _inactive_chests.is_empty() else CHEST_SCENE.instantiate() as Node3D
	_reparent_node(chest, _chests_parent)
	if not chest.is_connected(&"pickup_requested", _on_chest_pickup_requested):
		chest.connect(&"pickup_requested", _on_chest_pickup_requested)
	var anchor := chest.call(&"tooltip_anchor") as Control
	if not anchor.mouse_entered.is_connected(_on_anchor_mouse_entered.bind(chest)):
		anchor.mouse_entered.connect(_on_anchor_mouse_entered.bind(chest))
		anchor.focus_entered.connect(_on_anchor_focus_entered.bind(chest))
		anchor.mouse_exited.connect(_on_anchor_mouse_exited.bind(chest))
		anchor.focus_exited.connect(_on_anchor_focus_exited.bind(chest))
		anchor.gui_input.connect(_on_anchor_gui_input.bind(chest))
	return chest


func _release_chest(drop_id: StringName) -> void:
	var chest := _chest_by_drop.get(drop_id) as Node3D
	if chest == null:
		return
	if _tooltip != null and _tooltip.is_current_source(_source_id(drop_id)):
		_tooltip.force_dismiss()
	_chest_by_drop.erase(drop_id)
	_record_by_drop.erase(drop_id)
	_detail_by_drop.erase(drop_id)
	_dirty_drop_ids.erase(drop_id)
	_mouse_inside_by_drop.erase(drop_id)
	_focus_inside_by_drop.erase(drop_id)
	chest.call(&"deactivate")
	if _inactive_chests.size() < MAX_INACTIVE_CHESTS:
		_inactive_chests.append(chest)
		return
	_destroy_chest(chest)


func _release_all() -> void:
	var drop_ids := _chest_by_drop.keys()
	for drop_value: Variant in drop_ids:
		_release_chest(StringName(drop_value))


func _detail_for(record: GroundItemRecord) -> Dictionary:
	var projected: Variant
	if _presentation_projector is Callable and (_presentation_projector as Callable).is_valid():
		projected = (_presentation_projector as Callable).call(record.copy())
	elif _presentation_projector is Object and (_presentation_projector as Object).has_method(&"project_record"):
		projected = (_presentation_projector as Object).call(&"project_record", record.copy())
	if projected is Dictionary and not (projected as Dictionary).has("error"):
		return (projected as Dictionary).duplicate(true)
	status_changed.emit("GROUND_ITEM_WORLD_PRESENTATION_FALLBACK drop_id=%s" % record.drop_id)
	return {
		"instance_id": record.item_id,
		"name": "Unknown Item",
		"rarity_id": String(record.rarity_id),
		"rarity_name": String(record.rarity_id).capitalize(),
		"item_level": 0,
		"compatible_slot_ids": [],
		"affixes": [],
		"modifier_totals": {},
	}


func _comparisons_for(record: GroundItemRecord, detail: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if record == null or not _comparison_projector.is_valid():
		return result
	var compatible: Array = detail.get("compatible_slot_ids", [])
	var equipment_value: Variant = _comparison_projector.call(record.copy(), detail.duplicate(true))
	if not equipment_value is Array:
		return result
	for value: Variant in equipment_value as Array:
		if not value is Dictionary:
			continue
		var entry := value as Dictionary
		var slot_id := String(entry.get("slot_id", ""))
		if slot_id not in compatible:
			continue
		var equipped_value: Variant = entry.get("item", {})
		var current := entry.get("current_stats") as ResolvedStatSnapshot
		var candidate := entry.get("candidate_stats") as ResolvedStatSnapshot
		if not equipped_value is Dictionary or (equipped_value as Dictionary).is_empty() or current == null or candidate == null:
			continue
		result.append({
			"slot_id": slot_id,
			"item": (equipped_value as Dictionary).duplicate(true),
			"delta_lines": COMPARISON_PROJECTOR.compare(current, candidate, GameCatalog.STAT_CATALOG),
		})
	return result


func _project_anchor(drop_id: StringName) -> void:
	var chest := _chest_by_drop.get(drop_id) as Node3D
	if chest == null:
		return
	var anchor := chest.call(&"tooltip_anchor") as Control
	var world_position := chest.global_position if chest.is_inside_tree() else chest.position
	var record := _record_by_drop.get(drop_id) as GroundItemRecord
	var distance := _distance_for_record(record, world_position)
	chest.call(&"_refresh_accessibility", distance)
	if chest.call(&"is_selected"):
		chest.call(&"set_distance_feedback", distance, String(_status_by_owner.get(StringName(chest.get("run_player_id")), "")))
	var cached_detail := _detail_by_drop.get(drop_id, {}) as Dictionary
	if not cached_detail.is_empty():
		cached_detail["distance_meters"] = distance
	if _camera == null or not is_instance_valid(_camera):
		anchor.visible = chest.visible
		return
	var elevated_position: Vector3 = world_position + Vector3.UP * 1.55
	if _camera.is_inside_tree():
		var projected := _camera.unproject_position(elevated_position)
		anchor.position = projected - anchor.size * 0.5
		var viewport_rect := _camera.get_viewport().get_visible_rect()
		var inset_size := viewport_rect.size - anchor.size
		var anchor_fits := inset_size.x >= 0.0 and inset_size.y >= 0.0 and Rect2(viewport_rect.position + anchor.size * 0.5, inset_size).has_point(projected)
		anchor.visible = chest.visible and not _camera.is_position_behind(elevated_position) and anchor_fits
		return
	var camera_space := _camera.transform.affine_inverse() * elevated_position
	var projection_scale := 100.0 / tan(deg_to_rad(_camera.fov) * 0.5) if _camera.projection == Camera3D.PROJECTION_PERSPECTIVE else 200.0 / maxf(_camera.size, 0.001)
	anchor.position = Vector2(camera_space.x, -camera_space.y) * projection_scale - anchor.size * 0.5
	anchor.visible = chest.visible and camera_space.z < 0.0


func _on_anchor_mouse_entered(chest: Node3D) -> void:
	var drop_id := _drop_id_for(chest)
	if drop_id.is_empty():
		return
	_mouse_inside_by_drop[drop_id] = true
	_present_tooltip(chest)


func _on_anchor_focus_entered(chest: Node3D) -> void:
	var drop_id := _drop_id_for(chest)
	if drop_id.is_empty():
		return
	_focus_inside_by_drop[drop_id] = true
	_present_tooltip(chest)


func _on_anchor_mouse_exited(chest: Node3D) -> void:
	var drop_id := _drop_id_for(chest)
	if drop_id.is_empty():
		return
	_mouse_inside_by_drop.erase(drop_id)
	_release_tooltip_if_inactive(drop_id)


func _on_anchor_focus_exited(chest: Node3D) -> void:
	var drop_id := _drop_id_for(chest)
	if drop_id.is_empty():
		return
	_focus_inside_by_drop.erase(drop_id)
	_release_tooltip_if_inactive(drop_id)


func _present_tooltip(chest: Node3D) -> void:
	if chest == null or _tooltip == null or StringName(chest.get("drop_id")).is_empty():
		return
	var chest_drop_id := StringName(chest.get("drop_id"))
	var detail := _refresh_detail(chest_drop_id)
	var record := _record_by_drop.get(chest_drop_id) as GroundItemRecord
	var comparisons := _comparisons_for(record, detail)
	_tooltip.show_item(detail, comparisons, chest.call(&"tooltip_anchor") as Control, _source_id(chest_drop_id))


func _release_tooltip_if_inactive(drop_id: StringName) -> void:
	if _tooltip == null or drop_id.is_empty():
		return
	if bool(_mouse_inside_by_drop.get(drop_id, false)) or bool(_focus_inside_by_drop.get(drop_id, false)):
		return
	_tooltip.release_item(_source_id(drop_id))


func _on_anchor_gui_input(event: InputEvent, chest: Node3D) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT or _modal_input_suppressed() or chest == null:
		return
	var input_owner := _owner_for_event(mouse)
	if input_owner.is_empty():
		return
	chest.call(&"request_pickup", input_owner)
	_mark_input_handled()


func _on_chest_pickup_requested(drop_id: StringName, input_owner: StringName) -> void:
	var chest := _chest_by_drop.get(drop_id) as Node3D
	if chest == null or StringName(chest.get("run_player_id")) != input_owner:
		return
	pickup_requested.emit(drop_id, input_owner)
	_collect_for_owner(drop_id, input_owner)


func _cycle_for_owner(run_player_id: StringName, direction: int) -> void:
	if _spatial_index == null or _targeting_service == null:
		return
	var leader_position := _leader_position_for(run_player_id)
	if not bool(leader_position.get("valid", false)):
		return
	var next := StringName(_targeting_service.call(
		&"cycle",
		selection_for_owner(run_player_id), direction, _spatial_index, run_player_id,
		leader_position.position as Vector3, _target_radius, Callable(self, "_record_visible"),
	))
	if not next.is_empty():
		_apply_selection(run_player_id, next)


func _apply_selection(run_player_id: StringName, drop_id: StringName) -> void:
	var previous := selection_for_owner(run_player_id)
	if previous == drop_id:
		_inspect_selection(run_player_id, drop_id)
		return
	if not previous.is_empty():
		_focus_inside_by_drop.erase(previous)
		set_selected(previous, false)
	_selection_by_owner[run_player_id] = drop_id
	_status_by_owner.erase(run_player_id)
	set_selected(drop_id, true)
	_inspect_selection(run_player_id, drop_id)


func _inspect_selection(run_player_id: StringName, drop_id: StringName) -> void:
	var chest := _chest_by_drop.get(drop_id) as Node3D
	if chest == null or StringName(chest.get("run_player_id")) != run_player_id:
		return
	_project_anchor(drop_id)
	var anchor := chest.call(&"tooltip_anchor") as Control
	_focus_inside_by_drop[drop_id] = true
	if anchor != null and anchor.is_inside_tree() and anchor.is_visible_in_tree():
		anchor.grab_focus()
	_present_tooltip(chest)


func _collect_for_owner(drop_id: StringName, run_player_id: StringName) -> void:
	if _pickup_service == null:
		return
	var result := _pickup_service.call(&"collect", drop_id, run_player_id) as RefCounted
	if result == null:
		return
	match result.code:
		PICKUP_RESULT.Code.MOVE_CLOSER:
			_status_by_owner[run_player_id] = "Move closer"
			_refresh_selection_feedback(run_player_id)
			status_changed.emit("Move closer")
		PICKUP_RESULT.Code.INVENTORY_FULL:
			status_changed.emit("Inventory full")
		PICKUP_RESULT.Code.NOT_OWNER:
			status_changed.emit("GROUND_ITEM_PICKUP_NOT_OWNER")
		PICKUP_RESULT.Code.MISSING:
			status_changed.emit("GROUND_ITEM_PICKUP_MISSING")
		PICKUP_RESULT.Code.TRANSACTION_REJECTED:
			status_changed.emit("GROUND_ITEM_PICKUP_TRANSACTION_REJECTED")
		PICKUP_RESULT.Code.OK:
			_status_by_owner.erase(run_player_id)
			status_changed.emit("GROUND_ITEM_PICKUP_OK")


func _refresh_selection_feedback(run_player_id: StringName) -> void:
	var drop_id := selection_for_owner(run_player_id)
	if not drop_id.is_empty():
		_project_anchor(drop_id)


func _owner_for_event(event: InputEvent) -> StringName:
	if _context_registry == null:
		return &""
	var event_device := event.device
	for context: PlayerRunContext in _context_registry.all_contexts():
		var owned_device := _context_registry.device_for(context.run_player_id)
		if event is InputEventJoypadButton or event is InputEventJoypadMotion or (event is InputEventMouseButton and event_device >= 0):
			if owned_device == event_device:
				return context.run_player_id
		elif owned_device == -1:
			return context.run_player_id
	return &""


func _leader_position_for(run_player_id: StringName) -> Dictionary:
	var context := _context_registry.context_for(run_player_id) if _context_registry != null else null
	if context == null or context.party == null or context.party.members.is_empty():
		return {"valid": false}
	return context.member_position(context.party.members[0].member_id)


func _record_visible(record: GroundItemRecord) -> bool:
	if record == null:
		return false
	if _visibility_filter.is_valid() and not bool(_visibility_filter.call(record.copy())):
		return false
	var chest := _chest_by_drop.get(record.drop_id) as Node3D
	if chest == null or not chest.visible:
		return false
	return _world_position_visible(record.world_position + Vector3.UP * 1.55)


func _world_position_visible(world_position: Vector3) -> bool:
	if _camera == null or not is_instance_valid(_camera):
		return true
	if not _camera.is_inside_tree():
		return (_camera.transform.affine_inverse() * world_position).z < 0.0
	if _camera.is_position_behind(world_position):
		return false
	var projected := _camera.unproject_position(world_position)
	return _camera.get_viewport().get_visible_rect().has_point(projected)


func _modal_input_suppressed() -> bool:
	return _modal_filter.is_valid() and bool(_modal_filter.call())


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _resolve_shared_tooltip() -> ItemTooltipPanel:
	if _tooltip_layer == null:
		return null
	for child: Node in _tooltip_layer.get_children():
		if child is ItemTooltipPanel:
			_owns_tooltip = false
			return child as ItemTooltipPanel
	var tooltip := TOOLTIP_SCENE.instantiate() as ItemTooltipPanel
	_tooltip_layer.add_child(tooltip)
	_owns_tooltip = true
	return tooltip


func _release_shared_tooltip() -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		_tooltip = null
		_owns_tooltip = false
		return
	_tooltip.force_dismiss()
	if _owns_tooltip:
		_tooltip.free()
	_tooltip = null
	_owns_tooltip = false


func _reparent_inactive_projections() -> void:
	if _chests_parent == null or _tooltip_layer == null:
		return
	for chest: Node3D in _inactive_chests:
		if chest == null or not is_instance_valid(chest):
			continue
		_reparent_node(chest, _chests_parent)
		_reparent_node(chest.call(&"tooltip_anchor") as Control, _tooltip_layer)


func _reparent_node(node: Node, parent: Node) -> void:
	if node == null or parent == null or node.get_parent() == parent:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	parent.add_child(node)


func _destroy_chest(chest: Node3D) -> void:
	if chest == null or not is_instance_valid(chest):
		return
	var anchor := chest.call(&"tooltip_anchor") as Control
	if anchor != null and is_instance_valid(anchor):
		anchor.free()
	chest.free()


func _destroy_all_projections() -> void:
	var seen: Dictionary = {}
	for value: Variant in _chest_by_drop.values():
		var chest := value as Node3D
		if chest != null and not seen.has(chest.get_instance_id()):
			seen[chest.get_instance_id()] = true
			_destroy_chest(chest)
	for chest: Node3D in _inactive_chests:
		if chest != null and is_instance_valid(chest) and not seen.has(chest.get_instance_id()):
			seen[chest.get_instance_id()] = true
			_destroy_chest(chest)
	_chest_by_drop.clear()
	_inactive_chests.clear()
	_record_by_drop.clear()
	_detail_by_drop.clear()
	_dirty_drop_ids.clear()
	_pending_reprojection_ids.clear()
	_mouse_inside_by_drop.clear()
	_focus_inside_by_drop.clear()


func _disconnect_registry() -> void:
	if _registry == null:
		return
	if _registry.record_added.is_connected(_on_record_added):
		_registry.record_added.disconnect(_on_record_added)
	if _registry.record_removed.is_connected(_on_record_removed):
		_registry.record_removed.disconnect(_on_record_removed)
	if _registry.cleared.is_connected(_on_registry_cleared):
		_registry.cleared.disconnect(_on_registry_cleared)


func _exit_tree() -> void:
	clear_projection()


func _distance_to_camera(world_position: Vector3) -> float:
	if _camera == null or not is_instance_valid(_camera):
		return world_position.length()
	var camera_position := _camera.global_position if _camera.is_inside_tree() else _camera.position
	return camera_position.distance_to(world_position)


func _distance_for_record(record: GroundItemRecord, world_position: Vector3) -> float:
	if record != null:
		var leader_position := _leader_position_for(record.run_player_id)
		if bool(leader_position.get("valid", false)):
			return (leader_position.position as Vector3).distance_to(world_position)
	return _distance_to_camera(world_position)


func _nearest_remaining_visible(run_player_id: StringName, excluded_drop_id: StringName) -> StringName:
	var leader_position := _leader_position_for(run_player_id)
	if not bool(leader_position.get("valid", false)):
		return &""
	var origin := leader_position.position as Vector3
	var best_id: StringName
	var best_distance := INF
	for value: Variant in _record_by_drop.values():
		var record := value as GroundItemRecord
		if record == null or record.drop_id == excluded_drop_id or record.run_player_id != run_player_id or not _record_visible(record):
			continue
		var distance := origin.distance_squared_to(record.world_position)
		if distance < best_distance or (distance == best_distance and (best_id.is_empty() or String(record.drop_id) < String(best_id))):
			best_id = record.drop_id
			best_distance = distance
	return best_id


func _refresh_detail(drop_id: StringName) -> Dictionary:
	var record := _record_by_drop.get(drop_id) as GroundItemRecord
	if record == null:
		return (_detail_by_drop.get(drop_id, {}) as Dictionary).duplicate(true)
	var detail := _detail_for(record)
	var identity := _identities.get(record.run_player_id, {}) as Dictionary
	_decorate_detail(detail, record, identity)
	_detail_by_drop[drop_id] = detail.duplicate(true)
	return detail


func _decorate_detail(detail: Dictionary, record: GroundItemRecord, identity: Dictionary) -> void:
	detail["distance_meters"] = _distance_for_record(record, record.world_position)
	detail["owner_player_number"] = int(identity.get("player_number", record.player_number))
	detail["owner_run_player_id"] = String(record.run_player_id)


func _camera_signature() -> Array:
	if _camera == null or not is_instance_valid(_camera):
		return []
	var viewport_rect := _camera.get_viewport().get_visible_rect() if _camera.is_inside_tree() and _camera.get_viewport() != null else Rect2()
	return [
		_camera.global_transform if _camera.is_inside_tree() else _camera.transform,
		_camera.projection,
		_camera.fov,
		_camera.size,
		_camera.near,
		_camera.far,
		_camera.keep_aspect,
		_camera.h_offset,
		_camera.v_offset,
		_camera.frustum_offset,
		viewport_rect,
	]


func _drop_id_for(chest: Node3D) -> StringName:
	return StringName(chest.get("drop_id")) if chest != null and is_instance_valid(chest) else &""


func _source_id(drop_id: StringName) -> StringName:
	return StringName("ground-loot:%s" % drop_id)
