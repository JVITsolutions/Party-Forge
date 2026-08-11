class_name CharacterEquipmentPreview
extends SubViewportContainer

const PRESENTATION_SCENE := preload("res://scenes/characters/presentation/character_presentation.tscn")
const DRAG_RADIANS_PER_PIXEL := 0.012
const SAFE_VERTICAL_ANGLE := -8.0

var active_preview: CharacterPresentation
var active_member_id := 0
var diagnostics := PackedStringArray()
var _dragging := false
var _active_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_root().rotation.x = deg_to_rad(SAFE_VERTICAL_ANGLE)
	var drag_surface := get_node("DragSurface") as Control
	if not drag_surface.gui_input.is_connected(_handle_preview_input):
		drag_surface.gui_input.connect(_handle_preview_input)


func show_member(member: PartyMemberState, equipment_rows: Array[Dictionary]) -> bool:
	if member == null or member.class_definition == null or member.class_definition.visual_profile == null:
		clear()
		return false
	var visuals_by_slot := _visuals_by_slot(equipment_rows)
	var requested_signature := _signature(member, visuals_by_slot)
	if active_preview != null and is_instance_valid(active_preview) and requested_signature == _active_signature:
		return true
	_clear_preview()
	diagnostics.clear()
	var copy := PRESENTATION_SCENE.instantiate() as CharacterPresentation
	_preview_root().add_child(copy)
	if not copy.apply_profile(member.class_definition.visual_profile, member.class_definition.color):
		copy.free()
		return false
	diagnostics = copy.refresh_equipment_visuals(visuals_by_slot)
	active_preview = copy
	active_member_id = member.member_id
	_active_signature = requested_signature
	return true


func clear() -> void:
	_clear_preview()
	diagnostics.clear()


func _gui_input(event: InputEvent) -> void:
	_handle_preview_input(event)


func _handle_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		accept_event()
		return
	if event is InputEventMouseMotion and _dragging and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var mount := _preview_root()
		mount.rotation.y = wrapf(mount.rotation.y - (event as InputEventMouseMotion).relative.x * DRAG_RADIANS_PER_PIXEL, -PI, PI)
		mount.rotation.x = deg_to_rad(SAFE_VERTICAL_ANGLE)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_dragging = false


func _visuals_by_slot(rows: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var slot_id := StringName(String(row.get("slot_id", "")))
		if not EquipmentSlotCatalog.is_valid(slot_id) or String(row.get("item_id", "")).is_empty():
			continue
		var base := row.get("base_definition") as EquipmentBaseDefinition
		result[slot_id] = base.presentation if base != null else null
	return result


func _signature(member: PartyMemberState, visuals_by_slot: Dictionary) -> String:
	var profile := member.class_definition.visual_profile
	var parts := PackedStringArray([
		str(member.member_id), String(profile.id), String(profile.default_body_preset),
		String(profile.default_palette_id), member.class_definition.color.to_html(true),
	])
	for slot_id: StringName in EquipmentSlotCatalog.SHEET_SLOT_IDS:
		if not visuals_by_slot.has(slot_id):
			continue
		var definition := visuals_by_slot.get(slot_id) as EquipmentVisualDefinition
		parts.append("%s=%s" % [slot_id, definition.id if definition != null else &"<missing>"])
	return "|".join(parts)


func _clear_preview() -> void:
	if active_preview != null and is_instance_valid(active_preview):
		active_preview.free()
	active_preview = null
	active_member_id = 0
	_active_signature = ""


func _preview_root() -> Node3D:
	return get_node("SubViewport/World/PreviewRoot") as Node3D
