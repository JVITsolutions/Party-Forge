extends RefCounted

const HEAD_SCRIPT_PATH := "res://scripts/presentation/character_head_visual_definition.gd"
const SURFACE_SCRIPT_PATH := "res://scripts/presentation/character_surface_definition.gd"
const SHA_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


func run() -> Array[String]:
	var failures: Array[String] = []
	var head_script := load(HEAD_SCRIPT_PATH) as Script
	var surface_script := load(SURFACE_SCRIPT_PATH) as Script
	TestAssertions.truthy(head_script != null, "character head definition loads", failures)
	TestAssertions.truthy(surface_script != null, "head surface dependency loads", failures)
	if head_script == null or surface_script == null:
		return failures

	var valid: Resource = head_script.new()
	_configure_valid(valid, surface_script)
	TestAssertions.equal(valid.call(&"validate"), PackedStringArray(), "valid modular class head", failures)

	for case: Dictionary in [
		{"property": &"class_id", "value": &"", "fragment": "class id is empty", "label": "class identity required"},
		{"property": &"body_preset_id", "value": &"shared", "fragment": "body preset shared is invalid", "label": "body preset closed"},
		{"property": &"presentation_scene", "value": null, "fragment": "presentation scene is missing", "label": "head scene required"},
		{"property": &"mesh_root_path", "value": NodePath("/HeadMesh"), "fragment": "mesh root path must be relative", "label": "mesh root relative"},
		{"property": &"neck_interface_id", "value": &"", "fragment": "neck interface and helmet envelope are required", "label": "neck interface required"},
		{"property": &"helmet_envelope_id", "value": &"", "fragment": "neck interface and helmet envelope are required", "label": "helmet envelope required"},
		{"property": &"left_ear_socket_path", "value": NodePath(), "fragment": "ear socket paths are required", "label": "left ear socket required"},
		{"property": &"right_ear_socket_path", "value": NodePath(), "fragment": "ear socket paths are required", "label": "right ear socket required"},
		{"property": &"head_region_ids", "value": Array([&"scalp", &"scalp"], TYPE_STRING_NAME, "", null), "fragment": "duplicate region scalp", "label": "head regions unique"},
	]:
		var invalid: Resource = head_script.new()
		_configure_valid(invalid, surface_script)
		invalid.set(case["property"], case["value"])
		TestAssertions.truthy(_contains(invalid.call(&"validate"), case["fragment"]), case["label"], failures)

	var missing_surface: Resource = head_script.new()
	_configure_valid(missing_surface, surface_script)
	missing_surface.set(&"surface", null)
	TestAssertions.truthy(_contains(missing_surface.call(&"validate"), "surface definition is missing"), "head surface required", failures)
	return failures


func _configure_valid(head: Resource, surface_script: Script) -> void:
	head.set(&"id", &"paladin_masculine_head")
	head.set(&"class_id", &"paladin")
	head.set(&"body_preset_id", &"masculine")
	head.set(&"presentation_scene", _packed_scene())
	head.set(&"mesh_root_path", NodePath("HeadMesh"))
	head.set(&"neck_interface_id", &"pf_neck_masculine_v1")
	head.set(&"helmet_envelope_id", &"pf_head_masculine_v1")
	head.set(&"left_ear_socket_path", NodePath("Skeleton3D/EarSocketLeft"))
	head.set(&"right_ear_socket_path", NodePath("Skeleton3D/EarSocketRight"))
	head.set(&"head_region_ids", Array([&"scalp", &"hair", &"facial_hair", &"ears"], TYPE_STRING_NAME, "", null))
	var surface: Resource = surface_script.new()
	surface.set(&"source_sha256", SHA_A)
	surface.set(&"uv_set_count", 1)
	surface.set(&"tangent_status", &"valid")
	surface.set(&"texture_paths", {&"base_color": "res://assets/models/characters/test/head_base_color.png"})
	surface.set(&"material_family_ids", Array([&"skin"], TYPE_STRING_NAME, "", null))
	surface.set(&"lod_triangle_counts", Array([1200, 600], TYPE_INT, "", null))
	head.set(&"surface", surface)


func _packed_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "HeadRoot"
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false
