class_name CombatHudProjection
extends RefCounted

const MAX_VISIBLE_ALERTS := 3

var _members: Array[PartyMemberHudProjection] = []
var _all_alerts: Array[CombatAlertProjection] = []

var elapsed_seconds: float
var experience: int
var experience_next: int
var boss_name: String
var boss_health: float
var boss_max_health: float

var members: Array[PartyMemberHudProjection]:
	get: return _member_copies(_members)
	set(_next): pass
var all_alerts: Array[CombatAlertProjection]:
	get: return _alert_copies(_all_alerts)
	set(_next): pass
var visible_alerts: Array[CombatAlertProjection]:
	get:
		var visible: Array[CombatAlertProjection] = []
		for index: int in range(mini(MAX_VISIBLE_ALERTS, _all_alerts.size())):
			var alert := _all_alerts[index]
			visible.append(alert.copy() if alert != null else null)
		return visible
	set(_next): pass
var overflow_alert_count: int:
	get: return maxi(0, _all_alerts.size() - MAX_VISIBLE_ALERTS)
	set(_next): pass


static func create(members_value: Array[PartyMemberHudProjection], all_alerts_value: Array[CombatAlertProjection], elapsed_seconds_value: float, experience_value: int, experience_next_value: int, boss_name_value: String, boss_health_value: float, boss_max_health_value: float) -> CombatHudProjection:
	var result := CombatHudProjection.new()
	result._members = _member_copies(members_value)
	result._all_alerts = _alert_copies(all_alerts_value)
	result.elapsed_seconds = elapsed_seconds_value
	result.experience = experience_value
	result.experience_next = experience_next_value
	result.boss_name = boss_name_value
	result.boss_health = boss_health_value
	result.boss_max_health = boss_max_health_value
	return result


func copy() -> CombatHudProjection:
	return create(_members, _all_alerts, elapsed_seconds, experience, experience_next, boss_name, boss_health, boss_max_health)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var member_ids: Dictionary = {}
	for member: PartyMemberHudProjection in _members:
		if member == null:
			errors.append(_error("members", "must not contain null"))
			continue
		for member_error: String in member.validate():
			errors.append(member_error)
		if member_ids.has(member.member_id):
			errors.append(_error("members", "duplicate member_id %d" % member.member_id))
		member_ids[member.member_id] = true
	var alert_ids: Dictionary = {}
	for alert: CombatAlertProjection in _all_alerts:
		if alert == null:
			errors.append(_error("all_alerts", "must not contain null"))
			continue
		for alert_error: String in alert.validate():
			errors.append(alert_error)
		if alert_ids.has(alert.stable_id):
			errors.append(_error("all_alerts", "duplicate alert stable_id %s" % alert.stable_id))
		alert_ids[alert.stable_id] = true
	if not is_finite(elapsed_seconds) or elapsed_seconds < 0.0:
		errors.append(_error("elapsed_seconds", "must be finite and nonnegative"))
	if experience < 0:
		errors.append(_error("experience", "must be nonnegative"))
	if experience_next < 0:
		errors.append(_error("experience_next", "must be nonnegative"))
	if experience > experience_next:
		errors.append(_error("experience", "must not exceed experience_next"))
	_validate_boss(errors)
	return errors


func _validate_boss(errors: PackedStringArray) -> void:
	if boss_name.strip_edges().is_empty():
		if boss_health != 0.0 or boss_max_health != 0.0:
			errors.append(_error("boss", "empty boss_name requires zero health values"))
		return
	if not is_finite(boss_max_health) or boss_max_health <= 0.0:
		errors.append(_error("boss_max_health", "must be finite and positive for a named boss"))
	if not is_finite(boss_health) or boss_health < 0.0:
		errors.append(_error("boss_health", "must be finite and nonnegative"))
	elif boss_health > boss_max_health:
		errors.append(_error("boss_health", "must not exceed boss_max_health"))


static func _member_copies(source: Array[PartyMemberHudProjection]) -> Array[PartyMemberHudProjection]:
	var copies: Array[PartyMemberHudProjection] = []
	for member: PartyMemberHudProjection in source:
		copies.append(member.copy() if member != null else null)
	return copies


static func _alert_copies(source: Array[CombatAlertProjection]) -> Array[CombatAlertProjection]:
	var copies: Array[CombatAlertProjection] = []
	for alert: CombatAlertProjection in source:
		copies.append(alert.copy() if alert != null else null)
	return copies


func _error(field: String, reason: String) -> String:
	return "COMBAT_HUD_PROJECTION_ERROR field=%s reason=%s" % [field, reason]
