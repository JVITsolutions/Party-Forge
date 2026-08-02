extends RefCounted

const POLICY_SCRIPT := preload("res://tools/equipment_icon_validation_policy.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var hashes := {256: {}, 128: {}}
	var policy := POLICY_SCRIPT.new() as RefCounted
	for set_id: StringName in ClassEquipmentRows.SET_ITEM_IDS:
		var folder := StringName(ClassEquipmentRows.SET_FOLDERS[set_id])
		for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			for size: int in [256, 128]:
				var kind := "master" if size == 256 else "runtime"
				var path := "res://assets/ui/equipment/%s/%s/%s_%d.png" % [kind, folder, item_id, size]
				var image := Image.new()
				TestAssertions.equal(image.load(ProjectSettings.globalize_path(path)), OK, "%s %s icon loads" % [item_id, kind], failures)
				if image.is_empty():
					continue
				var validation_error := String(policy.call(&"image_error", image, size, item_id, kind))
				TestAssertions.equal(validation_error, "", "%s %s icon satisfies shared geometry policy" % [item_id, kind], failures)
				var digest := _image_digest(image)
				TestAssertions.truthy(not (hashes[size] as Dictionary).has(digest), "%s %s pixels differ from %s" % [item_id, kind, (hashes[size] as Dictionary).get(digest, &"<none>")], failures)
				(hashes[size] as Dictionary)[digest] = item_id
	return failures

func _image_digest(image: Image) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(image.get_data()) != OK:
		return ""
	return context.finish().hex_encode()
