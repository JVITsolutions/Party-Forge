class_name CharacterNameService
extends RefCounted

static func choose_name(class_pool: CharacterNamePool, fallback_pool: CharacterNamePool, run_seed: int, member_id: int, used_names: PackedStringArray) -> String:
	var candidates := class_pool.names.duplicate() if class_pool != null else PackedStringArray()
	for fallback: String in fallback_pool.names if fallback_pool != null else PackedStringArray():
		if fallback not in candidates:
			candidates.append(fallback)
	if candidates.is_empty():
		push_warning("PARTY_FORGE_NAME_WARNING member=%d reason=no available names" % member_id)
		return "Unnamed #%d" % member_id
	var start: int = absi(hash("%d:%d" % [run_seed, member_id])) % candidates.size()
	for offset: int in candidates.size():
		var candidate := candidates[(start + offset) % candidates.size()]
		if candidate not in used_names:
			return candidate
	return candidates[start]
