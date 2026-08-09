class_name ItemGenerationResult
extends RefCounted

var _item: ItemInstance
var item: ItemInstance:
	get:
		return _item
	set(_value):
		pass
var _failure: ItemGenerationFailure
var failure: ItemGenerationFailure:
	get:
		return _failure
	set(_value):
		pass
var _trace: ItemGenerationTrace
var trace: ItemGenerationTrace:
	get:
		return _trace
	set(_value):
		pass

func _init(item_value: ItemInstance, failure_value: ItemGenerationFailure, trace_value: ItemGenerationTrace) -> void:
	_trace = trace_value
	if (item_value != null) != (failure_value != null):
		_item = item_value
		_failure = failure_value
		return
	_failure = ItemGenerationFailure.new()
	_failure.stage = &"result"
	_failure.code = &"invalid_result_construction"

static func success(item_value: ItemInstance, trace_value: ItemGenerationTrace) -> ItemGenerationResult:
	if item_value == null:
		return null
	return ItemGenerationResult.new(item_value, null, trace_value)

static func failed(failure_value: ItemGenerationFailure, trace_value: ItemGenerationTrace) -> ItemGenerationResult:
	if failure_value == null:
		return null
	return ItemGenerationResult.new(null, failure_value, trace_value)

func ok() -> bool:
	return _item != null and _failure == null
