extends SceneTree

const SET_FOLDERS := {&"fighter": &"forge_vanguard", &"paladin": &"dawn_bulwark", &"ranger": &"greenwood", &"marksman": &"siege_archer", &"rogue": &"nightstep", &"mage": &"emberweave", &"frost_mage": &"rime_scholar", &"cleric": &"storm_chaplain", &"warlock": &"grave_covenant"}
const CATALOG := preload("res://data/equipment/core_equipment_catalog.tres")
const RENDERER_SCRIPT := preload("res://tools/equipment_icon_cpu_renderer.gd")

func _initialize() -> void:
	var registry_error := _registry_error()
	if not registry_error.is_empty(): push_error("EQUIPMENT_ICON_VALIDATION_ERROR registries disagree %s" % registry_error); quit(1); return
	var registered_sets := _registered_sets()
	var requested_sets := _requested_sets(registered_sets)
	if requested_sets.is_empty(): push_error("EQUIPMENT_ICON_VALIDATION_ERROR no registered sets requested"); quit(1); return
	var item_count := 0
	var seen_hashes := {256: {}, 128: {}}
	var renderer := RENDERER_SCRIPT.new() as RefCounted
	for set_id: StringName in requested_sets:
		if not SET_FOLDERS.has(set_id): push_error("EQUIPMENT_ICON_VALIDATION_ERROR set=%s is not registered" % set_id); quit(1); return
		var item_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[set_id]
		for index: int in item_ids.size():
			if not _validate(set_id, index, renderer, seen_hashes): quit(1); return
			item_count += 1
	print("EQUIPMENT_ICON_VALIDATION_OK sets=%d items=%d unique_master=%d unique_runtime=%d" % [requested_sets.size(), item_count, (seen_hashes[256] as Dictionary).size(), (seen_hashes[128] as Dictionary).size()]); quit(0)
func _registry_error() -> String:
	for set_id: StringName in SET_FOLDERS:
		if not ClassEquipmentRows.SET_ITEM_IDS.has(set_id):
			return "set=%s missing manifest" % set_id
	for set_id: StringName in ClassEquipmentRows.SET_ITEM_IDS:
		if not SET_FOLDERS.has(set_id):
			return "set=%s missing folder mapping" % set_id
	return ""

func _registered_sets() -> Array[StringName]:
	var registered_sets: Array[StringName] = []
	for set_id: StringName in SET_FOLDERS.keys():
		registered_sets.append(set_id)
	registered_sets.sort()
	return registered_sets

func _requested_sets(registered_sets: Array[StringName]) -> Array[StringName]:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sets="):
			var result: Array[StringName] = []
			for raw: String in arg.trim_prefix("--sets=").split(","):
				var set_id := StringName(raw.strip_edges())
				if set_id == &"all":
					return registered_sets.duplicate()
				if set_id.is_empty() or set_id not in registered_sets: return []
				result.append(set_id)
			return result
	return [&"fighter"]

func _validate(set_id: StringName, index: int, renderer: RefCounted, seen_hashes: Dictionary) -> bool:
	var id := ClassEquipmentRows.SET_ITEM_IDS[set_id][index] as StringName
	var folder := SET_FOLDERS[set_id] as StringName
	var definition := CATALOG.definition(id)
	if definition == null:
		push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s definition missing" % id)
		return false
	var slot_id := ClassEquipmentRows.slot_for(set_id, index)
	if not EquipmentSlotCatalog.is_valid(slot_id) or slot_id not in definition.compatible_slot_ids:
		push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s registered slot=%s is incompatible" % [id, slot_id])
		return false
	var family := renderer.call(&"family_for", definition, slot_id) as StringName
	if family.is_empty():
		push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s registered slot=%s family is empty" % [id, slot_id])
		return false
	for size: int in [256, 128]:
		var image := Image.new(); var path := ProjectSettings.globalize_path("res://assets/ui/equipment/%s/%s/%s_%d.png" % ["master" if size == 256 else "runtime", folder, id, size])
		if image.load(path) != OK:
			push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s size=%d image load failed" % [id, size])
			return false
		if image.get_width() != size or image.get_height() != size:
			push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s size=%d dimensions=%dx%d" % [id, size, image.get_width(), image.get_height()])
			return false
		var digest := _image_digest(image)
		if digest.is_empty():
			push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s size=%d digest failed" % [id, size])
			return false
		var owner := (seen_hashes[size] as Dictionary).get(digest, &"") as StringName
		if not owner.is_empty() and owner != id:
			push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s duplicate_of=%s size=%d" % [id, owner, size])
			return false
		(seen_hashes[size] as Dictionary)[digest] = id
		var bounds := Rect2i(); var found := false; var transparent := false
		for y: int in image.get_height(): for x: int in image.get_width():
			var pixel := image.get_pixel(x,y); transparent = transparent or pixel.a < 0.99
			if pixel.a > 0.01: bounds = Rect2i(x,y,1,1) if not found else bounds.expand(Vector2i(x,y)); found = true
		if not found or not transparent or (size == 128 and (bounds.position.x < 8 or bounds.position.y < 8 or bounds.end.x > 120 or bounds.end.y > 120)): push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s bounds" % id); return false
	return true

func _image_digest(image: Image) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(image.get_data()) != OK:
		return ""
	return context.finish().hex_encode()
