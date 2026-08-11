class_name GroundItemWorldController
extends Node

signal pickup_requested(drop_id: StringName, input_owner: StringName)
signal status_changed(status: String)

const CHEST_SCENE := preload("res://scenes/world/ground_item_chest.tscn")
const TOOLTIP_SCENE := preload("res://scenes/ui/storage/item_tooltip_panel.tscn")
const COMPARISON_PROJECTOR := preload("res://scripts/ui/storage/equipment_comparison_projection_service.gd")
const MAX_INACTIVE_CHESTS := 64

var _registry: GroundItemRegistry
var _identities: Dictionary = {}
var _presentation_projector: Variant
var _camera: Camera3D
var _chests_parent: Node3D
var _tooltip_layer: Node
var _tooltip: ItemTooltipPanel
var _chest_by_drop: Dictionary = {}
var _inactive_chests: Array[Node3D] = []
var _detail_by_drop: Dictionary = {}
var _comparisons_by_drop: Dictionary = {}
var _dirty_drop_ids: Dictionary = {}


func configure(
	registry: GroundItemRegistry,
	identities: Dictionary,
	presentation_projector: Variant,
	camera: Camera3D,
	chests_parent: Node3D,
	tooltip_layer: Node,
) -> void:
	_disconnect_registry()
	_release_all()
	_registry = registry
	_identities = identities.duplicate(true)
	_presentation_projector = presentation_projector
	_camera = camera
	_chests_parent = chests_parent
	_tooltip_layer = tooltip_layer
	_tooltip = _resolve_shared_tooltip()
	if _registry == null or _chests_parent == null or _tooltip_layer == null or _tooltip == null:
		status_changed.emit("GROUND_ITEM_WORLD_UNAVAILABLE")
		return
	_registry.record_added.connect(_on_record_added)
	_registry.record_removed.connect(_on_record_removed)
	_registry.cleared.connect(_on_registry_cleared)
	for record: GroundItemRecord in _registry.all_records():
		_on_record_added(record)
	status_changed.emit("GROUND_ITEM_WORLD_READY")


func set_selected(drop_id: StringName, active: bool) -> void:
	var chest := _chest_by_drop.get(drop_id) as Node3D
	if chest == null:
		return
	chest.call(&"set_selected", active)
	_dirty_drop_ids[drop_id] = true


func _process(_delta: float) -> void:
	if _dirty_drop_ids.is_empty():
		return
	var dirty := _dirty_drop_ids.keys()
	_dirty_drop_ids.clear()
	for drop_value: Variant in dirty:
		_project_anchor(StringName(drop_value))


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
	detail["distance_meters"] = _distance_to_camera(record.world_position)
	detail["owner_player_number"] = int(identity.get("player_number", record.player_number))
	detail["owner_run_player_id"] = String(record.run_player_id)
	var visual_record := record.copy()
	visual_record.player_number = int(identity.get("player_number", record.player_number))
	var chest: Node3D = _take_chest()
	_chest_by_drop[record.drop_id] = chest
	_detail_by_drop[record.drop_id] = detail.duplicate(true)
	_comparisons_by_drop[record.drop_id] = _comparisons_for(detail)
	chest.call(&"bind", visual_record, detail, owner_color as Color)
	var anchor := chest.call(&"tooltip_anchor") as Control
	if anchor.get_parent() != _tooltip_layer:
		anchor.get_parent().remove_child(anchor)
		_tooltip_layer.add_child(anchor)
	_dirty_drop_ids[record.drop_id] = true


func _on_record_removed(record: GroundItemRecord) -> void:
	if record == null:
		return
	_release_chest(record.drop_id)


func _on_registry_cleared() -> void:
	_release_all()


func _take_chest() -> Node3D:
	var chest := _inactive_chests.pop_back() as Node3D if not _inactive_chests.is_empty() else CHEST_SCENE.instantiate() as Node3D
	if chest.get_parent() == null:
		_chests_parent.add_child(chest)
	if not chest.is_connected(&"pickup_requested", _on_chest_pickup_requested):
		chest.connect(&"pickup_requested", _on_chest_pickup_requested)
	var anchor := chest.call(&"tooltip_anchor") as Control
	if not anchor.mouse_entered.is_connected(_on_anchor_inspection_started.bind(chest)):
		anchor.mouse_entered.connect(_on_anchor_inspection_started.bind(chest))
		anchor.focus_entered.connect(_on_anchor_inspection_started.bind(chest))
		anchor.mouse_exited.connect(_on_anchor_inspection_ended.bind(chest))
		anchor.focus_exited.connect(_on_anchor_inspection_ended.bind(chest))
		anchor.pressed.connect(_on_anchor_pressed.bind(chest))
	return chest


func _release_chest(drop_id: StringName) -> void:
	var chest := _chest_by_drop.get(drop_id) as Node3D
	if chest == null:
		return
	if _tooltip != null:
		_tooltip.release_item(_source_id(drop_id))
	_chest_by_drop.erase(drop_id)
	_detail_by_drop.erase(drop_id)
	_comparisons_by_drop.erase(drop_id)
	_dirty_drop_ids.erase(drop_id)
	chest.call(&"deactivate")
	if _inactive_chests.size() < MAX_INACTIVE_CHESTS:
		_inactive_chests.append(chest)
		return
	var anchor := chest.call(&"tooltip_anchor") as Control
	if anchor.get_parent() != null:
		anchor.get_parent().remove_child(anchor)
	anchor.queue_free()
	chest.queue_free()


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


func _comparisons_for(detail: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var compatible: Array = detail.get("compatible_slot_ids", [])
	var equipment_value: Variant = detail.get("owner_leader_equipment", [])
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
	if _camera == null or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		anchor.visible = chest.visible
		return
	var world_position: Vector3 = chest.global_position + Vector3.UP * 1.55
	anchor.position = _camera.unproject_position(world_position) - anchor.size * 0.5
	anchor.visible = chest.visible and not _camera.is_position_behind(world_position)


func _on_anchor_inspection_started(chest: Node3D) -> void:
	if chest == null or _tooltip == null or StringName(chest.get("drop_id")).is_empty():
		return
	var chest_drop_id := StringName(chest.get("drop_id"))
	var detail := _detail_by_drop.get(chest_drop_id, {}) as Dictionary
	var comparisons: Array[Dictionary] = []
	for value: Variant in _comparisons_by_drop.get(chest_drop_id, []):
		if value is Dictionary:
			comparisons.append((value as Dictionary).duplicate(true))
	_tooltip.show_item(detail, comparisons, chest.call(&"tooltip_anchor") as Control, _source_id(chest_drop_id))


func _on_anchor_inspection_ended(chest: Node3D) -> void:
	var chest_drop_id := StringName(chest.get("drop_id")) if chest != null else &""
	if chest != null and _tooltip != null and not chest_drop_id.is_empty():
		_tooltip.release_item(_source_id(chest_drop_id))


func _on_anchor_pressed(chest: Node3D) -> void:
	if chest != null:
		var anchor := chest.call(&"tooltip_anchor") as Control
		var input_owner := StringName(String(anchor.get_meta("input_owner", "")))
		chest.call(&"request_pickup", input_owner)


func _on_chest_pickup_requested(drop_id: StringName, input_owner: StringName) -> void:
	var chest := _chest_by_drop.get(drop_id) as Node3D
	if chest == null or StringName(chest.get("run_player_id")) != input_owner:
		return
	pickup_requested.emit(drop_id, input_owner)


func _resolve_shared_tooltip() -> ItemTooltipPanel:
	if _tooltip_layer == null:
		return null
	for child: Node in _tooltip_layer.get_children():
		if child is ItemTooltipPanel:
			return child as ItemTooltipPanel
	var tooltip := TOOLTIP_SCENE.instantiate() as ItemTooltipPanel
	_tooltip_layer.add_child(tooltip)
	return tooltip


func _disconnect_registry() -> void:
	if _registry == null:
		return
	if _registry.record_added.is_connected(_on_record_added):
		_registry.record_added.disconnect(_on_record_added)
	if _registry.record_removed.is_connected(_on_record_removed):
		_registry.record_removed.disconnect(_on_record_removed)
	if _registry.cleared.is_connected(_on_registry_cleared):
		_registry.cleared.disconnect(_on_registry_cleared)


func _distance_to_camera(world_position: Vector3) -> float:
	if _camera == null or not is_instance_valid(_camera):
		return world_position.length()
	var camera_position := _camera.global_position if _camera.is_inside_tree() else _camera.position
	return camera_position.distance_to(world_position)


func _source_id(drop_id: StringName) -> StringName:
	return StringName("ground-loot:%s" % drop_id)
