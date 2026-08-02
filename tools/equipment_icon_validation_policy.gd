class_name EquipmentIconValidationPolicy
extends RefCounted

func validate_registries_and_catalog(set_folders: Dictionary, set_item_ids: Dictionary, catalog: EquipmentCatalog) -> Dictionary:
	var folder_sets := _sorted_names(set_folders.keys())
	var manifest_sets := _sorted_names(set_item_ids.keys())
	for set_id: StringName in folder_sets:
		if not set_item_ids.has(set_id):
			return _validation_failure("set=%s missing manifest" % set_id)
	for set_id: StringName in manifest_sets:
		if not set_folders.has(set_id):
			return _validation_failure("set=%s missing folder mapping" % set_id)
	if catalog == null:
		return _validation_failure("catalog is null")

	var manifest_ids: Dictionary = {}
	var manifest_count := 0
	for set_id: StringName in manifest_sets:
		var item_ids: Array = set_item_ids[set_id]
		for raw_id: Variant in item_ids:
			var item_id := StringName(raw_id)
			manifest_count += 1
			if item_id.is_empty():
				return _validation_failure("set=%s has empty manifest id" % set_id)
			if manifest_ids.has(item_id):
				return _validation_failure("duplicate manifest id=%s" % item_id)
			manifest_ids[item_id] = set_id

	var catalog_ids: Dictionary = {}
	for definition: EquipmentBaseDefinition in catalog.definitions:
		if definition == null:
			return _validation_failure("null catalog definition")
		if definition.id.is_empty():
			return _validation_failure("empty catalog id")
		if catalog_ids.has(definition.id):
			return _validation_failure("duplicate catalog id=%s" % definition.id)
		catalog_ids[definition.id] = true
	var catalog_errors := catalog.validate()
	if not catalog_errors.is_empty():
		return _validation_failure("catalog validation failed: %s" % catalog_errors[0])

	for item_id: StringName in _sorted_names(manifest_ids.keys()):
		if not catalog_ids.has(item_id):
			return _validation_failure("manifest id=%s missing catalog definition" % item_id)
	for item_id: StringName in _sorted_names(catalog_ids.keys()):
		if not manifest_ids.has(item_id):
			return _validation_failure("catalog id=%s missing manifest occurrence" % item_id)
	if manifest_count != manifest_ids.size() or manifest_count != catalog.definitions.size() or manifest_count != catalog_ids.size():
		return _validation_failure("inconsistent complete counts manifest=%d manifest_unique=%d catalog=%d catalog_unique=%d" % [manifest_count, manifest_ids.size(), catalog.definitions.size(), catalog_ids.size()])
	return {
		"error": "",
		"registered_sets": folder_sets,
		"manifest_ids": manifest_ids,
		"catalog_ids": catalog_ids,
		"complete_count": manifest_count,
	}

func requested_sets(args: Variant, registered_sets: Array[StringName]) -> Dictionary:
	var set_arguments: Array[String] = []
	for raw_arg: Variant in args:
		var arg := String(raw_arg)
		if arg.begins_with("--sets="):
			set_arguments.append(arg.trim_prefix("--sets="))
	if set_arguments.is_empty():
		return {"error": "", "sets": [&"fighter"], "all": false}
	if set_arguments.size() != 1:
		return _request_failure("multiple conflicting --sets arguments")
	var requested := set_arguments[0].strip_edges()
	if requested == "all":
		var all_sets := registered_sets.duplicate()
		all_sets.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
		return {"error": "", "sets": all_sets, "all": true}
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	for raw_set: String in requested.split(",", true):
		var token := raw_set.strip_edges()
		var set_id := StringName(token)
		if set_id.is_empty():
			return _request_failure("empty set token")
		if set_id == &"all":
			return _request_failure("all must be the complete --sets value")
		if set_id not in registered_sets:
			return _request_failure("unknown set=%s" % set_id)
		if seen.has(set_id):
			return _request_failure("duplicate set=%s" % set_id)
		seen[set_id] = true
		result.append(set_id)
	return {"error": "", "sets": result, "all": false}

func image_error(image: Image, expected_size: int, item_id: StringName, kind: String) -> String:
	if image == null or image.is_empty():
		return "item=%s kind=%s size=%d reason=image is empty" % [item_id, kind, expected_size]
	if image.get_width() != expected_size or image.get_height() != expected_size:
		return "item=%s kind=%s size=%d reason=dimensions actual=%dx%d" % [item_id, kind, expected_size, image.get_width(), image.get_height()]
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	var has_transparency := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha := image.get_pixel(x, y).a
			has_transparency = has_transparency or alpha < 0.99
			if alpha > 0.01:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return "item=%s kind=%s size=%d reason=visible bounds are empty" % [item_id, kind, expected_size]
	if not has_transparency:
		return "item=%s kind=%s size=%d reason=transparency missing" % [item_id, kind, expected_size]
	var padding := 16 if expected_size == 256 else 8 if expected_size == 128 else 0
	var bounds := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	if padding > 0 and (bounds.position.x < padding or bounds.position.y < padding or bounds.end.x > expected_size - padding or bounds.end.y > expected_size - padding):
		return "item=%s kind=%s size=%d reason=padding bounds=%s required=%d" % [item_id, kind, expected_size, bounds, padding]
	return ""

func image_digest(image: Image) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(image.get_data()) != OK:
		return ""
	return context.finish().hex_encode()

func duplicate_pixel_error(image: Image, item_id: StringName, expected_size: int, kind: String, seen_hashes: Dictionary) -> String:
	var digest := image_digest(image)
	if digest.is_empty():
		return "item=%s kind=%s size=%d reason=digest failed" % [item_id, kind, expected_size]
	if seen_hashes.has(digest):
		return "item=%s kind=%s size=%d reason=duplicate pixels duplicate_of=%s" % [item_id, kind, expected_size, seen_hashes[digest]]
	seen_hashes[digest] = item_id
	return ""

func _validation_failure(error: String) -> Dictionary:
	return {"error": error, "registered_sets": [], "manifest_ids": {}, "catalog_ids": {}, "complete_count": 0}

func _request_failure(error: String) -> Dictionary:
	return {"error": error, "sets": [], "all": false}

func _sorted_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(value))
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result
