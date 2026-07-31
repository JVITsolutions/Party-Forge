class_name RunPauseMenu
extends CanvasLayer

signal quit_run_confirmed

var run: GameRun
var ledger_open_provider: Callable
var _pause_lease := RunPauseLease.new()
var _quit_emitted := false
var _wired := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_wired()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _pause_lease != null and _pause_lease.is_active():
		_pause_lease.release(Engine.get_main_loop() as SceneTree)


func configure(game_run: GameRun, is_ledger_open: Callable) -> void:
	if visible or _pause_lease.is_active():
		close()
	run = game_run
	ledger_open_provider = is_ledger_open
	_quit_emitted = false
	_ensure_wired()


func open() -> bool:
	if visible:
		return true
	if not _can_open():
		return false
	_quit_emitted = false
	_title().text = "Paused"
	_confirmation().visible = false
	visible = true
	_pause_lease.acquire(Engine.get_main_loop() as SceneTree)
	_focus(_resume())
	return true


func close() -> void:
	_confirmation().visible = false
	visible = false
	_pause_lease.release(Engine.get_main_loop() as SceneTree)


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and _confirmation().visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause_menu"):
			_cancel_quit()
			_mark_input_handled()
		return
	if event.is_action_pressed(&"pause_menu"):
		if visible:
			close()
			_mark_input_handled()
		elif open():
			_mark_input_handled()
		return
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		_mark_input_handled()


func _can_open() -> bool:
	if run == null or not is_instance_valid(run):
		return false
	if ledger_open_provider.is_valid() and bool(ledger_open_provider.call()):
		return false
	return run.current_state() in [
		RunStateMachine.State.RUNNING,
		RunStateMachine.State.BOSS,
	]


func _ensure_wired() -> void:
	if _wired:
		return
	_wired = true
	var settings := _settings()
	settings.set_meta("coming_soon", true)
	_resume().pressed.connect(close)
	settings.pressed.connect(_show_settings_status)
	_quit_run().pressed.connect(_show_quit_confirmation)
	_confirm().pressed.connect(_confirm_quit)
	_cancel().pressed.connect(_cancel_quit)


func _show_settings_status() -> void:
	_title().text = "Settings: Coming Soon"


func _show_quit_confirmation() -> void:
	if not visible:
		return
	_confirmation().visible = true
	_focus(_cancel())


func _cancel_quit() -> void:
	_confirmation().visible = false
	_focus(_quit_run())


func _confirm_quit() -> void:
	if _quit_emitted or not visible or not _confirmation().visible:
		return
	_quit_emitted = true
	quit_run_confirmed.emit()


func _focus(control: Control) -> void:
	if control != null and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _title() -> Label:
	return get_node("Overlay/Panel/Content/Title") as Label


func _resume() -> Button:
	return get_node("Overlay/Panel/Content/Resume") as Button


func _settings() -> Button:
	return get_node("Overlay/Panel/Content/Settings") as Button


func _quit_run() -> Button:
	return get_node("Overlay/Panel/Content/QuitRun") as Button


func _confirmation() -> Control:
	return get_node("Overlay/QuitConfirmation") as Control


func _confirm() -> Button:
	return get_node("Overlay/QuitConfirmation/Panel/Content/Confirm") as Button


func _cancel() -> Button:
	return get_node("Overlay/QuitConfirmation/Panel/Content/Cancel") as Button
