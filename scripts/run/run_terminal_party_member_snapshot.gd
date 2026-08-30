class_name RunTerminalPartyMemberSnapshot
extends RefCounted

const FIELDS: Array[String] = [
	"member_id", "display_name", "class_id", "class_name", "is_leader", "final_level",
]

var _member_id := 0
var member_id: int:
	get: return _member_id
var _display_name := ""
var display_name: String:
	get: return _display_name
var _class_id: StringName = &""
var class_id: StringName:
	get: return _class_id
var _class_name := ""
var _is_leader := false
var is_leader: bool:
	get: return _is_leader
var _final_level := 0
var final_level: int:
	get: return _final_level

static func create(
	member_id_value: int,
	display_name_value: String,
	class_id_value: StringName,
	class_name_value: String,
	is_leader_value: bool,
	final_level_value: int,
) -> RunTerminalPartyMemberSnapshot:
	if (
		member_id_value <= 0
		or display_name_value.strip_edges().is_empty()
		or String(class_id_value).strip_edges().is_empty()
		or class_name_value.strip_edges().is_empty()
		or final_level_value <= 0
	):
		return null
	var result := RunTerminalPartyMemberSnapshot.new()
	result._member_id = member_id_value
	result._display_name = display_name_value
	result._class_id = class_id_value
	result._class_name = class_name_value
	result._is_leader = is_leader_value
	result._final_level = final_level_value
	return result

func copy() -> RunTerminalPartyMemberSnapshot:
	return create(_member_id, _display_name, _class_id, _class_name, _is_leader, _final_level)

func to_dictionary() -> Dictionary:
	return {
		"member_id": _member_id,
		"display_name": _display_name,
		"class_id": String(_class_id),
		"class_name": _class_name,
		"is_leader": _is_leader,
		"final_level": _final_level,
	}

func _get(property: StringName) -> Variant:
	if property == &"class_name":
		return _class_name
	return null

func _get_property_list() -> Array[Dictionary]:
	return [{"name": "class_name", "type": TYPE_STRING, "usage": PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_READ_ONLY}]
