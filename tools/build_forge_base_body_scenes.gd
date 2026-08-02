extends SceneTree

const SOURCE_SCENE := preload("res://scenes/characters/presentation/forge_humanoid_model.tscn")
const OUTPUT_PATHS := {
	&"masculine": "res://scenes/characters/presentation/forge_base_masculine.tscn",
	&"feminine": "res://scenes/characters/presentation/forge_base_feminine.tscn",
}
const NEUTRAL_BODY_COLOR := Color(0.76, 0.57, 0.44, 1.0)
const NEUTRAL_BODY_ROUGHNESS := 0.82

func _initialize() -> void:
	for preset_id: StringName in OUTPUT_PATHS:
		if not _build_base_body(preset_id, String(OUTPUT_PATHS[preset_id])):
			quit(1)
			return
	print("FORGE_BASE_BODY_BUILD_OK scenes=2")
	quit(0)

func _build_base_body(preset_id: StringName, output_path: String) -> bool:
	var model := SOURCE_SCENE.instantiate() as ForgeHumanoidModel
	if model == null or not model.set_body_preset(preset_id):
		push_error("FORGE_BASE_BODY_BUILD_ERROR preset=%s reason=body selection failed" % preset_id)
		return false
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		if not model.clear_equipment_visual(slot_id):
			push_error("FORGE_BASE_BODY_BUILD_ERROR preset=%s slot=%s reason=clear failed" % [preset_id, slot_id])
			model.free()
			return false
	_neutralize_selected_body_materials(model, preset_id)
	_set_scene_owners(model, model)
	var scene := PackedScene.new()
	if scene.pack(model) != OK:
		push_error("FORGE_BASE_BODY_BUILD_ERROR preset=%s reason=pack failed" % preset_id)
		model.free()
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
	var result := ResourceSaver.save(scene, output_path)
	model.free()
	if result != OK:
		push_error("FORGE_BASE_BODY_BUILD_ERROR preset=%s reason=save code=%d" % [preset_id, result])
		return false
	if not _remove_generated_node_ids(output_path):
		push_error("FORGE_BASE_BODY_BUILD_ERROR preset=%s reason=stabilize scene failed" % preset_id)
		return false
	print("FORGE_BASE_BODY_BUILD_OK preset=%s path=%s" % [preset_id, output_path])
	return true

func _neutralize_selected_body_materials(model: Node3D, preset_id: StringName) -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or _body_preset_for(mesh) != preset_id:
			continue
		var source_material := mesh.material_override as StandardMaterial3D
		if source_material == null:
			continue
		var neutral_material := source_material.duplicate() as StandardMaterial3D
		neutral_material.albedo_color = NEUTRAL_BODY_COLOR
		neutral_material.metallic = 0.0
		neutral_material.roughness = NEUTRAL_BODY_ROUGHNESS
		neutral_material.emission_enabled = false
		neutral_material.emission = Color.BLACK
		neutral_material.emission_energy_multiplier = 0.0
		mesh.material_override = neutral_material

func _body_preset_for(node: Node) -> StringName:
	var cursor: Node = node
	while cursor != null:
		if cursor.has_meta(&"body_preset"):
			return StringName(cursor.get_meta(&"body_preset"))
		cursor = cursor.get_parent()
	return &""

func _remove_generated_node_ids(scene_path: String) -> bool:
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return false
	var scene_text := file.get_as_text()
	var node_id_pattern := RegEx.new()
	if node_id_pattern.compile(" unique_id=[0-9]+") != OK:
		return false
	var stable_scene_text := node_id_pattern.sub(scene_text, "", true)
	if stable_scene_text == scene_text:
		return true
	file = FileAccess.open(scene_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(stable_scene_text)
	return file.get_error() == OK

func _set_scene_owners(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		_set_scene_owners(child, scene_root)
