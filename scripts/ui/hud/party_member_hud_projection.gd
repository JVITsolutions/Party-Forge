class_name PartyMemberHudProjection
extends RefCounted

var member_id: int
var display_name: String
var class_id: StringName
var class_label: String
var level: int
var rank: int
var health: float
var max_health: float
var is_leader: bool
var is_downed: bool
var is_dead: bool


static func create(member_id_value: int, display_name_value: String, class_id_value: StringName, class_name_value: String, level_value: int, rank_value: int, health_value: float, max_health_value: float, is_leader_value: bool, is_downed_value: bool, is_dead_value: bool) -> PartyMemberHudProjection:
	var result := PartyMemberHudProjection.new()
	result.member_id = member_id_value
	result.display_name = display_name_value
	result.class_id = class_id_value
	result.class_label = class_name_value
	result.level = level_value
	result.rank = rank_value
	result.health = health_value
	result.max_health = max_health_value
	result.is_leader = is_leader_value
	result.is_downed = is_downed_value
	result.is_dead = is_dead_value
	return result if result.validate().is_empty() else null


func copy() -> PartyMemberHudProjection:
	return create(member_id, display_name, class_id, class_label, level, rank, health, max_health, is_leader, is_downed, is_dead)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if member_id <= 0:
		errors.append(_error("member_id", "must be positive"))
	if display_name.strip_edges().is_empty():
		errors.append(_error("display_name", "must not be empty"))
	if class_id.is_empty():
		errors.append(_error("class_id", "must not be empty"))
	if class_label.strip_edges().is_empty():
		errors.append(_error("class_label", "must not be empty"))
	if level <= 0:
		errors.append(_error("level", "must be positive"))
	if rank <= 0:
		errors.append(_error("rank", "must be positive"))
	if not is_finite(health) or health < 0.0:
		errors.append(_error("health", "must be finite and nonnegative"))
	if not is_finite(max_health) or max_health <= 0.0:
		errors.append(_error("max_health", "must be finite and positive"))
	elif health > max_health:
		errors.append(_error("health", "must not exceed max_health"))
	return errors


func _error(field: String, reason: String) -> String:
	return "PARTY_MEMBER_HUD_PROJECTION_ERROR field=%s reason=%s" % [field, reason]
