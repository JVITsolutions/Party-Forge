class_name EquipmentBodyFitDescriptor
extends Resource

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]
const SHARED_BODY_PRESET: StringName = &"shared"

@export var body_preset_id: StringName
@export var presentation_scene: PackedScene
@export var mesh_root_paths: Array[NodePath] = []
@export var hide_body_regions: Array[StringName] = []
@export var headwear_fit: HeadwearFitDescriptor
@export var necklace_anchor_paths: Array[NodePath] = []

func validates_for_body(body_preset: StringName, shared_fit: bool) -> bool:
	if body_preset not in BODY_PRESETS:
		return false
	return body_preset_id == body_preset or (shared_fit and body_preset_id == SHARED_BODY_PRESET)

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if body_preset_id not in BODY_PRESETS and body_preset_id != SHARED_BODY_PRESET:
		errors.append("equipment body fit body preset %s is invalid" % body_preset_id)
	if headwear_fit != null:
		for reason: String in headwear_fit.validate():
			errors.append(reason)
	var seen_necklace_paths: Dictionary = {}
	for anchor_path: NodePath in necklace_anchor_paths:
		if anchor_path.is_empty():
			errors.append("equipment body fit necklace anchor path is empty")
		elif anchor_path.is_absolute():
			errors.append("equipment body fit necklace anchor path must be relative")
		elif seen_necklace_paths.has(anchor_path):
			errors.append("equipment body fit has duplicate necklace anchor path %s" % anchor_path)
		seen_necklace_paths[anchor_path] = true
	if presentation_scene == null:
		errors.append("equipment body fit presentation scene is missing")
		return errors
	if mesh_root_paths.is_empty():
		errors.append("equipment body fit mesh roots are empty")
		return errors
	var root := presentation_scene.instantiate()
	if root == null:
		errors.append("equipment body fit presentation scene did not instance")
		return errors
	for mesh_root_path: NodePath in mesh_root_paths:
		if mesh_root_path.is_empty():
			errors.append("equipment body fit mesh root path is empty")
			continue
		var mesh_root := root.get_node_or_null(mesh_root_path)
		if mesh_root == null:
			errors.append("equipment body fit mesh root %s is missing" % mesh_root_path)
		elif not mesh_root is Node3D:
			errors.append("equipment body fit mesh root %s is not Node3D" % mesh_root_path)
	root.free()
	return errors

static func legacy(body_preset: StringName, scene: PackedScene) -> EquipmentBodyFitDescriptor:
	if body_preset not in BODY_PRESETS or scene == null:
		return null
	var descriptor := EquipmentBodyFitDescriptor.new()
	descriptor.body_preset_id = body_preset
	descriptor.presentation_scene = scene
	descriptor.mesh_root_paths = [NodePath(".")]
	return descriptor
