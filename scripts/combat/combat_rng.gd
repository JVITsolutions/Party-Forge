class_name CombatRng
extends RefCounted

var _rng := RandomNumberGenerator.new()
var _prescribed: Array[float] = []
var draw_count := 0

func _init(seed_value: int = 0, prescribed_draws: Array[float] = []) -> void:
	reseed(seed_value, prescribed_draws)

func reseed(seed_value: int, prescribed_draws: Array[float] = []) -> void:
	_rng.seed = seed_value
	_prescribed.clear()
	for draw: float in prescribed_draws:
		if is_finite(draw) and draw >= 0.0 and draw < 1.0: _prescribed.append(draw)
		else: push_error("PARTY_FORGE_DAMAGE_ERROR rng_draw=%s reason=draw must be finite and in [0,1)" % draw)
	draw_count = 0

func roll(chance: float) -> Dictionary:
	if not is_finite(chance):
		push_error("PARTY_FORGE_DAMAGE_ERROR chance=%s reason=chance must be finite" % chance)
		return {"consumed": false, "draw": -1.0, "success": false}
	var finalized := clampf(chance, 0.0, 1.0)
	if finalized <= 0.0: return {"consumed": false, "draw": -1.0, "success": false}
	if finalized >= 1.0: return {"consumed": false, "draw": -1.0, "success": true}
	var draw := unit()
	return {"consumed": true, "draw": draw, "success": draw < finalized}

func unit() -> float:
	var draw: float = _prescribed.pop_front() if not _prescribed.is_empty() else _rng.randf()
	draw_count += 1
	return draw
