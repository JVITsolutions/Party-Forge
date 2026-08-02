extends SceneTree

const CATALOG := preload("res://data/equipment/core_equipment_catalog.tres")
const RENDERER_SCRIPT := preload("res://tools/equipment_icon_cpu_renderer.gd")
const POLICY_SCRIPT := preload("res://tools/equipment_icon_validation_policy.gd")

func _initialize() -> void:
	var policy := POLICY_SCRIPT.new() as RefCounted
	var validation := policy.call(&"validate_registries_and_catalog", ClassEquipmentRows.SET_FOLDERS, ClassEquipmentRows.SET_ITEM_IDS, CATALOG) as Dictionary
	var validation_error := String(validation.get("error", ""))
	if not validation_error.is_empty():
		_fail(validation_error)
		return
	var registered_sets: Array[StringName] = []
	for set_id: StringName in validation.get("registered_sets", []):
		registered_sets.append(set_id)
	var request := policy.call(&"requested_sets", OS.get_cmdline_user_args(), registered_sets) as Dictionary
	var request_error := String(request.get("error", ""))
	if not request_error.is_empty():
		_fail(request_error)
		return
	var requested_sets: Array[StringName] = []
	for set_id: StringName in request.get("sets", []):
		requested_sets.append(set_id)
	if requested_sets.is_empty():
		_fail("no registered sets requested")
		return

	var item_count := 0
	var seen_hashes := {256: {}, 128: {}}
	var renderer := RENDERER_SCRIPT.new() as RefCounted
	for set_id: StringName in requested_sets:
		if not ClassEquipmentRows.SET_FOLDERS.has(set_id):
			_fail("set=%s is not registered" % set_id)
			return
		var item_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[set_id]
		for index: int in item_ids.size():
			var error := _validate_item(set_id, index, renderer, policy, seen_hashes)
			if not error.is_empty():
				_fail(error)
				return
			item_count += 1

	var unique_master := (seen_hashes[256] as Dictionary).size()
	var unique_runtime := (seen_hashes[128] as Dictionary).size()
	if bool(request.get("all", false)):
		var complete_count := int(validation.get("complete_count", -1))
		if item_count != complete_count or unique_master != complete_count or unique_runtime != complete_count:
			_fail("all-set count mismatch complete=%d items=%d unique_master=%d unique_runtime=%d" % [complete_count, item_count, unique_master, unique_runtime])
			return
	print("EQUIPMENT_ICON_VALIDATION_OK sets=%d items=%d unique_master=%d unique_runtime=%d" % [requested_sets.size(), item_count, unique_master, unique_runtime])
	quit(0)

func _validate_item(set_id: StringName, index: int, renderer: RefCounted, policy: RefCounted, seen_hashes: Dictionary) -> String:
	var item_id := ClassEquipmentRows.SET_ITEM_IDS[set_id][index] as StringName
	var folder := ClassEquipmentRows.SET_FOLDERS[set_id] as StringName
	var definition := CATALOG.definition(item_id)
	if definition == null:
		return "item=%s definition missing" % item_id
	var slot_id := ClassEquipmentRows.slot_for(set_id, index)
	if not EquipmentSlotCatalog.is_valid(slot_id) or slot_id not in definition.compatible_slot_ids:
		return "item=%s registered slot=%s is incompatible" % [item_id, slot_id]
	var family := renderer.call(&"family_for", definition, slot_id) as StringName
	if family.is_empty():
		return "item=%s registered slot=%s family is empty" % [item_id, slot_id]
	for size: int in [256, 128]:
		var kind := "master" if size == 256 else "runtime"
		var path := ProjectSettings.globalize_path("res://assets/ui/equipment/%s/%s/%s_%d.png" % [kind, folder, item_id, size])
		var image := Image.new()
		if image.load(path) != OK:
			return "item=%s kind=%s size=%d reason=image load failed path=%s" % [item_id, kind, size, path]
		var image_error := String(policy.call(&"image_error", image, size, item_id, kind))
		if not image_error.is_empty():
			return image_error
		var duplicate_error := String(policy.call(&"duplicate_pixel_error", image, item_id, size, kind, seen_hashes[size] as Dictionary))
		if not duplicate_error.is_empty():
			return duplicate_error
	return ""

func _fail(reason: String) -> void:
	push_error("EQUIPMENT_ICON_VALIDATION_ERROR %s" % reason)
	quit(1)
