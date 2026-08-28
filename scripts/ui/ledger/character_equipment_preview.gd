class_name CharacterEquipmentPreview
extends SubViewportContainer

const PRESENTATION_SCENE := preload("res://scenes/characters/presentation/character_presentation.tscn")
const DRAG_RADIANS_PER_PIXEL := 0.012
const SAFE_VERTICAL_ANGLE := -8.0

var active_preview: CharacterPresentation
var active_member_id := 0
var diagnostics := PackedStringArray()
var _dragging := false
var _active_signature: PresentationSignature
var _reduced_motion := false


class EquipmentSignature extends RefCounted:
	var definition: EquipmentVisualDefinition
	var presentation_scene: PackedScene
	var icon_master: Texture2D
	var icon_runtime: Texture2D
	var id: StringName
	var slot_id: StringName
	var geometry_key: StringName
	var visual_channels: Array
	var supported_slot_ids: Array
	var socket_id: StringName
	var body_preset_ids: Array
	var combat_visible: bool
	var item_colors: Dictionary
	var wearer_accent_channel: StringName
	var weapon_animation_family_id: StringName
	var launch_socket_id: StringName
	var readability_channels: Array
	var readability_anchor_name: StringName
	var action_origin_socket_name: StringName
	var projectile_launch_socket_name: StringName
	var attachment_role_id: StringName

	func _init(value: EquipmentVisualDefinition) -> void:
		definition = value
		presentation_scene = value.presentation_scene
		icon_master = value.icon_master
		icon_runtime = value.icon_runtime
		id = value.id
		slot_id = value.slot_id
		geometry_key = value.geometry_key
		visual_channels = value.visual_channels.duplicate()
		supported_slot_ids = value.supported_slot_ids.duplicate()
		socket_id = value.socket_id
		body_preset_ids = value.body_preset_ids.duplicate()
		combat_visible = value.combat_visible
		item_colors = value.item_colors.duplicate(true)
		wearer_accent_channel = value.wearer_accent_channel
		weapon_animation_family_id = value.weapon_animation_family_id
		launch_socket_id = value.launch_socket_id
		readability_channels = value.readability_channels.duplicate()
		readability_anchor_name = value.readability_anchor_name
		action_origin_socket_name = value.action_origin_socket_name
		projectile_launch_socket_name = value.projectile_launch_socket_name
		attachment_role_id = value.attachment_role_id

	func matches(other: EquipmentSignature) -> bool:
		return other != null \
			and definition == other.definition \
			and presentation_scene == other.presentation_scene \
			and icon_master == other.icon_master \
			and icon_runtime == other.icon_runtime \
			and id == other.id \
			and slot_id == other.slot_id \
			and geometry_key == other.geometry_key \
			and visual_channels == other.visual_channels \
			and supported_slot_ids == other.supported_slot_ids \
			and socket_id == other.socket_id \
			and body_preset_ids == other.body_preset_ids \
			and combat_visible == other.combat_visible \
			and item_colors == other.item_colors \
			and wearer_accent_channel == other.wearer_accent_channel \
			and weapon_animation_family_id == other.weapon_animation_family_id \
			and launch_socket_id == other.launch_socket_id \
			and readability_channels == other.readability_channels \
			and readability_anchor_name == other.readability_anchor_name \
			and action_origin_socket_name == other.action_origin_socket_name \
			and projectile_launch_socket_name == other.projectile_launch_socket_name \
			and attachment_role_id == other.attachment_role_id


class PresentationSignature extends RefCounted:
	enum Mode { MEMBER, CLASS }

	var mode := Mode.MEMBER
	var member_id: int
	var class_definition: ClassDefinition
	var profile: CharacterVisualProfile
	var presentation_scene: PackedScene
	var body_id: StringName
	var palette_id: StringName
	var primary_color: Color
	var idle_action_id: StringName
	var required_animation_names: Array
	var visuals_by_slot: Dictionary = {}

	func _init(member: PartyMemberState = null, visuals: Dictionary = {}) -> void:
		if member == null:
			return
		mode = Mode.MEMBER
		member_id = member.member_id
		_configure(member.class_definition, member.class_definition.color, visuals)

	static func for_class(definition: ClassDefinition) -> PresentationSignature:
		var signature := PresentationSignature.new()
		signature.mode = Mode.CLASS
		signature._configure(definition, definition.color, {})
		return signature

	func _configure(definition: ClassDefinition, color: Color, visuals: Dictionary) -> void:
		class_definition = definition
		profile = definition.visual_profile
		presentation_scene = profile.presentation_scene
		body_id = profile.default_body_preset
		palette_id = profile.default_palette_id
		primary_color = color
		idle_action_id = profile.idle_action_id
		required_animation_names = profile.required_animation_names.duplicate()
		for slot_id: StringName in EquipmentSlotCatalog.SHEET_SLOT_IDS:
			if not visuals.has(slot_id):
				continue
			var visual_definition := visuals.get(slot_id) as EquipmentVisualDefinition
			visuals_by_slot[slot_id] = EquipmentSignature.new(visual_definition) if visual_definition != null else null

	func matches(other: PresentationSignature) -> bool:
		if other == null \
			or mode != other.mode \
			or member_id != other.member_id \
			or class_definition != other.class_definition \
			or profile != other.profile \
			or presentation_scene != other.presentation_scene \
			or body_id != other.body_id \
			or palette_id != other.palette_id \
			or primary_color != other.primary_color \
			or idle_action_id != other.idle_action_id \
			or required_animation_names != other.required_animation_names:
			return false
		for slot_id: StringName in EquipmentSlotCatalog.SHEET_SLOT_IDS:
			if visuals_by_slot.has(slot_id) != other.visuals_by_slot.has(slot_id):
				return false
			if not visuals_by_slot.has(slot_id):
				continue
			var current := visuals_by_slot.get(slot_id) as EquipmentSignature
			var candidate := other.visuals_by_slot.get(slot_id) as EquipmentSignature
			if (current == null) != (candidate == null) or (current != null and not current.matches(candidate)):
				return false
		return true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_root().rotation.x = deg_to_rad(SAFE_VERTICAL_ANGLE)
	var drag_surface := get_node("DragSurface") as Control
	if not drag_surface.gui_input.is_connected(_handle_preview_input):
		drag_surface.gui_input.connect(_handle_preview_input)
	if not visibility_changed.is_connected(_sync_rendering):
		visibility_changed.connect(_sync_rendering)
	_sync_rendering()


func show_member(member: PartyMemberState, equipment_rows: Array[Dictionary]) -> bool:
	if member == null or member.class_definition == null or member.class_definition.visual_profile == null:
		clear()
		return false
	var visuals_by_slot := _visuals_by_slot(equipment_rows)
	var requested_signature := PresentationSignature.new(member, visuals_by_slot)
	if active_preview != null and is_instance_valid(active_preview) and requested_signature.matches(_active_signature):
		_set_fallback_visible(false)
		_sync_rendering()
		return true
	clear()
	var copy := PRESENTATION_SCENE.instantiate() as CharacterPresentation
	_preview_root().add_child(copy)
	if not copy.apply_profile(member.class_definition.visual_profile, member.class_definition.color):
		copy.free()
		return false
	diagnostics = copy.refresh_equipment_visuals(visuals_by_slot)
	active_preview = copy
	active_member_id = member.member_id
	_active_signature = requested_signature
	_set_fallback_visible(false)
	_sync_rendering()
	return true


func show_class(definition: ClassDefinition) -> bool:
	if definition == null or definition.visual_profile == null or not definition.visual_profile.validate().is_empty():
		show_fallback(definition.id if definition != null else &"", "Preview unavailable.")
		return false
	var requested_signature := PresentationSignature.for_class(definition)
	if active_preview != null and is_instance_valid(active_preview) and requested_signature.matches(_active_signature):
		_set_fallback_visible(false)
		_sync_rendering()
		return true
	clear()
	var copy := PRESENTATION_SCENE.instantiate() as CharacterPresentation
	_preview_root().add_child(copy)
	if not copy.apply_profile(definition.visual_profile, definition.color):
		copy.free()
		show_fallback(definition.id, "Preview unavailable.")
		return false
	active_preview = copy
	active_member_id = 0
	_active_signature = requested_signature
	_set_fallback_visible(false)
	_sync_rendering()
	return true


func show_fallback(_class_id: StringName, safe_reason: String) -> void:
	clear()
	var detail := safe_reason.strip_edges()
	_fallback_detail().text = detail if not detail.is_empty() else "Preview unavailable."
	_set_fallback_visible(true)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func clear() -> void:
	_dragging = false
	_clear_preview()
	diagnostics.clear()
	_set_fallback_visible(false)
	_sync_rendering()


func _exit_tree() -> void:
	clear()


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


func _clear_preview() -> void:
	if active_preview != null and is_instance_valid(active_preview):
		active_preview.free()
	active_preview = null
	active_member_id = 0
	_active_signature = null


func _preview_root() -> Node3D:
	return get_node("SubViewport/World/PreviewRoot") as Node3D


func _subviewport() -> SubViewport:
	return get_node("SubViewport") as SubViewport


func _fallback() -> Control:
	return get_node("Fallback") as Control


func _fallback_detail() -> Label:
	return get_node("Fallback/UnavailableDetail") as Label


func _set_fallback_visible(should_be_visible: bool) -> void:
	_fallback().visible = should_be_visible


func _sync_rendering() -> void:
	var has_visible_presentation := is_visible_in_tree() and active_preview != null and is_instance_valid(active_preview)
	_subviewport().render_target_update_mode = SubViewport.UPDATE_ALWAYS if has_visible_presentation else SubViewport.UPDATE_DISABLED
