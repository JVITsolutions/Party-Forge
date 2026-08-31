extends RefCounted

const SURFACE_SCRIPT_PATH := "res://scripts/presentation/character_surface_definition.gd"
const SHA_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


func run() -> Array[String]:
	var failures: Array[String] = []
	var script := load(SURFACE_SCRIPT_PATH) as Script
	TestAssertions.truthy(script != null, "character surface definition loads", failures)
	if script == null:
		return failures
	var surface: Resource = script.new()
	_configure_valid(surface)
	TestAssertions.equal(surface.call(&"validate"), PackedStringArray(), "valid production surface", failures)

	for case: Dictionary in [
		{"property": &"source_sha256", "value": SHA_A.to_upper(), "fragment": "lowercase SHA-256", "label": "uppercase hash"},
		{"property": &"source_sha256", "value": "abc123", "fragment": "lowercase SHA-256", "label": "short hash"},
		{"property": &"uv_set_count", "value": 0, "fragment": "at least one UV set", "label": "missing UVs"},
		{"property": &"tangent_status", "value": &"missing", "fragment": "tangent status must be valid", "label": "invalid tangents"},
		{"property": &"texture_paths", "value": {&"base_color": "F:/textures/body.png"}, "fragment": "path is invalid", "label": "machine texture path"},
		{"property": &"texture_paths", "value": {&"base_color": "res://textures/../body.png"}, "fragment": "path is invalid", "label": "texture traversal"},
		{"property": &"material_family_ids", "value": Array([&"skin", &"skin"], TYPE_STRING_NAME, "", null), "fragment": "duplicate material family", "label": "duplicate material family"},
		{"property": &"lod_triangle_counts", "value": Array([1200, 1200], TYPE_INT, "", null), "fragment": "strictly decreasing", "label": "flat LOD sequence"},
		{"property": &"lod_triangle_counts", "value": Array([1200, 0], TYPE_INT, "", null), "fragment": "strictly decreasing", "label": "nonpositive LOD"},
	]:
		var invalid: Resource = script.new()
		_configure_valid(invalid)
		invalid.set(case["property"], case["value"])
		TestAssertions.truthy(_contains(invalid.call(&"validate"), case["fragment"]), case["label"], failures)

	var empty_materials: Resource = script.new()
	_configure_valid(empty_materials)
	empty_materials.set(&"material_family_ids", Array([], TYPE_STRING_NAME, "", null))
	TestAssertions.truthy(_contains(empty_materials.call(&"validate"), "material families are empty"), "material families required", failures)

	var empty_lods: Resource = script.new()
	_configure_valid(empty_lods)
	empty_lods.set(&"lod_triangle_counts", Array([], TYPE_INT, "", null))
	TestAssertions.truthy(_contains(empty_lods.call(&"validate"), "LOD triangle counts are empty"), "LOD sequence required", failures)
	return failures


func _configure_valid(surface: Resource) -> void:
	surface.set(&"source_sha256", SHA_A)
	surface.set(&"uv_set_count", 1)
	surface.set(&"tangent_status", &"valid")
	surface.set(&"texture_paths", {&"base_color": "res://assets/models/characters/test/base_color.png"})
	surface.set(&"material_family_ids", Array([&"skin"], TYPE_STRING_NAME, "", null))
	surface.set(&"lod_triangle_counts", Array([1200, 600, 240], TYPE_INT, "", null))


func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false
