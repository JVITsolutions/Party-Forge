class_name RunPauseMenu
extends CanvasLayer

signal abandon_run_confirmed
signal retry_abandon_refresh_requested

const RETRY_RETURN_TO_FORGE_COPY := "Retry Return to Forge"

var run: GameRun
var ledger_open_provider: Callable
var _pause_lease := RunPauseLease.new()
var _abandon_emitted := false
var _abandon_committed := false
var _refresh_retry_pending := false
var _wired := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_wired()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _pause_lease != null and _pause_lease.is_active():
		_pause_lease.release(Engine.get_main_loop() as SceneTree)


func configure(game_run: GameRun, is_ledger_open: Callable) -> void:
	if _abandon_committed:
		return
	if visible or _pause_lease.is_active():
		close()
	run = game_run
	ledger_open_provider = is_ledger_open
	_abandon_emitted = false
	_refresh_retry_pending = false
	_ensure_wired()


func open() -> bool:
	if visible:
		return true
	if not _can_open():
		return false
	_abandon_emitted = false
	_title().text = "Paused"
	_confirmation().visible = false
	_committed_error().visible = false
	_main_panel().visible = true
	_set_main_controls_enabled(true)
	visible = true
	_pause_lease.acquire(Engine.get_main_loop() as SceneTree)
	_focus(_resume())
	return true


func close() -> void:
	if _abandon_committed:
		return
	_confirmation().visible = false
	visible = false
	_pause_lease.release(Engine.get_main_loop() as SceneTree)


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and _abandon_committed:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause_menu"):
			_mark_input_handled()
		return
	if visible and _confirmation().visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause_menu"):
			_cancel_abandon()
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
	_abandon_run().pressed.connect(_show_abandon_confirmation)
	_confirm().pressed.connect(_confirm_abandon)
	_cancel().pressed.connect(_cancel_abandon)
	_retry_return().pressed.connect(_retry_abandon_refresh)


func _show_settings_status() -> void:
	_title().text = "Settings: Coming Soon"


func _show_abandon_confirmation() -> void:
	if not visible or _abandon_committed:
		return
	_confirmation().visible = true
	_focus(_cancel())


func _cancel_abandon() -> void:
	_confirmation().visible = false
	_focus(_abandon_run())


func _confirm_abandon() -> void:
	if _abandon_emitted or _abandon_committed or not visible or not _confirmation().visible:
		return
	_abandon_emitted = true
	abandon_run_confirmed.emit()

func reject_abandon(reason: String) -> void:
	if _abandon_committed:
		return
	_abandon_emitted = false
	_confirmation().visible = false
	_title().text = reason.strip_edges() if not reason.strip_edges().is_empty() else "Unable to abandon this run."
	_focus(_abandon_run())

func present_abandon_committed_refresh_error(reason: String) -> void:
	_abandon_committed = true
	_abandon_emitted = true
	_refresh_retry_pending = false
	_confirmation().visible = false
	_main_panel().visible = false
	_set_main_controls_enabled(false)
	_committed_message().text = reason.strip_edges()
	_committed_error().visible = true
	visible = true
	_pause_lease.acquire(Engine.get_main_loop() as SceneTree)
	_retry_return().visible = true
	_retry_return().text = RETRY_RETURN_TO_FORGE_COPY
	_retry_return().disabled = false
	_retry_return().focus_mode = Control.FOCUS_ALL
	_focus(_retry_return())

func _retry_abandon_refresh() -> void:
	if not _abandon_committed or _refresh_retry_pending:
		return
	_refresh_retry_pending = true
	_retry_return().disabled = true
	retry_abandon_refresh_requested.emit()

func complete_abandon_return() -> void:
	_abandon_committed = false
	_refresh_retry_pending = false
	_committed_error().visible = false
	_main_panel().visible = true
	visible = false
	_pause_lease.release(Engine.get_main_loop() as SceneTree)

func _set_main_controls_enabled(enabled: bool) -> void:
	for button: Button in [_resume(), _settings(), _abandon_run(), _confirm(), _cancel()]:
		button.disabled = not enabled
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _focus(control: Control) -> void:
	if control != null and control.is_inside_tree():
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


func _abandon_run() -> Button:
	return get_node("Overlay/Panel/Content/AbandonRun") as Button


func _confirmation() -> Control:
	return get_node("Overlay/AbandonConfirmation") as Control


func _confirm() -> Button:
	return get_node("Overlay/AbandonConfirmation/Panel/Content/Confirm") as Button


func _cancel() -> Button:
	return get_node("Overlay/AbandonConfirmation/Panel/Content/Cancel") as Button

func _main_panel() -> Control:
	return get_node("Overlay/Panel") as Control

func _committed_error() -> Control:
	return get_node("Overlay/AbandonCommittedError") as Control

func _committed_message() -> Label:
	return get_node("Overlay/AbandonCommittedError/Panel/Content/Message") as Label

func _retry_return() -> Button:
	return get_node("Overlay/AbandonCommittedError/Panel/Content/RetryReturnToForge") as Button
