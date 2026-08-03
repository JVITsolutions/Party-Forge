class_name PassiveTreeActionDecision
extends RefCounted

var allowed := false
var code: StringName = &""
var message := ""
var point_delta := 0
var next_allocations: Array[StringName] = []
var implicit_start_nodes: Array[StringName] = []

func _init(
	p_allowed: bool = false,
	p_code: StringName = &"",
	p_message: String = "",
	p_point_delta: int = 0,
	p_next_allocations: Array[StringName] = [],
	p_implicit_start_nodes: Array[StringName] = [],
) -> void:
	allowed = p_allowed
	code = p_code
	message = p_message
	point_delta = p_point_delta
	next_allocations = _canonical_ids(p_next_allocations)
	implicit_start_nodes = _canonical_ids(p_implicit_start_nodes)

func ok() -> bool:
	return allowed and code == &"ok"

func _canonical_ids(values: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: StringName in values:
		if value not in result:
			result.append(value)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result
