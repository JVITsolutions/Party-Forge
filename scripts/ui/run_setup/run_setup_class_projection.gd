class_name RunSetupClassProjection
extends RefCounted

enum Compatibility { UNKNOWN, UNAVAILABLE, COMPATIBLE, NEEDS_ATTENTION }

var id: StringName = &""
var display_name := ""
var role_label := ""
var color := Color.WHITE
var _trait_display_names: Array[String] = []
var starting_action_label := ""
var compatibility := Compatibility.UNKNOWN
var _compatibility_copy: Dictionary = {}

var trait_display_names: Array[String]:
	get:
		return _trait_display_names.duplicate()

var compatibility_copy: Dictionary:
	get:
		return _compatibility_copy.duplicate(true)

static func create(
	class_id: StringName,
	class_display_name: String,
	class_role_label: String,
	class_color: Color,
	trait_names: Array,
	action_label: String,
	compatibility_state: Compatibility,
	compatibility_summary: Dictionary,
) -> RunSetupClassProjection:
	var result := RunSetupClassProjection.new()
	result.id = class_id
	result.display_name = class_display_name
	result.role_label = class_role_label
	result.color = class_color
	result._trait_display_names.assign(trait_names)
	result.starting_action_label = action_label
	result.compatibility = compatibility_state
	result._compatibility_copy = compatibility_summary.duplicate(true)
	return result

func copy() -> RunSetupClassProjection:
	return create(id, display_name, role_label, color, _trait_display_names, starting_action_label, compatibility, _compatibility_copy)
