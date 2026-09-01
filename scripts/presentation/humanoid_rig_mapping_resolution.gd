class_name HumanoidRigMappingResolution
extends RefCounted

const SCRIPT_PATH := "res://scripts/presentation/humanoid_rig_mapping_resolution.gd"
const RigMapping := preload("res://scripts/presentation/humanoid_rig_mapping.gd")
const _RESOURCE_PATH_BY_BODY_PRESET := {
	&"masculine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
	&"feminine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
}
const UNKNOWN_BODY_PRESET := &"unknown_body_preset"
const MISSING_RESOURCE := &"missing_resource"
const RESOURCE_LOAD_FAILED := &"resource_load_failed"
const WRONG_RESOURCE_TYPE := &"wrong_resource_type"
const WRONG_MAPPING_ID := &"wrong_mapping_id"
const WRONG_CANONICAL_RIG_ID := &"wrong_canonical_rig_id"
const WRONG_SOURCE_HASH := &"wrong_source_hash"
const WRONG_REST_SIGNATURE := &"wrong_rest_signature"
const MAPPED_RIG_VALIDATION_FAILED := &"mapped_rig_validation_failed"
const _CATEGORY_ORDER := {
	UNKNOWN_BODY_PRESET: 0, MISSING_RESOURCE: 1, RESOURCE_LOAD_FAILED: 2,
	WRONG_RESOURCE_TYPE: 3, WRONG_MAPPING_ID: 4, WRONG_CANONICAL_RIG_ID: 5,
	WRONG_SOURCE_HASH: 6, WRONG_REST_SIGNATURE: 7, MAPPED_RIG_VALIDATION_FAILED: 8,
}
static var _factory_token := RefCounted.new()

var _requested_body_preset := StringName()
var _selected_resource_path := ""
var _mapping: RigMapping = null
var _failure_categories: Array[StringName] = []
var _error_messages := PackedStringArray()
var _construction_valid := false

func _init(
		factory_token: RefCounted,
		requested_body_preset: StringName,
		selected_resource_path: String,
		mapping: RigMapping,
		failure_categories: Array[StringName],
		error_messages: PackedStringArray
	) -> void:
	if factory_token != _factory_token:
		push_error("humanoid rig mapping resolution constructor contract failed: invalid factory token")
		return
	_requested_body_preset = requested_body_preset
	_selected_resource_path = selected_resource_path
	_mapping = mapping
	_failure_categories.assign(failure_categories)
	_error_messages = error_messages.duplicate()
	_construction_valid = true

static func succeeded(requested_body_preset: StringName, selected_resource_path: String, mapping: RigMapping) -> RefCounted:
	var defects := PackedStringArray()
	if requested_body_preset not in _RESOURCE_PATH_BY_BODY_PRESET:
		defects.append("success body preset %s is invalid" % requested_body_preset)
	elif selected_resource_path != _RESOURCE_PATH_BY_BODY_PRESET[requested_body_preset]:
		defects.append("success resource path does not match body preset %s" % requested_body_preset)
	if mapping == null:
		defects.append("success mapping is missing")
	if not defects.is_empty():
		push_error("humanoid rig mapping resolution factory contract failed: %s" % "; ".join(defects))
		return null
	var categories: Array[StringName] = []
	var result_script := load(SCRIPT_PATH) as Script
	if result_script == null:
		push_error("humanoid rig mapping resolution factory contract failed: result script could not be loaded from %s" % SCRIPT_PATH)
		return null
	return result_script.new(_factory_token, requested_body_preset, selected_resource_path, mapping, categories, PackedStringArray())

static func failed(requested_body_preset: StringName, selected_resource_path: String, failure_categories: Array[StringName], error_messages: PackedStringArray) -> RefCounted:
	var categories: Array[StringName] = []
	categories.assign(failure_categories)
	var messages := error_messages.duplicate()
	var defects := _failure_defects(requested_body_preset, selected_resource_path, categories, messages)
	if not defects.is_empty():
		push_error("humanoid rig mapping resolution factory contract failed: %s" % "; ".join(defects))
		return null
	var result_script := load(SCRIPT_PATH) as Script
	if result_script == null:
		push_error("humanoid rig mapping resolution factory contract failed: result script could not be loaded from %s" % SCRIPT_PATH)
		return null
	return result_script.new(_factory_token, requested_body_preset, selected_resource_path, null, categories, messages)

func get_requested_body_preset() -> StringName:
	return _requested_body_preset

func get_selected_resource_path() -> String:
	return _selected_resource_path

func get_mapping() -> RigMapping:
	return _mapping

func get_failure_categories() -> Array[StringName]:
	var copy: Array[StringName] = []
	copy.assign(_failure_categories)
	return copy

func get_error_messages() -> PackedStringArray:
	return _error_messages.duplicate()

func is_success() -> bool:
	return _construction_valid and _requested_body_preset in _RESOURCE_PATH_BY_BODY_PRESET and _selected_resource_path == _RESOURCE_PATH_BY_BODY_PRESET[_requested_body_preset] and _mapping != null and _failure_categories.is_empty() and _error_messages.is_empty()

func rejected_by_mapped_rig(validation_errors: PackedStringArray) -> RefCounted:
	if not is_success() or validation_errors.is_empty():
		return self
	var copied_errors := validation_errors.duplicate()
	var categories: Array[StringName] = []
	var messages := PackedStringArray()
	for validation_error: String in copied_errors:
		categories.append(MAPPED_RIG_VALIDATION_FAILED)
		messages.append("humanoid rig mapping catalog body preset %s resource %s mapped rig validation failed: %s" % [_requested_body_preset, _selected_resource_path, validation_error])
	return failed(_requested_body_preset, _selected_resource_path, categories, messages)

static func _failure_defects(requested_body_preset: StringName, selected_resource_path: String, categories: Array[StringName], messages: PackedStringArray) -> PackedStringArray:
	var defects := PackedStringArray()
	if categories.is_empty():
		defects.append("failure categories are empty")
	if messages.is_empty():
		defects.append("failure messages are empty")
	if categories.size() != messages.size():
		defects.append("failure category/message cardinality differs: %d categories, %d messages" % [categories.size(), messages.size()])
	var every_category_known := true
	for index: int in categories.size():
		var category := categories[index]
		if not _CATEGORY_ORDER.has(category):
			defects.append("failure category %d is unknown: %s" % [index, category])
			every_category_known = false
		if index < messages.size() and messages[index].strip_edges().is_empty():
			defects.append("failure message %d is empty" % index)
	if every_category_known and not categories.is_empty():
		var first_order := int(_CATEGORY_ORDER[categories[0]])
		if first_order <= 3:
			if categories.size() != 1:
				defects.append("terminal failure category %s must be the only category" % categories[0])
		elif first_order <= 7:
			var previous_order := 3
			for category: StringName in categories:
				var current_order := int(_CATEGORY_ORDER[category])
				if current_order < 4 or current_order > 7 or current_order <= previous_order:
					defects.append("identity failure categories must be unique and strictly ordered")
					break
				previous_order = current_order
		else:
			for category: StringName in categories:
				if category != MAPPED_RIG_VALIDATION_FAILED:
					defects.append("mapped rig validation failures cannot mix with another category")
					break
	if not categories.is_empty() and categories[0] == UNKNOWN_BODY_PRESET:
		if requested_body_preset in _RESOURCE_PATH_BY_BODY_PRESET:
			defects.append("unknown preset failure requires an unknown body preset")
		if not selected_resource_path.is_empty():
			defects.append("unknown preset failure requires an empty resource path")
	elif not categories.is_empty() and _CATEGORY_ORDER.has(categories[0]):
		if requested_body_preset not in _RESOURCE_PATH_BY_BODY_PRESET:
			defects.append("failure requires a known body preset")
		elif selected_resource_path != _RESOURCE_PATH_BY_BODY_PRESET[requested_body_preset]:
			defects.append("failure resource path does not match body preset %s" % requested_body_preset)
	return defects
