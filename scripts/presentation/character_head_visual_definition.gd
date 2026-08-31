class_name CharacterHeadVisualDefinition
extends Resource

@export var id: StringName
@export var class_id: StringName
@export var body_preset_id: StringName
@export var presentation_scene: PackedScene
@export var mesh_root_path: NodePath
@export var neck_interface_id: StringName
@export var helmet_envelope_id: StringName
@export var left_ear_socket_path: NodePath
@export var right_ear_socket_path: NodePath
@export var head_region_ids: Array[StringName] = []
@export var surface: CharacterSurfaceDefinition


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("head id is empty")
	if class_id.is_empty():
		errors.append("head %s class id is empty" % id)
	if body_preset_id not in [&"masculine", &"feminine"]:
		errors.append("head %s body preset %s is invalid" % [id, body_preset_id])
	if presentation_scene == null:
		errors.append("head %s presentation scene is missing" % id)
	if mesh_root_path.is_empty() or mesh_root_path.is_absolute():
		errors.append("head %s mesh root path must be relative" % id)
	if neck_interface_id.is_empty() or helmet_envelope_id.is_empty():
		errors.append("head %s neck interface and helmet envelope are required" % id)
	if left_ear_socket_path.is_empty() or right_ear_socket_path.is_empty():
		errors.append("head %s ear socket paths are required" % id)
	var seen_regions: Dictionary = {}
	for region_id: StringName in head_region_ids:
		if region_id.is_empty() or seen_regions.has(region_id):
			errors.append("head %s has empty or duplicate region %s" % [id, region_id])
		seen_regions[region_id] = true
	if surface == null:
		errors.append("head %s surface definition is missing" % id)
	else:
		for reason: String in surface.validate():
			errors.append("head %s %s" % [id, reason])
	return errors
