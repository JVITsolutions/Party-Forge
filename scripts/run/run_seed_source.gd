class_name RunSeedSource
extends RefCounted

const MAX_FRESH_RUN_SEED := 2147483647

var _entropy: Callable
var _rng := RandomNumberGenerator.new()
var _issued: Dictionary = {}


func _init(entropy: Callable = Callable()) -> void:
	_entropy = entropy
	_rng.randomize()


func next_seed() -> int:
	var raw: Variant = _entropy.call() if _entropy.is_valid() else _rng.randi_range(1, MAX_FRESH_RUN_SEED)
	var candidate := _normalize(raw)
	while _issued.has(candidate):
		candidate = 1 if candidate >= MAX_FRESH_RUN_SEED else candidate + 1
	_issued[candidate] = true
	return candidate


func _normalize(value: Variant) -> int:
	if typeof(value) != TYPE_INT:
		return _rng.randi_range(1, MAX_FRESH_RUN_SEED)
	var normalized := posmod(int(value), MAX_FRESH_RUN_SEED)
	return MAX_FRESH_RUN_SEED if normalized == 0 else normalized
