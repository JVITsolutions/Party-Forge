class_name UpgradeCard
extends Button

signal activated(choice: UpgradeChoice)
signal detail_requested(choice: UpgradeChoice, anchor: Control)
signal detail_dismissed(choice: UpgradeChoice)

var _choice: UpgradeChoice
var _mouse_inside := false
var _focus_inside := false
var _detail_visible := false


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not focus_entered.is_connected(_on_focus_entered):
		focus_entered.connect(_on_focus_entered)
	if not focus_exited.is_connected(_on_focus_exited):
		focus_exited.connect(_on_focus_exited)


func bind_choice(
	choice: UpgradeChoice,
	presentation: Dictionary,
	disabled_reason: String = ""
) -> void:
	_choice = choice
	_set_text("Content/Name", presentation.get("name", ""))
	_set_text("Content/Scope", presentation.get("scope_badge", ""))
	_set_text("Content/Rank", presentation.get("rank_text", ""))
	_set_text("Content/Summary", presentation.get("summary", ""))
	_set_text("Content/Eligibility", presentation.get("eligibility_text", ""))
	_set_text("Content/Recipient", presentation.get("recipient_text", ""))
	_set_text("Content/Inheritance", presentation.get("inheritance_text", ""))
	_set_text("Content/DisabledReason", disabled_reason)
	var disabled_label := get_node_or_null("Content/DisabledReason") as Label
	if disabled_label != null:
		disabled_label.visible = not disabled_reason.is_empty()
	disabled = not disabled_reason.is_empty()


func bind_preview(presentation: Dictionary) -> void:
	_set_text("Content/Name", presentation.get("name", ""))
	_set_text("Content/Scope", presentation.get("scope_badge", ""))
	_set_text("Content/Rank", presentation.get("rank_text", ""))
	_set_text("Content/Summary", presentation.get("summary", ""))


func bound_choice() -> UpgradeChoice:
	return _choice


func _set_text(path: NodePath, value: Variant) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = str(value)


func _on_pressed() -> void:
	if not disabled and _choice != null:
		activated.emit(_choice)


func _on_mouse_entered() -> void:
	_mouse_inside = true
	_update_detail_state()


func _on_mouse_exited() -> void:
	_mouse_inside = false
	_update_detail_state()


func _on_focus_entered() -> void:
	_focus_inside = true
	_update_detail_state()


func _on_focus_exited() -> void:
	_focus_inside = false
	_update_detail_state()


func _update_detail_state() -> void:
	var should_show := (_mouse_inside or _focus_inside) and _choice != null
	if should_show == _detail_visible:
		return
	_detail_visible = should_show
	if _detail_visible:
		detail_requested.emit(_choice, self)
	else:
		detail_dismissed.emit(_choice)
