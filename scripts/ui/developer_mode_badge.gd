class_name DeveloperModeBadge
extends CanvasLayer

var _summary := ""
var _diagnostics := ""
var _show_ground_chest_diagnostics := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_label()


func configure(snapshot: RunRulesSnapshot, reward_tuning: RewardDistributionTuning = null) -> void:
	_summary = ""
	_diagnostics = ""
	_show_ground_chest_diagnostics = false
	if snapshot == null or not snapshot.developer_mode_active():
		visible = false
		_sync_label()
		return
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
	return _diagnostics


func update_ground_chest_diagnostics(diagnostics: Dictionary) -> void:
	_diagnostics = ""
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
	_diagnostics = "\n".join(lines)
	_sync_label()


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
		label.text = _summary if _diagnostics.is_empty() else "%s\n%s" % [_summary, _diagnostics]
