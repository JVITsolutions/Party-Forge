class_name LoadoutTransitionRequest
extends RefCounted

var _transaction_id := ""
var _profile_id := ""
var _selected_class_id: StringName
var _confirmed := false
var _cancelled := false
var _confirmation_token := ""

var _incompatible_sources: Array[Dictionary] = []
var _planned_stash_destinations: Array[Dictionary] = []
var _overflow_item_ids: Array[String] = []

var transaction_id: String:
	get:
		return _transaction_id

var profile_id: String:
	get:
		return _profile_id

var selected_class_id: StringName:
	get:
		return _selected_class_id

var confirmed: bool:
	get:
		return _confirmed

var cancelled: bool:
	get:
		return _cancelled

var confirmation_token: String:
	get:
		return _confirmation_token

var incompatible_sources: Array[Dictionary]:
	get:
		return _incompatible_sources.duplicate(true)

var planned_stash_destinations: Array[Dictionary]:
	get:
		return _planned_stash_destinations.duplicate(true)

var overflow_item_ids: Array[String]:
	get:
		return _overflow_item_ids.duplicate()

static func create(
	transaction_id_value: String,
	profile_id_value: String,
	selected_class_id_value: StringName,
	incompatible_sources_value: Array[Dictionary],
	planned_stash_destinations_value: Array[Dictionary],
	overflow_item_ids_value: Array[String],
	confirmed_value: bool,
	cancelled_value: bool,
	confirmation_token_value: String,
) -> LoadoutTransitionRequest:
	var result := LoadoutTransitionRequest.new()
	result._transaction_id = transaction_id_value
	result._profile_id = profile_id_value
	result._selected_class_id = selected_class_id_value
	result._incompatible_sources = incompatible_sources_value.duplicate(true)
	result._planned_stash_destinations = planned_stash_destinations_value.duplicate(true)
	result._overflow_item_ids = overflow_item_ids_value.duplicate()
	result._confirmed = confirmed_value
	result._cancelled = cancelled_value
	result._confirmation_token = confirmation_token_value
	return result

func canonical_document() -> Dictionary:
	return {
		"cancelled": cancelled,
		"confirmation_token": confirmation_token,
		"confirmed": confirmed,
		"incompatible_sources": _incompatible_sources.duplicate(true),
		"overflow_item_ids": _overflow_item_ids.duplicate(),
		"planned_stash_destinations": _planned_stash_destinations.duplicate(true),
		"profile_id": profile_id,
		"selected_class_id": String(selected_class_id),
		"transaction_id": transaction_id,
	}
