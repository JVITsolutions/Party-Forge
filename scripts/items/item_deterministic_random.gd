class_name ItemDeterministicRandom
extends RefCounted

const SHA256_SEED_HEX_CHARACTERS := 15

static func unit(seed: int, sequence: int, stage: StringName, draw: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = _stage_seed(seed, sequence, stage, draw)
	return rng.randf()

static func weighted_id(seed: int, sequence: int, stage: StringName, draw: int, weights: Dictionary) -> StringName:
	if weights.is_empty():
		return &""
	var ids: Array[String] = []
	var canonical_weights: Dictionary = {}
	var total := 0.0
	for candidate: Variant in weights:
		if typeof(candidate) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return &""
		var raw_weight: Variant = weights[candidate]
		if typeof(raw_weight) not in [TYPE_INT, TYPE_FLOAT]:
			return &""
		var id := String(candidate)
		var weight := float(raw_weight)
		if id.is_empty() or canonical_weights.has(id) or not is_finite(weight) or weight <= 0.0:
			return &""
		canonical_weights[id] = weight
		ids.append(id)
	ids.sort()
	for id: String in ids:
		total += float(canonical_weights[id])
		if not is_finite(total):
			return &""
	if total <= 0.0:
		return &""
	var roll := unit(seed, sequence, stage, draw) * total
	var cumulative := 0.0
	for id: String in ids:
		cumulative += float(canonical_weights[id])
		if roll < cumulative:
			return StringName(id)
	return StringName(ids.back())

static func _stage_seed(seed: int, sequence: int, stage: StringName, draw: int) -> int:
	var digest := ("%d|%d|%s|%d" % [seed, sequence, stage, draw]).sha256_text()
	var derived := digest.substr(0, SHA256_SEED_HEX_CHARACTERS).hex_to_int()
	return maxi(derived, 1)
