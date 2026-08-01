class_name ProfilesSettingsPage
extends MarginContainer

signal profile_action_failed(message: String)

var _manager: ProfileManager


func _ready() -> void:
	if not _create_button().pressed.is_connected(_create_profile):
		_create_button().pressed.connect(_create_profile)
	if not _activate_button().pressed.is_connected(_activate_profile):
		_activate_button().pressed.connect(_activate_profile)
	if not _profile_name().text_submitted.is_connected(_on_name_submitted):
		_profile_name().text_submitted.connect(_on_name_submitted)
	if not _profile_list().item_activated.is_connected(_on_item_activated):
		_profile_list().item_activated.connect(_on_item_activated)
	refresh()


func bind(manager: ProfileManager) -> void:
	_disconnect_manager()
	_manager = manager
	if _manager != null:
		if not _manager.profiles_changed.is_connected(refresh):
			_manager.profiles_changed.connect(refresh)
		if not _manager.active_profile_changed.is_connected(_on_active_profile_changed):
			_manager.active_profile_changed.connect(_on_active_profile_changed)
	refresh()


func refresh() -> void:
	var list := _profile_list()
	list.clear()
	var available: Array[ProfileState] = []
	if _manager != null:
		available = _manager.profiles()
	var active := _manager.active_profile() if _manager != null else null
	for profile: ProfileState in available:
		var is_active := active != null and active.profile_id == profile.profile_id
		var index := list.add_item("%s%s" % [profile.display_name, "  [Active]" if is_active else ""])
		list.set_item_metadata(index, profile.profile_id)
		if is_active:
			list.select(index)
	_empty_state().visible = available.is_empty()
	list.visible = not available.is_empty()
	_activate_button().disabled = available.is_empty()
	_configure_focus_order(not available.is_empty())


func initial_focus() -> Control:
	var list := _profile_list()
	return list if list.visible and list.item_count > 0 else _profile_name()


func _create_profile() -> void:
	if _manager == null:
		_show_error("Profile service is unavailable.", "PROFILE_UI_ERROR reason=manager is missing")
		return
	var result := _manager.create_profile(_profile_name().text)
	if not result.ok():
		_show_error(_friendly_error(result.error), result.error)
		return
	_profile_name().clear()
	_clear_error()
	refresh()


func _activate_profile() -> void:
	var selected := _profile_list().get_selected_items()
	if _manager == null:
		_show_error("Profile service is unavailable.", "PROFILE_UI_ERROR reason=manager is missing")
		return
	if selected.is_empty():
		_show_error("Choose a profile first.", "PROFILE_UI_ERROR reason=no profile selected")
		return
	var error := _manager.select_profile(str(_profile_list().get_item_metadata(selected[0])))
	if not error.is_empty():
		_show_error(_friendly_error(error), error)
		return
	_clear_error()
	refresh()


func _on_name_submitted(_submitted_name: String) -> void:
	_create_profile()


func _on_item_activated(_index: int) -> void:
	_activate_profile()


func _on_active_profile_changed(_profile: ProfileState) -> void:
	refresh()


func _disconnect_manager() -> void:
	if _manager == null:
		return
	if _manager.profiles_changed.is_connected(refresh):
		_manager.profiles_changed.disconnect(refresh)
	if _manager.active_profile_changed.is_connected(_on_active_profile_changed):
		_manager.active_profile_changed.disconnect(_on_active_profile_changed)


func _friendly_error(error: String) -> String:
	if error.contains("name already exists"):
		return "That profile name already exists. Choose another name."
	if error.contains("1-32"):
		return "Profile names must contain 1 to 32 characters."
	return "The profile action could not be completed."


func _show_error(primary: String, technical: String) -> void:
	_status().text = primary
	_status().tooltip_text = technical
	profile_action_failed.emit(technical)


func _clear_error() -> void:
	_status().text = ""
	_status().tooltip_text = ""


func _configure_focus_order(has_profiles: bool) -> void:
	var order: Array[Control] = []
	if has_profiles:
		order.append(_profile_list())
	order.append_array([_profile_name(), _create_button()])
	if has_profiles:
		order.append(_activate_button())
	for index: int in range(order.size()):
		var control := order[index]
		var next := order[(index + 1) % order.size()]
		var previous := order[posmod(index - 1, order.size())]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_next = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)


func _profile_list() -> ItemList:
	return get_node("Layout/ProfileList") as ItemList


func _profile_name() -> LineEdit:
	return get_node("Layout/CreateRow/ProfileName") as LineEdit


func _create_button() -> Button:
	return get_node("Layout/CreateRow/Create") as Button


func _activate_button() -> Button:
	return get_node("Layout/Activate") as Button


func _empty_state() -> Label:
	return get_node("Layout/EmptyState") as Label


func _status() -> Label:
	return get_node("Layout/Status") as Label
