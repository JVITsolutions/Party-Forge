class_name SettingsScreen
extends CanvasLayer

signal settings_applied(settings: PartyForgeSettings)

var _store: PartyForgeSettingsStore
var _draft: PartyForgeSettings = PartyForgeSettings.new()
var _return_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_notice().text = "Run-affecting changes apply when the next run starts."


func configure(store: PartyForgeSettingsStore, settings: PartyForgeSettings) -> void:
	_store = store
	_draft = settings.copy() if settings != null else PartyForgeSettings.new()


func open(return_focus: Control = null) -> void:
	_return_focus = return_focus
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
	return _draft.copy()


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


func _tabs() -> TabContainer:
	return get_node("Overlay/Frame/Layout/Tabs") as TabContainer


func _notice() -> Label:
	return get_node("Overlay/Frame/Layout/NextRunNotice") as Label
