class_name LoadoutCompatibilityProjection
extends RefCounted

var _valid := false
var _error := ""
var _selected_class_id: StringName
var _confirmation_token := ""

var _compatible_items: Array[Dictionary] = []
var _incompatible_items: Array[Dictionary] = []
var _planned_stash_destinations: Array[Dictionary] = []
var _overflow_item_ids: Array[String] = []

var valid: bool:
	get:
		return _valid

var error: String:
	get:
		return _error

var selected_class_id: StringName:
	get:
		return _selected_class_id

var confirmation_token: String:
	get:
		return _confirmation_token

var compatible_items: Array[Dictionary]:
	get:
		return _compatible_items.duplicate(true)

var incompatible_items: Array[Dictionary]:
	get:
		return _incompatible_items.duplicate(true)

var planned_stash_destinations: Array[Dictionary]:
	get:
		return _planned_stash_destinations.duplicate(true)

var overflow_item_ids: Array[String]:
	get:
		return _overflow_item_ids.duplicate()

static func success(
	class_id: StringName,
	compatible: Array[Dictionary],
	incompatible: Array[Dictionary],
	destinations: Array[Dictionary],
	overflow: Array[String],
) -> LoadoutCompatibilityProjection:
	var result := LoadoutCompatibilityProjection.new()
	result._valid = true
	result._selected_class_id = class_id
	result._compatible_items = compatible.duplicate(true)
	result._incompatible_items = incompatible.duplicate(true)
	result._planned_stash_destinations = destinations.duplicate(true)
	result._overflow_item_ids = overflow.duplicate()
	result._confirmation_token = confirmation_token_for(
		class_id,
		result.incompatible_sources(),
		result._planned_stash_destinations,
		result._overflow_item_ids,
	)
	return result

static func failure(detail: String) -> LoadoutCompatibilityProjection:
	var result := LoadoutCompatibilityProjection.new()
	result._error = detail
	return result

func incompatible_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in _incompatible_items:
		result.append({
			"instance_id": String(item["instance_id"]),
			"source_container_id": String(item["source_container_id"]),
			"source_slot": int(item["source_slot"]),
		})
	return result

func confirmation_document() -> Dictionary:
	return _confirmation_document(
		selected_class_id,
		incompatible_sources(),
		_planned_stash_destinations,
		_overflow_item_ids,
	)

static func confirmation_token_for(
	class_id: StringName,
	sources: Array[Dictionary],
	destinations: Array[Dictionary],
	overflow: Array[String],
) -> String:
	var document := _confirmation_document(class_id, sources, destinations, overflow)
	return JSON.stringify(_canonicalize(document)).sha256_text()

static func _confirmation_document(
	class_id: StringName,
	sources: Array[Dictionary],
	destinations: Array[Dictionary],
	overflow: Array[String],
) -> Dictionary:
	return {
		"incompatible_sources": sources.duplicate(true),
		"overflow_item_ids": overflow.duplicate(),
		"planned_stash_destinations": destinations.duplicate(true),
		"selected_class_id": String(class_id),
	}

static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key: Variant in source:
			keys.append(String(key))
		keys.sort()
		var result: Dictionary = {}
		for key: String in keys:
			result[key] = _canonicalize(source[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value as Array:
			result.append(_canonicalize(item))
		return result
	return value
