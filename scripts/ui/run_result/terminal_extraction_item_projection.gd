class_name TerminalExtractionItemProjection
extends RefCounted

var _item_id := ""
var item_id: String:
	get: return _item_id
var _name := ""
var name: String:
	get: return _name
var _rarity_name := ""
var rarity_name: String:
	get: return _rarity_name
var _rarity_id := &""
var rarity_id: StringName:
	get: return _rarity_id
var _owner_label := ""
var owner_label: String:
	get: return _owner_label
var _container_label := ""
var container_label: String:
	get: return _container_label
var automatic := false
var selected := false
var lost := false
var _detail: Dictionary = {}
var detail: Dictionary:
	get: return _detail.duplicate(true)
var _comparisons: Array[Dictionary] = []
var comparisons: Array[Dictionary]:
	get: return _comparisons.duplicate(true)

static func create(
	item_id_value: String,
	name_value: String,
	rarity_name_value: String,
	rarity_id_value: StringName,
	owner_label_value: String,
	container_label_value: String,
	automatic_value: bool,
	selected_value: bool,
	lost_value: bool,
	detail_value: Dictionary,
	comparison_values: Array,
) -> TerminalExtractionItemProjection:
	if item_id_value.strip_edges().is_empty() or name_value.strip_edges().is_empty():
		return null
	var result := TerminalExtractionItemProjection.new()
	result._item_id = item_id_value
	result._name = name_value
	result._rarity_name = rarity_name_value
	result._rarity_id = rarity_id_value
	result._owner_label = owner_label_value
	result._container_label = container_label_value
	result.automatic = automatic_value
	result.selected = selected_value
	result.lost = lost_value
	result._detail = detail_value.duplicate(true)
	for comparison: Variant in comparison_values:
		if comparison is Dictionary:
			result._comparisons.append((comparison as Dictionary).duplicate(true))
	return result

func copy() -> TerminalExtractionItemProjection:
	return create(_item_id, _name, _rarity_name, _rarity_id, _owner_label, _container_label, automatic, selected, lost, _detail, _comparisons)

func to_dictionary() -> Dictionary:
	return {
		"item_id": _item_id,
		"name": _name,
		"rarity_name": _rarity_name,
		"rarity_id": String(_rarity_id),
		"owner_label": _owner_label,
		"container_label": _container_label,
		"automatic": automatic,
		"selected": selected,
		"lost": lost,
		"detail": _detail.duplicate(true),
		"comparisons": _comparisons.duplicate(true),
	}
