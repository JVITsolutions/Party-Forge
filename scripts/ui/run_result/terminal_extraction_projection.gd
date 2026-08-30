class_name TerminalExtractionProjection
extends RefCounted

var _automatic_items: Array[TerminalExtractionItemProjection] = []
var automatic_items: Array[TerminalExtractionItemProjection]:
	get: return _copy_items(_automatic_items)
var _eligible_items: Array[TerminalExtractionItemProjection] = []
var eligible_items: Array[TerminalExtractionItemProjection]:
	get: return _copy_items(_eligible_items)
var capacity := 0
var _selected_item_ids: Array[String] = []
var selected_item_ids: Array[String]:
	get: return _selected_item_ids.duplicate()
var _lost_item_ids: Array[String] = []
var lost_item_ids: Array[String]:
	get: return _lost_item_ids.duplicate()
var _changed_item_ids: Array[String] = []
var changed_item_ids: Array[String]:
	get: return _changed_item_ids.duplicate()
var player_error := ""
var valid := false
var pending := false

var automatic_count: int:
	get: return _automatic_items.size()
var selected_count: int:
	get: return _selected_item_ids.size()
var lost_count: int:
	get: return _lost_item_ids.size()

static func create(
	automatic_values: Array,
	eligible_values: Array,
	capacity_value: int,
	selected_values: Array,
	lost_values: Array,
	changed_values: Array,
	player_error_value: String,
	valid_value: bool,
) -> TerminalExtractionProjection:
	var result := TerminalExtractionProjection.new()
	result._automatic_items = _typed_copies(automatic_values)
	result._eligible_items = _typed_copies(eligible_values)
	result.capacity = maxi(0, capacity_value)
	result._selected_item_ids = _typed_strings(selected_values)
	result._lost_item_ids = _typed_strings(lost_values)
	result._changed_item_ids = _typed_strings(changed_values)
	result.player_error = player_error_value
	result.valid = valid_value
	return result

func copy() -> TerminalExtractionProjection:
	var result := create(_automatic_items, _eligible_items, capacity, _selected_item_ids, _lost_item_ids, _changed_item_ids, player_error, valid)
	result.pending = pending
	return result

func to_dictionary() -> Dictionary:
	return {
		"automatic_items": _item_documents(_automatic_items),
		"eligible_items": _item_documents(_eligible_items),
		"capacity": capacity,
		"selected_item_ids": _selected_item_ids.duplicate(),
		"lost_item_ids": _lost_item_ids.duplicate(),
		"changed_item_ids": _changed_item_ids.duplicate(),
		"player_error": player_error,
		"valid": valid,
		"pending": pending,
	}

static func _typed_copies(values: Array) -> Array[TerminalExtractionItemProjection]:
	var result: Array[TerminalExtractionItemProjection] = []
	for value: Variant in values:
		if value is TerminalExtractionItemProjection:
			result.append((value as TerminalExtractionItemProjection).copy())
	return result

static func _typed_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result

static func _copy_items(values: Array[TerminalExtractionItemProjection]) -> Array[TerminalExtractionItemProjection]:
	var result: Array[TerminalExtractionItemProjection] = []
	for value: TerminalExtractionItemProjection in values:
		result.append(value.copy())
	return result

static func _item_documents(values: Array[TerminalExtractionItemProjection]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: TerminalExtractionItemProjection in values:
		result.append(value.to_dictionary())
	return result
