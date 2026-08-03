class_name PassiveTreeNodeViewData
extends RefCounted

var id: StringName
var position: Vector2
var type: StringName
var state: StringName
var display_name: String
var description: String
var cost: int
var cost_text: String
var effect_lines: Array[String] = []
var requirement_lines: Array[String] = []
var keyword_lines: Array[String] = []
var metadata: Dictionary = {}
var permanent := false
var allocated := false
var allocatable := false
var decision_code: StringName
var decision_message: String

func _init(
	p_id: StringName = &"",
	p_position: Vector2 = Vector2.ZERO,
	p_type: StringName = &"",
	p_state: StringName = &"obscured",
	p_display_name: String = "???",
	p_description: String = "???",
	p_cost: int = -1,
	p_cost_text: String = "?",
	p_effect_lines: Array[String] = [],
	p_requirement_lines: Array[String] = [],
	p_keyword_lines: Array[String] = [],
	p_metadata: Dictionary = {},
	p_permanent: bool = false,
	p_allocated: bool = false,
	p_allocatable: bool = false,
	p_decision_code: StringName = &"node_obscured",
	p_decision_message: String = "",
) -> void:
	id = p_id
	position = p_position
	type = p_type
	state = p_state
	display_name = p_display_name
	description = p_description
	cost = p_cost
	cost_text = p_cost_text
	effect_lines.assign(p_effect_lines)
	requirement_lines.assign(p_requirement_lines)
	keyword_lines.assign(p_keyword_lines)
	metadata = value_only_copy(p_metadata) as Dictionary
	permanent = p_permanent
	allocated = p_allocated
	allocatable = p_allocatable
	decision_code = p_decision_code
	decision_message = p_decision_message

func copy() -> PassiveTreeNodeViewData:
	return PassiveTreeNodeViewData.new(
		id,
		position,
		type,
		state,
		display_name,
		description,
		cost,
		cost_text,
		effect_lines,
		requirement_lines,
		keyword_lines,
		metadata,
		permanent,
		allocated,
		allocatable,
		decision_code,
		decision_message,
	)

static func value_only_copy(value: Variant) -> Variant:
	var result := _value_copy_result(value)
	return result["value"] if result["supported"] else null

static func _value_copy_result(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2:
			return {"supported": true, "value": value}
		TYPE_ARRAY:
			var copied_array: Array = []
			for item: Variant in value as Array:
				var item_result := _value_copy_result(item)
				if item_result["supported"]:
					copied_array.append(item_result["value"])
			return {"supported": true, "value": copied_array}
		TYPE_DICTIONARY:
			var copied_dictionary: Dictionary = {}
			for key: Variant in (value as Dictionary).keys():
				var key_result := _value_copy_result(key)
				var value_result := _value_copy_result((value as Dictionary)[key])
				if key_result["supported"] and value_result["supported"]:
					copied_dictionary[key_result["value"]] = value_result["value"]
			return {"supported": true, "value": copied_dictionary}
		_:
			return {"supported": false, "value": null}
