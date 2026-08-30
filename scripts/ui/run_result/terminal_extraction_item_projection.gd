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
var _owner_member_id := 0
var owner_member_id: int:
	get: return _owner_member_id
var _owner_class_label := ""
var owner_class_label: String:
	get: return _owner_class_label
var _source_container_id := &""
var source_container_id: StringName:
	get: return _source_container_id
var _source_slot := -1
var source_slot: int:
	get: return _source_slot
var source_heading: String:
	get:
		if _owner_member_id > 0:
			return "MEMBER %d · %s · EQUIPMENT" % [_owner_member_id, _owner_class_label.to_upper()]
		return "RUN INVENTORY"
var consequence_label: String:
	get: return "%s · %s · %s · %s (%s) · slot %d" % [_name, _rarity_name, _owner_label, _container_label, String(_source_container_id), _source_slot]
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
	return create_with_source(
		item_id_value, name_value, rarity_name_value, rarity_id_value,
		owner_label_value, container_label_value, automatic_value, selected_value,
		lost_value, detail_value, comparison_values, 0, "", &"", -1,
	)

static func create_with_source(
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
	owner_member_id_value: int,
	owner_class_label_value: String,
	source_container_id_value: StringName,
	source_slot_value: int,
) -> TerminalExtractionItemProjection:
	if item_id_value.strip_edges().is_empty() or name_value.strip_edges().is_empty():
		return null
	if owner_member_id_value < 0 or source_slot_value < -1:
		return null
	if source_slot_value >= 0 and String(source_container_id_value).strip_edges().is_empty():
		return null
	var result := TerminalExtractionItemProjection.new()
	result._item_id = item_id_value
	result._name = name_value
	result._rarity_name = rarity_name_value
	result._rarity_id = rarity_id_value
	result._owner_label = owner_label_value
	result._container_label = container_label_value
	result._owner_member_id = owner_member_id_value
	result._owner_class_label = owner_class_label_value
	result._source_container_id = source_container_id_value
	result._source_slot = source_slot_value
	result.automatic = automatic_value
	result.selected = selected_value
	result.lost = lost_value
	result._detail = detail_value.duplicate(true)
	for comparison: Variant in comparison_values:
		if comparison is Dictionary:
			result._comparisons.append((comparison as Dictionary).duplicate(true))
	return result

func copy() -> TerminalExtractionItemProjection:
	return create_with_source(_item_id, _name, _rarity_name, _rarity_id, _owner_label, _container_label, automatic, selected, lost, _detail, _comparisons, _owner_member_id, _owner_class_label, _source_container_id, _source_slot)

func source_key() -> String:
	return "%d|%s" % [_owner_member_id, String(_source_container_id)]

func to_dictionary() -> Dictionary:
	return {
		"item_id": _item_id,
		"name": _name,
		"rarity_name": _rarity_name,
		"rarity_id": String(_rarity_id),
		"owner_label": _owner_label,
		"container_label": _container_label,
		"owner_member_id": _owner_member_id,
		"owner_class_label": _owner_class_label,
		"source_container_id": String(_source_container_id),
		"source_slot": _source_slot,
		"source_heading": source_heading,
		"consequence_label": consequence_label,
		"automatic": automatic,
		"selected": selected,
		"lost": lost,
		"detail": _detail.duplicate(true),
		"comparisons": _comparisons.duplicate(true),
	}
