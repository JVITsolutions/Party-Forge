class_name GroundItemChest
extends Node3D

signal pickup_requested(drop_id: StringName, input_owner: StringName)

const RARITY_PALETTE := preload("res://scripts/ui/storage/item_rarity_palette.gd")
const OWNER_MARKER_SCRIPT := preload("res://scripts/world/player_owner_marker_3d.gd")
const BASE_LIGHT_ENERGY := 0.45
const RARITY_LIGHT_STEP := 0.14
const SELECTED_LIGHT_BONUS := 1.1

var drop_id: StringName
var run_player_id: StringName
var player_number := 0
var _detail: Dictionary = {}
var _rarity_energy := BASE_LIGHT_ENERGY
var _selected := false
var _tooltip_anchor: Button


func _ready() -> void:
	_ensure_tooltip_anchor()


func bind(record: GroundItemRecord, detail: Dictionary, owner_color: Color) -> void:
	_ensure_tooltip_anchor()
	if record == null:
		deactivate()
		return
	drop_id = record.drop_id
	run_player_id = record.run_player_id
	player_number = record.player_number
	_detail = detail.duplicate(true)
	position = record.world_position
	visible = true
	_selected = false
	var rarity_id := StringName(String(_detail.get("rarity_id", record.rarity_id)))
	var rarity_color := RARITY_PALETTE.color_for(rarity_id)
	_rarity_energy = BASE_LIGHT_ENERGY + float(RARITY_PALETTE.intensity_for(rarity_id)) * RARITY_LIGHT_STEP
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.105, 0.045)
	material.metallic = 0.18
	material.roughness = 0.72
	material.emission_enabled = true
	material.emission = rarity_color.darkened(0.32)
	material.emission_energy_multiplier = 0.45
	(get_node("MeshTarget") as MeshInstance3D).material_override = material
	var collision := get_node("PickupTarget/CollisionShape3D") as CollisionShape3D
	collision.disabled = false
	var light := get_node("RarityLight") as OmniLight3D
	light.light_color = rarity_color
	light.light_energy = _rarity_energy
	get_node("OwnerMarker").call(&"bind", player_number, owner_color)
	_tooltip_anchor.visible = true
	_tooltip_anchor.text = "?" if _missing_optional_visual() else ""
	_tooltip_anchor.tooltip_text = ""
	_refresh_accessibility(float(_detail.get("distance_meters", record.world_position.length())))


func set_selected(active: bool) -> void:
	_selected = active
	var selection_ring := get_node_or_null("SelectionRing") as MeshInstance3D
	if selection_ring != null:
		selection_ring.visible = active
	var light := get_node("RarityLight") as OmniLight3D
	light.light_energy = _rarity_energy + SELECTED_LIGHT_BONUS if active else _rarity_energy
	var material := (get_node("MeshTarget") as MeshInstance3D).material_override as StandardMaterial3D
	if material != null:
		material.emission_energy_multiplier = 1.35 if active else 0.45
	_tooltip_anchor.add_theme_color_override("font_color", Color(0.86, 1.0, 0.78) if active else Color.WHITE)
	if not active:
		_tooltip_anchor.text = "?" if _missing_optional_visual() else ""


func is_selected() -> bool:
	return _selected


func set_distance_feedback(distance_meters: float, status: String = "") -> void:
	if not _selected:
		return
	var distance_text := "%.1f m" % maxf(distance_meters, 0.0)
	_tooltip_anchor.text = "%s • %s" % [status, distance_text] if not status.is_empty() else distance_text
	_refresh_accessibility(distance_meters)
	if not status.is_empty():
		_tooltip_anchor.accessibility_description = status
	else:
		_tooltip_anchor.accessibility_description = "Selected personal loot chest"


func tooltip_anchor() -> Control:
	_ensure_tooltip_anchor()
	return _tooltip_anchor


func request_pickup(input_owner: StringName) -> void:
	if drop_id.is_empty() or input_owner != run_player_id:
		return
	pickup_requested.emit(drop_id, input_owner)


func deactivate() -> void:
	visible = false
	_selected = false
	drop_id = &""
	run_player_id = &""
	player_number = 0
	_detail = {}
	if _tooltip_anchor != null and is_instance_valid(_tooltip_anchor):
		_tooltip_anchor.visible = false
		_tooltip_anchor.accessibility_description = ""
		if _tooltip_anchor.is_inside_tree() and _tooltip_anchor.has_focus():
			_tooltip_anchor.release_focus()
	var collision := get_node_or_null("PickupTarget/CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = true


func _detail_copy() -> Dictionary:
	return _detail.duplicate(true)


func _ensure_tooltip_anchor() -> void:
	if _tooltip_anchor != null and is_instance_valid(_tooltip_anchor):
		return
	_tooltip_anchor = Button.new()
	_tooltip_anchor.name = "GroundItemAnchor"
	_tooltip_anchor.custom_minimum_size = Vector2(44.0, 44.0)
	_tooltip_anchor.size = Vector2(44.0, 44.0)
	_tooltip_anchor.focus_mode = Control.FOCUS_ALL
	_tooltip_anchor.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tooltip_anchor.flat = true
	_tooltip_anchor.visible = false
	add_child(_tooltip_anchor)


func _refresh_accessibility(distance_meters: float) -> void:
	var item_name := String(_detail.get("name", "Unknown Item"))
	var rarity_name := String(_detail.get("rarity_name", String(_detail.get("rarity_id", "Unknown Rarity")).capitalize()))
	_tooltip_anchor.accessibility_name = "%s, %s, P%d, %.1f m" % [item_name, rarity_name, player_number, maxf(distance_meters, 0.0)]


func _missing_optional_visual() -> bool:
	for field: String in ["icon_path", "model_path"]:
		var path := String(_detail.get(field, ""))
		if not path.is_empty() and not ResourceLoader.exists(path):
			return true
	return false
