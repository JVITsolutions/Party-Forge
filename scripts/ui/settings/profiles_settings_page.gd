class_name ProfilesSettingsPage
extends MarginContainer

signal profile_action_failed(message: String)

var _manager: ProfileManager
var _has_selectable_profiles := false
var _bootstrap_safe_status := ""
var _bootstrap_technical_detail := ""
var _action_error_active := false
var _action_error_primary := ""
var _action_error_technical := ""


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
	var statuses: Array[ProfileEntryStatus] = []
	if _manager != null:
		statuses = _manager.profile_statuses()
	var active := _manager.active_profile() if _manager != null else null
	_has_selectable_profiles = false
	for status: ProfileEntryStatus in statuses:
		var is_active := active != null and active.profile_id == status.profile_id
		var suffix := ""
		if is_active:
			suffix += "  [Active]"
		if status.state == ProfileEntryStatus.State.RECOVERED:
			suffix += "  [Recovered]"
		elif status.state == ProfileEntryStatus.State.DAMAGED:
			suffix += "  [Damaged]"
		var index := list.add_item("%s%s" % [status.display_name, suffix])
		list.set_item_metadata(index, status.profile_id)
		list.set_item_disabled(index, not status.selectable())
		_has_selectable_profiles = _has_selectable_profiles or status.selectable()
		if is_active:
			list.select(index)
	_empty_state().visible = statuses.is_empty()
	list.visible = not statuses.is_empty()
	_activate_button().disabled = not _has_selectable_profiles
	_configure_focus_order(_has_selectable_profiles)
	if _action_error_active:
		_render_action_error()
	else:
		_update_profile_health(statuses)


func set_bootstrap_diagnostic(safe_status: String, technical_detail: String) -> void:
	_bootstrap_safe_status = safe_status.strip_edges()
	_bootstrap_technical_detail = technical_detail.strip_edges()
	if _action_error_active:
		_render_action_error()
	else:
		_update_profile_health(_manager.profile_statuses() if _manager != null else [])


func initial_focus() -> Control:
	var list := _profile_list()
	if list.visible and list.item_count > 0 and _has_selectable_profiles:
		return list
	return _profile_name()


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
	_action_error_active = true
	_action_error_primary = primary
	_action_error_technical = technical
	_render_action_error()
	profile_action_failed.emit(technical)


func _clear_error() -> void:
	_action_error_active = false
	_action_error_primary = ""
	_action_error_technical = ""
	_update_profile_health(_manager.profile_statuses() if _manager != null else [])

func _update_profile_health(statuses: Array[ProfileEntryStatus]) -> void:
	var recovered_count := 0
	var damaged_count := 0
	var details: Array[String] = []
	for status: ProfileEntryStatus in statuses:
		if status.state == ProfileEntryStatus.State.RECOVERED:
			recovered_count += 1
		elif status.state == ProfileEntryStatus.State.DAMAGED:
			damaged_count += 1
		if not status.error.is_empty():
			details.append(status.error)
	var primary := ""
	if damaged_count > 0:
		primary = "%d damaged profile%s need recovery and cannot be activated." % [damaged_count, "s" if damaged_count != 1 else ""]
	if recovered_count > 0:
		var recovered_message := "%d profile%s recovered from a verified backup." % [recovered_count, "s" if recovered_count != 1 else ""]
		primary = "%s %s" % [primary, recovered_message] if not primary.is_empty() else recovered_message
	if not _bootstrap_safe_status.is_empty():
		primary = "%s %s" % [primary, _bootstrap_safe_status] if not primary.is_empty() else _bootstrap_safe_status
	var tooltip := " | ".join(details)
	if not _bootstrap_technical_detail.is_empty():
		if not details.has(_bootstrap_technical_detail):
			details.append(_bootstrap_technical_detail)
		var bootstrap_hint := "Additional technical details are available below."
		tooltip = "%s %s" % [tooltip, bootstrap_hint] if not tooltip.is_empty() else bootstrap_hint
	_status().text = primary
	_status().tooltip_text = tooltip
	_technical_details().text = "\n".join(details)
	_technical_details().visible = not details.is_empty()


func _render_action_error() -> void:
	_status().text = _action_error_primary
	_status().tooltip_text = _action_error_technical
	var details: Array[String] = []
	if not _action_error_technical.is_empty():
		details.append(_action_error_technical)
	if not _bootstrap_technical_detail.is_empty() and not details.has(_bootstrap_technical_detail):
		details.append(_bootstrap_technical_detail)
	_technical_details().text = "\n".join(details)
	_technical_details().visible = not details.is_empty()


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

func _technical_details() -> Label:
	return get_node("Layout/TechnicalDetails") as Label
