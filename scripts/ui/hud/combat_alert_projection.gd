class_name CombatAlertProjection
extends RefCounted

enum Severity { CRITICAL, DOWNED, DEAD }

var stable_id: StringName
var member_id: int
var category: StringName
var summary: String
var detail: String
var severity: Severity
var can_inspect: bool
var can_open_ledger: bool


static func create(stable_id_value: StringName, member_id_value: int, category_value: StringName, summary_value: String, detail_value: String, severity_value: Severity, can_inspect_value: bool, can_open_ledger_value: bool) -> CombatAlertProjection:
	var result := CombatAlertProjection.new()
	result.stable_id = stable_id_value
	result.member_id = member_id_value
	result.category = category_value
	result.summary = summary_value
	result.detail = detail_value
	result.severity = severity_value
	result.can_inspect = can_inspect_value
	result.can_open_ledger = can_open_ledger_value
	return result if result.validate().is_empty() else null


func copy() -> CombatAlertProjection:
	return create(stable_id, member_id, category, summary, detail, severity, can_inspect, can_open_ledger)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if stable_id.is_empty():
		errors.append(_error("stable_id", "must not be empty"))
	if member_id <= 0:
		errors.append(_error("member_id", "must be positive"))
	if category.is_empty():
		errors.append(_error("category", "must not be empty"))
	if summary.strip_edges().is_empty():
		errors.append(_error("summary", "must not be empty"))
	if detail.strip_edges().is_empty():
		errors.append(_error("detail", "must not be empty"))
	if severity < Severity.CRITICAL or severity > Severity.DEAD:
		errors.append(_error("severity", "must be a supported severity"))
	return errors


func _error(field: String, reason: String) -> String:
	return "COMBAT_ALERT_PROJECTION_ERROR field=%s reason=%s" % [field, reason]
