class_name DeveloperModeBadge
extends CanvasLayer

var _summary := ""
var _ground_chest_diagnostics := ""
var _combat_diagnostics := ""
var _developer_mode_active := false
var _show_ground_chest_diagnostics := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_label()


func configure(snapshot: RunRulesSnapshot, reward_tuning: RewardDistributionTuning = null) -> void:
	_summary = ""
	_ground_chest_diagnostics = ""
	_combat_diagnostics = ""
	_developer_mode_active = false
	_show_ground_chest_diagnostics = false
	if snapshot == null or not snapshot.developer_mode_active():
		visible = false
		_sync_label()
		return
	_developer_mode_active = true
	var parts := PackedStringArray(["DEV MODE"])
	_show_ground_chest_diagnostics = snapshot.show_ground_chest_diagnostics()
	parts.append_array(snapshot.combat_policy().summary_parts())
	if snapshot.experience_multiplier_percent() != 100:
		parts.append("XP %d%%" % snapshot.experience_multiplier_percent())
	if snapshot.level_up_card_count() != 5:
		parts.append("CARDS %d" % snapshot.level_up_card_count())
	if snapshot.personal_drop_multiplier_percent() != 100:
		parts.append("DROPS %d%%" % snapshot.personal_drop_multiplier_percent())
	if snapshot.force_personal_drops():
		parts.append("FORCE DROPS")
	if not snapshot.personal_drop_source_category_override().is_empty():
		parts.append("SOURCE %s" % String(snapshot.personal_drop_source_category_override()).replace("_", " ").to_upper())
	if snapshot.personal_drop_item_level_override() > 0:
		parts.append("ITEM LEVEL %d" % snapshot.personal_drop_item_level_override())
	if reward_tuning != null and reward_tuning.validate().is_empty():
		parts.append("XP SHARE %.1fm" % reward_tuning.leader_event_share_radius)
		parts.append("SQUAD LINK %.1fm" % reward_tuning.follower_squad_link_radius)
	_summary = " | ".join(parts)
	visible = true
	_sync_label()


func summary_text() -> String:
	return _summary


func diagnostics_text() -> String:
	return _composed_diagnostics()


func update_ground_chest_diagnostics(diagnostics: Dictionary) -> void:
	_ground_chest_diagnostics = ""
	if not _show_ground_chest_diagnostics or diagnostics.is_empty():
		_sync_label()
		return
	var lines := PackedStringArray([
		"SESSION LOOT DIAGNOSTICS",
		"LIVE %d | PEAK %d" % [int(diagnostics.get("live", 0)), int(diagnostics.get("peak", 0))],
		"ROLL SUCCESS %s" % _counts_text(diagnostics.get("successes_by_source", {}) as Dictionary),
		"ROLL MISS %s" % _counts_text(diagnostics.get("misses_by_source", {}) as Dictionary),
		"INELIGIBLE %d | REASONS %s | SOURCES %s" % [int(diagnostics.get("ineligible_total", 0)), _counts_text(diagnostics.get("ineligible_by_reason", {}) as Dictionary), _counts_text(diagnostics.get("ineligible_by_source", {}) as Dictionary)],
		"GENERATION FAILURES %d" % int(diagnostics.get("generation_failures", 0)),
		"DIAGNOSTIC STAGES %s" % _counts_text(diagnostics.get("diagnostics_by_stage", {}) as Dictionary),
		"DIAGNOSTIC CODES %s" % _counts_text(diagnostics.get("diagnostics_by_code", {}) as Dictionary),
		"COLLECTION %s" % _counts_text(diagnostics.get("collection_outcomes", {}) as Dictionary),
		"PROJECTION pending=%d last=%d peak=%d limit=%d" % [int(diagnostics.get("projection_pending", 0)), int(diagnostics.get("projection_last_work", 0)), int(diagnostics.get("projection_peak_work", 0)), int(diagnostics.get("projection_limit", 0))],
	])
	_ground_chest_diagnostics = "\n".join(lines)
	_sync_label()


func update_combat_diagnostics(diagnostics: Dictionary) -> void:
	_combat_diagnostics = ""
	if not _developer_mode_active or diagnostics.is_empty():
		_sync_label()
		return
	var remainder_outcome := "NOT_ROLLED"
	if bool(diagnostics.get("fractional_draw_consumed", false)):
		remainder_outcome = "SUCCESS" if bool(diagnostics.get("fractional_success", false)) else "MISS"
	var lines := PackedStringArray([
		"COMBAT DIAGNOSTICS",
		"INSTANCES requested=%d processed=%d" % [int(diagnostics.get("requested_instances", 0)), int(diagnostics.get("processed_instances", 0))],
		"REMAINDER chance=%s draw=%s outcome=%s" % [
			_percent_text(float(diagnostics.get("fractional_chance", 0.0))),
			_percent_text(float(diagnostics.get("fractional_draw", -1.0))) if bool(diagnostics.get("fractional_draw_consumed", false)) else "not-consumed",
			remainder_outcome,
		],
		"OVERKILL %s" % _number_text(float(diagnostics.get("total_overkill", 0.0))),
	])
	if bool(diagnostics.get("ceiling_truncated", false)):
		lines.append("TRUNCATED")
	_combat_diagnostics = "\n".join(lines)
	_sync_label()


func _composed_diagnostics() -> String:
	var sections := PackedStringArray()
	if not _ground_chest_diagnostics.is_empty():
		sections.append(_ground_chest_diagnostics)
	if not _combat_diagnostics.is_empty():
		sections.append(_combat_diagnostics)
	return "\n".join(sections)


func _percent_text(value: float) -> String:
	return "%s%%" % _number_text(value * 100.0)


func _number_text(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")


func _counts_text(counts: Dictionary) -> String:
	var keys: Array[String] = []
	for value: Variant in counts:
		keys.append(String(value))
	keys.sort()
	var parts := PackedStringArray()
	for key: String in keys:
		parts.append("%s=%d" % [key, int(counts.get(key, counts.get(StringName(key), 0)))])
	return ",".join(parts) if not parts.is_empty() else "none"


func _sync_label() -> void:
	var label := get_node_or_null("Anchor/Margin/Label") as Label
	if label != null:
		var diagnostics := _composed_diagnostics()
		label.text = _summary if diagnostics.is_empty() else "%s\n%s" % [_summary, diagnostics]
