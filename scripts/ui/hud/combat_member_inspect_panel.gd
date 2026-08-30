class_name CombatMemberInspectPanel
extends CanvasLayer

signal closed(return_focus: Control, focus_descriptor: Dictionary)

var _pause_lease := RunPauseLease.new()
var _return_focus: WeakRef
var _return_descriptor: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var close_button := get_node("Overlay/Frame/Layout/Close") as Button
	if not close_button.pressed.is_connected(close):
		close_button.pressed.connect(close)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _pause_lease.is_active():
		_pause_lease.release(Engine.get_main_loop() as SceneTree)


func apply_visual_settings(theme_value: Theme) -> void:
	(get_node("Overlay") as Control).theme = theme_value


func open(member: PartyMemberHudProjection, return_focus: Control, focus_descriptor: Dictionary = {}) -> bool:
	if member == null or not member.validate().is_empty():
		return false
	_return_focus = weakref(return_focus) if return_focus != null else null
	_return_descriptor = focus_descriptor.duplicate(true)
	(get_node("Overlay/Frame/Layout/Identity") as Label).text = "%s · %s" % [member.display_name, member.class_label]
	(get_node("Overlay/Frame/Layout/Progression") as Label).text = "Level %d · Rank %d" % [member.level, member.rank]
	(get_node("Overlay/Frame/Layout/Health") as Label).text = "%s health · %s" % [_health_text(member), _state_text(member)]
	var overlay := get_node("Overlay") as Control
	overlay.accessibility_name = "Inspect %s" % member.display_name
	overlay.accessibility_description = "%s, %s, Level %d, Rank %d, %s health, %s. Read only." % [
		member.display_name,
		member.class_label,
		member.level,
		member.rank,
		_health_text(member),
		_state_text(member),
	]
	_pause_lease.acquire(Engine.get_main_loop() as SceneTree)
	visible = true
	var close_button := get_node("Overlay/Frame/Layout/Close") as Button
	if close_button.is_inside_tree():
		close_button.grab_focus()
	return true


func close() -> void:
	if not visible:
		return
	visible = false
	_pause_lease.release(Engine.get_main_loop() as SceneTree)
	var target := _return_focus.get_ref() as Control if _return_focus != null else null
	var descriptor := _return_descriptor.duplicate(true)
	_return_focus = null
	_return_descriptor.clear()
	if _focus_is_valid(target):
		target.grab_focus()
	closed.emit(target, descriptor)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _focus_is_valid(target: Control) -> bool:
	return (
		target != null
		and is_instance_valid(target)
		and target.is_inside_tree()
		and target.is_visible_in_tree()
		and target.focus_mode != Control.FOCUS_NONE
	)


func _health_text(member: PartyMemberHudProjection) -> String:
	return "%d of %d" % [roundi(member.health), roundi(member.max_health)]


func _state_text(member: PartyMemberHudProjection) -> String:
	if member.is_dead:
		return "Dead"
	if member.is_downed:
		return "Downed"
	if member.health / member.max_health <= CombatHudViewModel.CRITICAL_HEALTH_RATIO:
		return "Critical"
	return "Ready"
