class_name Task10FilesystemManifest
extends RefCounted


static func capture(root_path: String) -> Dictionary:
	var absolute_root := ProjectSettings.globalize_path(root_path).simplify_path()
	if not DirAccess.dir_exists_absolute(absolute_root):
		return {"error": "manifest root is missing: %s" % absolute_root, "entries": []}
	if _is_link(absolute_root):
		return {"error": "manifest root is a link/reparse point: %s" % absolute_root, "entries": []}
	var entries: Array[Dictionary] = []
	var error := _capture_directory(absolute_root, "", entries)
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return String(first["relative_path"]) < String(second["relative_path"]))
	return {"error": error, "entries": entries}


static func equivalent(first: Dictionary, second: Dictionary) -> bool:
	return first == second


static func describe_difference(expected: Dictionary, actual: Dictionary) -> String:
	if equivalent(expected, actual):
		return ""
	return "expected=%s actual=%s" % [JSON.stringify(expected), JSON.stringify(actual)]


static func _capture_directory(absolute_directory: String, relative_directory: String, entries: Array[Dictionary]) -> String:
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		return "cannot open manifest directory: %s" % absolute_directory
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name not in [".", ".."]:
			var absolute_path := absolute_directory.path_join(name).simplify_path()
			var relative_path := (name if relative_directory.is_empty() else relative_directory.path_join(name)).replace("\\", "/")
			if directory.is_link(name):
				directory.list_dir_end()
				return "manifest entry is a link/reparse point: %s" % absolute_path
			if directory.current_is_dir():
				entries.append({
					"relative_path": relative_path,
					"kind": "directory",
					"byte_length": 0,
					"sha256": "",
					"resolved_path": absolute_path,
				})
				var nested_error := _capture_directory(absolute_path, relative_path, entries)
				if not nested_error.is_empty():
					directory.list_dir_end()
					return nested_error
			else:
				var bytes := FileAccess.get_file_as_bytes(absolute_path)
				var read_error := FileAccess.get_open_error()
				if read_error != OK:
					directory.list_dir_end()
					return "cannot read manifest file code=%d path=%s" % [read_error, absolute_path]
				var hash_result := _sha256(bytes)
				if not String(hash_result["error"]).is_empty():
					directory.list_dir_end()
					return "%s path=%s" % [hash_result["error"], absolute_path]
				entries.append({
					"relative_path": relative_path,
					"kind": "file",
					"byte_length": bytes.size(),
					"sha256": hash_result["hash"],
					"resolved_path": absolute_path,
				})
		name = directory.get_next()
	directory.list_dir_end()
	return ""


static func _is_link(absolute_path: String) -> bool:
	var parent := DirAccess.open(absolute_path.get_base_dir())
	return parent != null and parent.is_link(absolute_path.get_file())


static func _sha256(bytes: PackedByteArray) -> Dictionary:
	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return {"error": "cannot start SHA-256 code=%d" % start_error, "hash": ""}
	var update_error := context.update(bytes)
	if update_error != OK:
		return {"error": "cannot update SHA-256 code=%d" % update_error, "hash": ""}
	return {"error": "", "hash": context.finish().hex_encode()}
