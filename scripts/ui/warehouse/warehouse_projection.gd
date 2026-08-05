class_name WarehouseProjection
extends RefCounted

var _storage: ProfileStorageProjection

var stash_tabs: Array[Dictionary]: get = _get_stash_tabs

static func from_storage(storage: ProfileStorageProjection) -> WarehouseProjection:
	var result := WarehouseProjection.new()
	result._storage = storage.copy() if storage != null else ProfileStorageProjection.new()
	return result

func item(instance_id: String) -> Dictionary:
	return _storage.item(instance_id) if _storage != null else {}

func displayed_items(search: String, rarity_id: StringName, item_type_id: StringName, sort_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var position := 0
	for tab: Dictionary in stash_tabs:
		var slots := tab["slots"] as Dictionary
		var indices: Array[int] = []
		for key: Variant in slots:
			indices.append(int(key))
		indices.sort()
		for slot: int in indices:
			var instance_id := String(slots.get(str(slot), slots.get(slot, "")))
			var detail := item(instance_id)
			if detail.is_empty():
				continue
			var needle := search.strip_edges().to_lower()
			if not needle.is_empty() and needle not in String(detail["name"]).to_lower() and needle not in instance_id.to_lower():
				continue
			if not rarity_id.is_empty() and String(detail["rarity_id"]) != String(rarity_id):
				continue
			if not item_type_id.is_empty() and String(detail["item_type_id"]) != String(item_type_id):
				continue
			var entry := detail.duplicate(true)
			entry["container_id"] = tab["container_id"]
			entry["slot"] = slot
			entry["stable_position"] = position
			position += 1
			result.append(entry)
	if sort_id == &"name":
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var comparison := String(a["name"]).naturalnocasecmp_to(String(b["name"]))
			return comparison < 0 or (comparison == 0 and int(a["stable_position"]) < int(b["stable_position"]))
		)
	elif sort_id == &"item_level":
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["item_level"]) > int(b["item_level"]) or (int(a["item_level"]) == int(b["item_level"]) and int(a["stable_position"]) < int(b["stable_position"]))
		)
	return result.duplicate(true)

func storage_projection() -> ProfileStorageProjection:
	return _storage.copy() if _storage != null else ProfileStorageProjection.new()

func _get_stash_tabs() -> Array[Dictionary]: return _storage.stash_tabs if _storage != null else []
