class_name SettingsScreen
extends CanvasLayer

signal settings_applied(settings: PartyForgeSettings)
signal city_tree_requested(developer_preview: bool)
signal item_sandbox_requested
signal profile_deletion_state_changed(in_progress: bool)

var _store: PartyForgeSettingsStore
var _current_settings: PartyForgeSettings = PartyForgeSettings.new()
var _draft: PartyForgeSettings = PartyForgeSettings.new()
var _profile_manager: ProfileManager
var _settings_path := PartyForgeSettingsStore.DEFAULT_PATH
var _return_focus: Control
var _child_return_focus: Control
var _child_resume_pending := false
var _pending_open := false
var _pending_profiles_tab := false


func _ready() -> void:
	var should_open := _pending_open
	var should_open_profiles := _pending_profiles_tab
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = should_open
	_notice().text = "Run-affecting changes apply when the next run starts."
	_connect_additional_actions()
	_connect_profile_actions()
	if not _technical_toggle().pressed.is_connected(_toggle_technical_details):
		_technical_toggle().pressed.connect(_toggle_technical_details)
	_clear_save_error_disclosure()
	_pending_open = false
	_pending_profiles_tab = false
	if should_open:
		if should_open_profiles:
			_select_tab_control(_profiles_page())
		call_deferred(&"_focus_active_page")


func configure(
	store: PartyForgeSettingsStore,
	settings: PartyForgeSettings,
	profile_manager: ProfileManager = null,
	settings_path: String = PartyForgeSettingsStore.DEFAULT_PATH,
	run_active_query: Callable = Callable(),
) -> void:
	_store = store
	_current_settings = settings.copy() if settings != null else PartyForgeSettings.new()
	_draft = _current_settings.copy()
	_profile_manager = profile_manager
	_settings_path = settings_path
	_profiles_page().bind(_profile_manager, run_active_query)


func open(return_focus: Control = null) -> void:
	_clear_child_resume_state()
	_return_focus = return_focus
	_draft = _current_settings.copy()
	_game_page().call(&"bind", _draft)
	_additional_page().bind(_draft)
	_status().text = ""
	_status().tooltip_text = ""
	_clear_save_error_disclosure()
	_profiles_page().refresh()
	visible = true
	if not is_inside_tree():
		_pending_open = true
		_pending_profiles_tab = false
		return
	_pending_open = false
	_focus_active_page()


func open_profiles(return_focus: Control = null) -> void:
	open(return_focus)
	if not is_inside_tree():
		_pending_profiles_tab = true
		return
	_pending_profiles_tab = false
	_select_tab_control(_profiles_page())
	_focus_active_page()


func open_additional(return_focus: Control = null) -> void:
	if _child_resume_pending:
		_resume_additional_from_child(return_focus)
		return
	open(return_focus)
	_select_tab_control(_additional_page())
	if not is_inside_tree():
		return
	_focus_active_page()


func _resume_additional_from_child(focus_target: Control) -> void:
	var external_return := _child_return_focus if _child_return_focus != null and is_instance_valid(_child_return_focus) else null
	_clear_child_resume_state()
	_return_focus = external_return
	visible = true
	_pending_open = false
	_pending_profiles_tab = false
	_select_tab_control(_additional_page())
	if not is_inside_tree():
		_pending_open = true
		return
	if focus_target != null and is_instance_valid(focus_target) and focus_target.is_inside_tree() and focus_target.is_visible_in_tree():
		focus_target.grab_focus()
	else:
		_focus_active_page()


func _tab_index_for_control(control: Control) -> int:
	var tabs := _tabs()
	for index: int in range(tabs.get_tab_count()):
		if tabs.get_tab_control(index) == control:
			return index
	return -1


func _select_tab_control(control: Control) -> void:
	var index := _tab_index_for_control(control)
	if index >= 0:
		var tabs := _tabs()
		tabs.set_current_tab(index)
		tabs.get_tab_bar().set_current_tab(index)


func close() -> void:
	var handled_return := _return_focus
	if handled_return == null and _child_resume_pending:
		handled_return = _child_return_focus
	visible = false
	_pending_open = false
	_pending_profiles_tab = false
	if is_inside_tree() and handled_return != null and is_instance_valid(handled_return) and handled_return.is_inside_tree() and handled_return.is_visible_in_tree():
		handled_return.grab_focus()
	_return_focus = null
	_clear_child_resume_state()


func is_open() -> bool:
	return visible


func current_settings() -> PartyForgeSettings:
	return _current_settings.copy()


func show_route_status(message: String, focus_target: Control = null) -> void:
	_status().text = message
	_status().tooltip_text = ""
	if is_inside_tree() and focus_target != null and is_instance_valid(focus_target) and focus_target.is_inside_tree() and focus_target.is_visible_in_tree() and focus_target.focus_mode != Control.FOCUS_NONE:
		focus_target.grab_focus()


func _apply_and_return() -> void:
	_game_page().call(&"write_to", _draft)
	_additional_page().write_to(_draft)
	_draft.normalize()
	var error := _store.save_settings(_draft, _settings_path) if _store != null else "PARTY_FORGE_SETTINGS_SAVE_ERROR reason=store is missing"
	if not error.is_empty():
		push_error(error)
		_status().text = "Settings could not be saved. Check that the settings folder is writable, then try again."
		_status().tooltip_text = error
		_technical_details().text = error
		_technical_toggle().visible = true
		if _technical_toggle().is_inside_tree() and _technical_toggle().is_visible_in_tree():
			_technical_toggle().grab_focus()
		return
	_current_settings = _draft.copy()
	_clear_save_error_disclosure()
	settings_applied.emit(_current_settings.copy())
	close()


func _cancel() -> void:
	close()


func _reset_developer_options() -> void:
	_additional_page().reset_developer_options()


func _toggle_technical_details() -> void:
	var details := _technical_details()
	details.visible = not details.visible
	_technical_toggle().text = "Hide technical details" if details.visible else "Show technical details"
	if not is_inside_tree():
		return
	if details.visible:
		details.grab_focus()
	else:
		_technical_toggle().grab_focus()


func _clear_save_error_disclosure() -> void:
	_technical_toggle().visible = false
	_technical_toggle().text = "Show technical details"
	_technical_details().visible = false
	_technical_details().text = ""


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
	var target := _focus_target_for_active_page()
	if target != null and target.focus_mode != Control.FOCUS_NONE and target.is_visible_in_tree():
		target.grab_focus()
	else:
		tabs.get_tab_bar().grab_focus()


func _focus_target_for_active_page() -> Control:
	var tabs := _tabs()
	if tabs.get_tab_count() == 0:
		return null
	var page := tabs.get_tab_control(tabs.current_tab)
	if page != null and page.has_method(&"initial_focus"):
		return page.call(&"initial_focus") as Control
	return page.get_node_or_null("Content/State") as Control if page != null else null


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _connect_additional_actions() -> void:
	var page := _additional_page()
	if not page.city_tree_requested.is_connected(_on_city_tree_requested):
		page.city_tree_requested.connect(_on_city_tree_requested)
	if not page.item_sandbox_requested.is_connected(_on_item_sandbox_requested):
		page.item_sandbox_requested.connect(_on_item_sandbox_requested)
	var apply := page.get_node("Layout/Actions/ApplyAndReturn") as Button
	var cancel := page.get_node("Layout/Actions/Cancel") as Button
	var reset := page.get_node("Layout/Actions/ResetDeveloperOptions") as Button
	if not apply.pressed.is_connected(_apply_and_return):
		apply.pressed.connect(_apply_and_return)
	if not cancel.pressed.is_connected(_cancel):
		cancel.pressed.connect(_cancel)
	if not reset.pressed.is_connected(_reset_developer_options):
		reset.pressed.connect(_reset_developer_options)


func _connect_profile_actions() -> void:
	var page := _profiles_page()
	if not page.profile_deletion_state_changed.is_connected(_on_profile_deletion_state_changed):
		page.profile_deletion_state_changed.connect(_on_profile_deletion_state_changed)


func _on_profile_deletion_state_changed(in_progress: bool) -> void:
	profile_deletion_state_changed.emit(in_progress)


func _on_city_tree_requested(developer_preview: bool) -> void:
	if not developer_preview:
		return
	_child_return_focus = _return_focus
	_child_resume_pending = true
	_return_focus = null
	visible = false
	city_tree_requested.emit(true)


func _on_item_sandbox_requested() -> void:
	_child_return_focus = _return_focus
	_child_resume_pending = true
	_return_focus = null
	visible = false
	item_sandbox_requested.emit()


func _clear_child_resume_state() -> void:
	_child_resume_pending = false
	_child_return_focus = null


func _tabs() -> TabContainer:
	return get_node("Overlay/Frame/Layout/Tabs") as TabContainer


func _notice() -> Label:
	return get_node("Overlay/Frame/Layout/NextRunNotice") as Label


func _status() -> Label:
	return get_node("Overlay/Frame/Layout/Status") as Label


func _technical_toggle() -> Button:
	return get_node("Overlay/Frame/Layout/ShowTechnicalDetails") as Button


func _technical_details() -> LineEdit:
	return get_node("Overlay/Frame/Layout/TechnicalDetails") as LineEdit


func _additional_page() -> AdditionalSettingsPage:
	return get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage


func _profiles_page() -> ProfilesSettingsPage:
	return get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage


func _game_page() -> Node:
	return get_node("Overlay/Frame/Layout/Tabs/Game Settings")
