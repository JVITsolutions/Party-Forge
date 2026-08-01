class_name LevelUpRevealController
extends Node

signal resolved

const TOTAL_DURATION := 1.1
const DROP_DURATION := 0.3
const PREVIEW_INTERVAL := 0.075
const DROP_OFFSET := -520.0

var _cards: Array[UpgradeCard] = []
var _final_bindings: Array[Dictionary] = []
var _preview_presentations: Array[Dictionary] = []
var _base_positions: Array[Vector2] = []
var _elapsed := 0.0
var _cycle_index := 0
var _revealing := false
var _resolved_emitted := false


func play(
	cards: Array[UpgradeCard],
	final_bindings: Array[Dictionary],
	preview_presentations: Array[Dictionary],
	reduced_motion: bool
) -> void:
	reset()
	_cards = cards.duplicate()
	_final_bindings = final_bindings.duplicate(true)
	_preview_presentations = preview_presentations.duplicate(true)
	_elapsed = 0.0
	_cycle_index = 0
	_resolved_emitted = false
	_revealing = true
	for card: UpgradeCard in _cards:
		_base_positions.append(card.position)
		card.disabled = true
		card.position += Vector2(0.0, DROP_OFFSET)
	if reduced_motion:
		_resolve()


func skip() -> void:
	if _revealing:
		_resolve()


func advance(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if not _revealing:
		return
	var drop_progress := clampf(_elapsed / DROP_DURATION, 0.0, 1.0)
	for index: int in mini(_cards.size(), _base_positions.size()):
		_cards[index].position = _base_positions[index] + Vector2(
			0.0,
			lerpf(DROP_OFFSET, 0.0, drop_progress)
		)
	var next_cycle_index := int(floor(_elapsed / PREVIEW_INTERVAL))
	if next_cycle_index > _cycle_index:
		_cycle_index = next_cycle_index
		_bind_cycle_previews()
	if _elapsed >= TOTAL_DURATION:
		_resolve()


func is_revealing() -> bool:
	return _revealing


func elapsed_phase() -> float:
	return _elapsed


func reset() -> void:
	for index: int in mini(_cards.size(), _base_positions.size()):
		if is_instance_valid(_cards[index]):
			_cards[index].position = _base_positions[index]
	_cards.clear()
	_final_bindings.clear()
	_preview_presentations.clear()
	_base_positions.clear()
	_elapsed = 0.0
	_cycle_index = 0
	_revealing = false
	_resolved_emitted = false


func _bind_cycle_previews() -> void:
	if _preview_presentations.is_empty():
		return
	for index: int in _cards.size():
		var preview_index := (_cycle_index + index) % _preview_presentations.size()
		_cards[index].bind_preview(_preview_presentations[preview_index])


func _resolve() -> void:
	if not _revealing or _resolved_emitted:
		return
	_revealing = false
	for index: int in _cards.size():
		var card := _cards[index]
		if index < _base_positions.size():
			card.position = _base_positions[index]
		if index >= _final_bindings.size():
			continue
		var final_binding := _final_bindings[index]
		card.bind_choice(
			final_binding.get("choice") as UpgradeChoice,
			final_binding.get("presentation", {}) as Dictionary,
			str(final_binding.get("disabled_reason", ""))
		)
	_resolved_emitted = true
	resolved.emit()
