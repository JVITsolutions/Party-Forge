class_name RunResultPartyMemberProjection
extends RefCounted

var member_id := 0
var display_name := ""
var class_id: StringName = &""
var class_label := ""
var is_leader := false
var final_level := 0

static func create(
	member_id_value: int,
	display_name_value: String,
	class_id_value: StringName,
	class_label_value: String,
	is_leader_value: bool,
	final_level_value: int,
) -> RunResultPartyMemberProjection:
	var result := RunResultPartyMemberProjection.new()
	result.member_id = member_id_value
	result.display_name = display_name_value.strip_edges()
	result.class_id = class_id_value
	result.class_label = class_label_value.strip_edges()
	result.is_leader = is_leader_value
	result.final_level = final_level_value
	return result

func valid() -> bool:
	return member_id > 0 and not display_name.is_empty() and not String(class_id).strip_edges().is_empty() and not class_label.is_empty() and final_level > 0

func copy() -> RunResultPartyMemberProjection:
	return create(member_id, display_name, class_id, class_label, is_leader, final_level)
