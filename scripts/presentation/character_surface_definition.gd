class_name CharacterSurfaceDefinition
extends Resource

@export var source_sha256: String
@export var uv_set_count: int
@export var tangent_status: StringName
@export var texture_paths: Dictionary = {}
@export var material_family_ids: Array[StringName] = []
@export var lod_triangle_counts: Array[int] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _is_sha256(source_sha256):
		errors.append("surface source hash must be lowercase SHA-256")
	if uv_set_count < 1:
		errors.append("surface requires at least one UV set")
	if tangent_status != &"valid":
		errors.append("surface tangent status must be valid")
	for channel: Variant in texture_paths:
		var path := str(texture_paths[channel])
		if str(channel).is_empty() or not _is_normalized_res_path(path):
			errors.append("surface texture channel %s path is invalid" % channel)
	var seen_families: Dictionary = {}
	for family_id: StringName in material_family_ids:
		if family_id.is_empty() or seen_families.has(family_id):
			errors.append("surface has empty or duplicate material family %s" % family_id)
		seen_families[family_id] = true
	if material_family_ids.is_empty():
		errors.append("surface material families are empty")
	var previous := 2147483647
	for triangle_count: int in lod_triangle_counts:
		if triangle_count <= 0 or triangle_count >= previous:
			errors.append("surface LOD triangle counts must be positive and strictly decreasing")
			break
		previous = triangle_count
	if lod_triangle_counts.is_empty():
		errors.append("surface LOD triangle counts are empty")
	return errors


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _is_normalized_res_path(path: String) -> bool:
	if not path.begins_with("res://") or "\\" in path:
		return false
	var segments := path.trim_prefix("res://").split("/", true)
	return not segments.has("") and not segments.has(".") and not segments.has("..")
