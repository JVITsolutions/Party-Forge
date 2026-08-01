class_name DeveloperModeBadge
extends CanvasLayer

var _summary := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_label()


func configure(snapshot: RunRulesSnapshot) -> void:
	_summary = ""
	if snapshot == null or not snapshot.developer_mode_active():
		visible = false
		_sync_label()
		return
	var parts := PackedStringArray(["DEV MODE"])
	parts.append_array(snapshot.combat_policy().summary_parts())
	if snapshot.experience_multiplier_percent() != 100:
		parts.append("XP %d%%" % snapshot.experience_multiplier_percent())
	if snapshot.level_up_card_count() != 5:
		parts.append("CARDS %d" % snapshot.level_up_card_count())
	_summary = " | ".join(parts)
	visible = true
	_sync_label()


func summary_text() -> String:
	return _summary


func _sync_label() -> void:
	var label := get_node_or_null("Anchor/Margin/Label") as Label
	if label != null:
		label.text = _summary
