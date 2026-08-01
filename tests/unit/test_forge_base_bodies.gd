extends RefCounted

const BASES := {
	&"masculine": {
		&"scene": "res://scenes/characters/presentation/forge_base_masculine.tscn",
		&"profile": "res://data/presentation/profiles/forge_base_masculine.tres",
	},
	&"feminine": {
		&"scene": "res://scenes/characters/presentation/forge_base_feminine.tscn",
		&"profile": "res://data/presentation/profiles/forge_base_feminine.tres",
	},
}
const NEUTRAL_BODY_COLOR := Color(0.76, 0.57, 0.44, 1.0)
const PIVOT_PATHS := [
	"HitPivot",
	"HitPivot/BodyPivot",
	"HitPivot/BodyPivot/HipsPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket",
]
const ANIMATION_IDS: Array[StringName] = [&"idle", &"attack_slash", &"attack_combo", &"hit_flinch"]

func run() -> Array[String]:
	var failures: Array[String] = []
	_assert_equipped_source_material_contract(failures)
	for preset_id: StringName in BASES:
		_assert_base_body(preset_id, BASES[preset_id] as Dictionary, failures)
	return failures

func _assert_base_body(preset_id: StringName, paths: Dictionary, failures: Array[String]) -> void:
	var scene := load(String(paths[&"scene"])) as PackedScene
	var profile := load(String(paths[&"profile"])) as CharacterVisualProfile
	TestAssertions.truthy(scene != null, "%s base scene loads directly" % preset_id, failures)
	TestAssertions.truthy(profile != null, "%s base profile loads" % preset_id, failures)
	if scene == null or profile == null:
		return
	TestAssertions.equal(profile.validate(), PackedStringArray(), "%s base profile validates" % preset_id, failures)
	TestAssertions.equal(profile.default_body_preset, preset_id, "%s base profile selects its body" % preset_id, failures)
	TestAssertions.truthy(profile.default_equipment_visuals.is_empty(), "%s base profile has no default equipment" % preset_id, failures)
	TestAssertions.equal(profile.available_equipment_visuals.size(), EquipmentSlotCatalog.SLOT_IDS.size(), "%s base profile exposes all slot visuals" % preset_id, failures)
	var model := scene.instantiate() as Node3D
	TestAssertions.truthy(model != null and model.has_method(&"set_body_preset") and model.has_method(&"set_palette") and model.has_method(&"apply_equipment_visual") and model.has_method(&"clear_equipment_visual") and model.has_method(&"play_action"), "%s base scene retains public model API" % preset_id, failures)
	if model == null:
		return
	for pivot_path: String in PIVOT_PATHS:
		TestAssertions.truthy(model.get_node_or_null(pivot_path) != null, "%s retains pivot %s" % [preset_id, pivot_path], failures)
	for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
		var equipment_root := _equipment_root(model, slot_id)
		TestAssertions.truthy(equipment_root != null and not equipment_root.visible, "%s base scene hides %s by default" % [preset_id, slot_id], failures)
		TestAssertions.truthy(profile.get_available_equipment_visual(slot_id) != null, "%s base profile exposes %s" % [preset_id, slot_id], failures)
	for body_id: StringName in CharacterVisualProfile.BODY_PRESETS:
		for body_node: Node3D in _body_nodes(model, body_id):
			TestAssertions.equal(body_node.visible, body_id == preset_id, "%s base scene only shows its requested body" % preset_id, failures)
	var visible_body_meshes := 0
	for mesh: MeshInstance3D in _meshes(model):
		if mesh.visible and mesh.get_parent() is Node3D and (mesh.get_parent() as Node3D).has_meta(&"body_preset"):
			visible_body_meshes += 1
	TestAssertions.truthy(visible_body_meshes >= 11, "%s base scene retains covered mannequin geometry" % preset_id, failures)
	_assert_neutral_body_materials(model, preset_id, failures)
	var bounds: AABB = model.call(&"visual_bounds") as AABB
	TestAssertions.truthy(bounds.size.y >= 1.6 and bounds.size.y <= 1.85, "%s base body preserves actor scale" % preset_id, failures)
	TestAssertions.near(bounds.position.y, 0.0, 0.05, "%s base body remains floor aligned" % preset_id, failures)
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	for animation_id: StringName in ANIMATION_IDS:
		TestAssertions.truthy(player != null and player.has_animation(animation_id), "%s base body preserves %s" % [preset_id, animation_id], failures)
	model.free()

func _assert_neutral_body_materials(model: Node3D, preset_id: StringName, failures: Array[String]) -> void:
	var neutral_meshes := 0
	for mesh: MeshInstance3D in _meshes(model):
		if not mesh.visible or _body_preset_for(mesh) != preset_id:
			continue
		var material := mesh.material_override as StandardMaterial3D
		TestAssertions.truthy(material != null, "%s base body mesh has an explicit mannequin material: %s" % [preset_id, mesh.name], failures)
		if material == null:
			continue
		neutral_meshes += 1
		TestAssertions.near(material.metallic, 0.0, 0.001, "%s base body material is non-metallic: %s" % [preset_id, mesh.name], failures)
		TestAssertions.truthy(material.roughness >= 0.8, "%s base body material is matte: %s" % [preset_id, mesh.name], failures)
		TestAssertions.truthy(not material.emission_enabled, "%s base body material has no equipment-like emission: %s" % [preset_id, mesh.name], failures)
		TestAssertions.truthy(material.albedo_color.is_equal_approx(NEUTRAL_BODY_COLOR), "%s base body material uses the neutral mannequin palette: %s" % [preset_id, mesh.name], failures)
	TestAssertions.truthy(neutral_meshes >= 11, "%s base body neutralizes every visible body mesh" % preset_id, failures)

func _assert_equipped_source_material_contract(failures: Array[String]) -> void:
	var source_text := FileAccess.get_file_as_string("res://scenes/characters/presentation/forge_vanguard_model.tscn")
	TestAssertions.truthy(source_text.contains("[sub_resource type=\"StandardMaterial3D\" id=\"StandardMaterial3D_kedvv\"]\nalbedo_color = Color(0.1882353, 0.22745098, 0.2784314, 1)\nmetallic = 0.7"), "base generation leaves equipped Forge Vanguard torso metal unchanged", failures)
	TestAssertions.truthy(source_text.contains("[sub_resource type=\"StandardMaterial3D\" id=\"StandardMaterial3D_xrbkh\"]\nalbedo_color = Color(0.2901961, 0.20392157, 0.14901961, 1)"), "base generation leaves equipped Forge Vanguard leather unchanged", failures)

func _equipment_root(model: Node3D, slot_id: StringName) -> Node3D:
	for node: Node in model.find_children("*", "Node3D", true, false):
		if StringName(node.get_meta(&"equipment_slot", &"")) == slot_id:
			return node as Node3D
	return null

func _body_nodes(model: Node3D, body_id: StringName) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for node: Node in model.find_children("*", "Node3D", true, false):
		if StringName(node.get_meta(&"body_preset", &"")) == body_id:
			nodes.append(node as Node3D)
	return nodes

func _meshes(model: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes

func _body_preset_for(node: Node) -> StringName:
	var cursor: Node = node
	while cursor != null:
		if cursor.has_meta(&"body_preset"):
			return StringName(cursor.get_meta(&"body_preset"))
		cursor = cursor.get_parent()
	return &""
