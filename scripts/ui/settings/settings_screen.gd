class_name SettingsScreen
extends CanvasLayer

signal settings_applied(settings: PartyForgeSettings)

var _store: PartyForgeSettingsStore
var _current_settings: PartyForgeSettings = PartyForgeSettings.new()
var _draft: PartyForgeSettings = PartyForgeSettings.new()
var _return_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_notice().text = "Run-affecting changes apply when the next run starts."
	_connect_additional_actions()


func configure(store: PartyForgeSettingsStore, settings: PartyForgeSettings) -> void:
	_store = store
	_current_settings = settings.copy() if settings != null else PartyForgeSettings.new()
	_draft = _current_settings.copy()


func open(return_focus: Control = null) -> void:
	_return_focus = return_focus
	_draft = _current_settings.copy()
	_additional_page().bind(_draft)
	_status().text = ""
	visible = true
	_focus_active_page()


func close() -> void:
	visible = false
	if _return_focus != null and is_instance_valid(_return_focus) and _return_focus.is_inside_tree() and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null


func is_open() -> bool:
	return visible


func current_settings() -> PartyForgeSettings:
	return _current_settings.copy()


func _apply_and_return() -> void:
	_additional_page().write_to(_draft)
	_draft.normalize()
	var error := _store.save_settings(_draft) if _store != null else "PARTY_FORGE_SETTINGS_SAVE_ERROR reason=store is missing"
	if not error.is_empty():
		_status().text = error
		return
	_current_settings = _draft.copy()
	settings_applied.emit(_current_settings.copy())
	close()


func _cancel() -> void:
	close()


func _reset_developer_options() -> void:
	_additional_page().reset_developer_options()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		_mark_input_handled()
		return
	if event.is_action_pressed(&"settings_previous_tab"):
		_cycle_tab(-1)
		_mark_input_handled()
		return
	if event.is_action_pressed(&"settings_next_tab"):
		_cycle_tab(1)
		_mark_input_handled()


func _cycle_tab(direction: int) -> void:
	var tabs := _tabs()
	if tabs.get_tab_count() == 0:
		return
	tabs.current_tab = posmod(tabs.current_tab + direction, tabs.get_tab_count())
	_focus_active_page()


func _focus_active_page() -> void:
	var tabs := _tabs()
	if not is_inside_tree() or tabs.get_tab_count() == 0:
		return
	var page := tabs.get_tab_control(tabs.current_tab)
	var state := page.get_node_or_null("Content/State") as Control if page != null else null
	if state != null and state.is_visible_in_tree():
		state.grab_focus()
	else:
		tabs.get_tab_bar().grab_focus()


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _connect_additional_actions() -> void:
	var page := _additional_page()
	var apply := page.get_node("Layout/ApplyAndReturn") as Button
	var cancel := page.get_node("Layout/Cancel") as Button
	var reset := page.get_node("Layout/ResetDeveloperOptions") as Button
	if not apply.pressed.is_connected(_apply_and_return):
		apply.pressed.connect(_apply_and_return)
	if not cancel.pressed.is_connected(_cancel):
		cancel.pressed.connect(_cancel)
	if not reset.pressed.is_connected(_reset_developer_options):
		reset.pressed.connect(_reset_developer_options)


func _tabs() -> TabContainer:
	return get_node("Overlay/Frame/Layout/Tabs") as TabContainer


func _notice() -> Label:
	return get_node("Overlay/Frame/Layout/NextRunNotice") as Label


func _status() -> Label:
	return get_node("Overlay/Frame/Layout/Status") as Label


func _additional_page() -> AdditionalSettingsPage:
	return get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage
