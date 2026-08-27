class_name ProfilesSettingsPage
extends MarginContainer

const PlayerColorPalette := preload("res://scripts/profile/player_color_palette.gd")

signal profile_action_failed(message: String)
signal profile_deletion_state_changed(in_progress: bool)

var _manager: ProfileManager
var _status_by_id: Dictionary = {}
var _run_active_query: Callable
var _pending_delete_profile_id := ""
var _bootstrap_safe_status := ""
var _bootstrap_technical_detail := ""
var _action_error_active := false
var _action_error_primary := ""
var _action_error_technical := ""


func _ready() -> void:
	_populate_preferred_colors()
	if not _create_button().pressed.is_connected(_create_profile):
		_create_button().pressed.connect(_create_profile)
	if not _activate_button().pressed.is_connected(_activate_profile):
		_activate_button().pressed.connect(_activate_profile)
	if not _delete_button().pressed.is_connected(_request_delete):
		_delete_button().pressed.connect(_request_delete)
	if not _profile_name().text_submitted.is_connected(_on_name_submitted):
		_profile_name().text_submitted.connect(_on_name_submitted)
	if not _profile_list().item_selected.is_connected(_on_item_selected):
		_profile_list().item_selected.connect(_on_item_selected)
	if not _profile_list().item_activated.is_connected(_on_item_activated):
		_profile_list().item_activated.connect(_on_item_activated)
	if not _delete_confirmation().confirmed.is_connected(_confirm_delete):
		_delete_confirmation().confirmed.connect(_confirm_delete)
	if not _delete_confirmation().canceled.is_connected(_cancel_delete):
		_delete_confirmation().canceled.connect(_cancel_delete)
	if not _delete_confirmation().close_requested.is_connected(_cancel_delete):
		_delete_confirmation().close_requested.connect(_cancel_delete)
	if not _delete_confirmation().visibility_changed.is_connected(_on_delete_confirmation_visibility_changed):
		_delete_confirmation().visibility_changed.connect(_on_delete_confirmation_visibility_changed)
	refresh()


func bind(manager: ProfileManager, run_active_query: Callable = Callable()) -> void:
	_disconnect_manager()
	_manager = manager
	_run_active_query = run_active_query
	if _manager != null:
		if not _manager.profiles_changed.is_connected(refresh):
			_manager.profiles_changed.connect(refresh)
		if not _manager.active_profile_changed.is_connected(_on_active_profile_changed):
			_manager.active_profile_changed.connect(_on_active_profile_changed)
	refresh()


func set_run_active_query(query: Callable) -> void:
	_run_active_query = query
	_refresh_action_eligibility()


func refresh() -> void:
	var list := _profile_list()
	var previous_selected_id := _selected_profile_id()
	list.clear()
	_status_by_id.clear()
	var statuses: Array[ProfileEntryStatus] = []
	if _manager != null:
		statuses = _manager.profile_statuses()
	var active := _manager.active_profile() if _manager != null else null
	var profiles_by_id: Dictionary = {}
	if _manager != null:
		for profile: ProfileState in _manager.profiles():
			profiles_by_id[profile.profile_id] = profile
	var index_by_id: Dictionary = {}
	for status: ProfileEntryStatus in statuses:
		_status_by_id[status.profile_id] = status
		var is_active := active != null and active.profile_id == status.profile_id
		var suffix := ""
		var profile := profiles_by_id.get(status.profile_id) as ProfileState
		if profile != null and status.selectable():
			suffix += "  [Color: %s]" % String(profile.preferred_player_color_id).capitalize()
		if is_active:
			suffix += "  [Active]"
		if status.state == ProfileEntryStatus.State.RECOVERED:
			suffix += "  [Recovered]"
		elif status.state == ProfileEntryStatus.State.DAMAGED:
			suffix += "  [Damaged]"
		var index := list.add_item("%s%s" % [status.display_name, suffix])
		list.set_item_metadata(index, status.profile_id)
		list.set_item_disabled(index, false)
		index_by_id[status.profile_id] = index
	var preferred_selection := previous_selected_id
	if preferred_selection.is_empty() or not index_by_id.has(preferred_selection):
		preferred_selection = active.profile_id if active != null else ""
	if index_by_id.has(preferred_selection):
		list.select(int(index_by_id[preferred_selection]))
	_empty_state().visible = statuses.is_empty()
	list.visible = not statuses.is_empty()
	_refresh_action_eligibility()
	_configure_focus_order(not statuses.is_empty())
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
	if list.visible and list.item_count > 0:
		return list
	return _profile_name()


func _create_profile() -> void:
	if _manager == null:
		_show_error("Profile service is unavailable.", "PROFILE_UI_ERROR reason=manager is missing")
		return
	var result := _manager.create_profile(_profile_name().text, -1, _selected_preferred_color_id())
	if not result.ok():
		_show_error(_friendly_error(result.error), result.error)
		return
	_profile_name().clear()
	_clear_error()
	refresh()


func _activate_profile() -> void:
	if _manager == null:
		_show_error("Profile service is unavailable.", "PROFILE_UI_ERROR reason=manager is missing")
		return
	var status := _selected_status()
	if status == null:
		_show_error("Choose a profile first.", "PROFILE_UI_ERROR reason=no profile selected")
		return
	if not status.selectable():
		_show_error("This profile cannot be activated until it is recovered.", status.error)
		_refresh_action_eligibility()
		return
	var error := _manager.select_profile(status.profile_id)
	if not error.is_empty():
		_show_error(_friendly_error(error), error)
		return
	_clear_error()
	refresh()


func _on_name_submitted(_submitted_name: String) -> void:
	_create_profile()


func _on_item_selected(_index: int) -> void:
	_refresh_action_eligibility()


func _on_item_activated(_index: int) -> void:
	_activate_profile()


func _request_delete() -> void:
	_refresh_action_eligibility()
	var status := _selected_status()
	if status == null or _run_is_active():
		return
	_pending_delete_profile_id = status.profile_id
	_delete_confirmation().dialog_text = (
		"Permanently delete %s? This cannot be undone. Any resumable run and all run-owned items will also be discarded."
		% status.display_name
	)
	if _delete_confirmation().is_inside_tree():
		_delete_confirmation().popup_centered()


func _confirm_delete() -> void:
	var profile_id := _pending_delete_profile_id
	_pending_delete_profile_id = ""
	if _manager == null:
		_show_error("Profile service is unavailable.", "PROFILE_UI_ERROR reason=manager is missing")
		_focus_delete_button()
		return
	if profile_id.is_empty():
		_show_error("Choose a profile first.", "PROFILE_UI_ERROR reason=no profile selected for deletion")
		_focus_delete_button()
		return
	if _run_is_active():
		_show_error("Profiles cannot be deleted while an arena run is active.", "PROFILE_DELETE_BLOCKED reason=active run")
		_refresh_action_eligibility()
		if _profile_list().is_inside_tree() and _profile_list().is_visible_in_tree():
			_profile_list().grab_focus()
		return
	profile_deletion_state_changed.emit(true)
	var result := _manager.delete_profile(profile_id)
	if not result.committed:
		_show_error(_friendly_error(result.error), result.error)
		_refresh_action_eligibility()
		_focus_delete_button()
		profile_deletion_state_changed.emit(false)
		return
	if result.cleanup_debt:
		_show_error("The profile was deleted, but some cleanup could not be completed safely.", result.error)
	else:
		_clear_error()
	refresh()
	_focus_after_committed_deletion(result.next_active_profile_id)
	profile_deletion_state_changed.emit(false)


func _cancel_delete() -> void:
	_pending_delete_profile_id = ""
	_refresh_action_eligibility()
	_focus_delete_button()


func _on_delete_confirmation_visibility_changed() -> void:
	if not _delete_confirmation().visible:
		_refresh_action_eligibility()


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
	order.append_array([_profile_name(), _preferred_color(), _create_button()])
	if has_profiles:
		order.append_array([_activate_button(), _delete_button()])
	for index: int in range(order.size()):
		var control := order[index]
		var next := order[(index + 1) % order.size()]
		var previous := order[posmod(index - 1, order.size())]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_next = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)


func _selected_status() -> ProfileEntryStatus:
	var selected := _profile_list().get_selected_items()
	if selected.is_empty():
		return null
	return _status_by_id.get(String(_profile_list().get_item_metadata(selected[0]))) as ProfileEntryStatus


func _selected_profile_id() -> String:
	var selected := _profile_list().get_selected_items()
	if selected.is_empty():
		return ""
	return String(_profile_list().get_item_metadata(selected[0]))


func _refresh_action_eligibility() -> void:
	var status := _selected_status()
	_activate_button().disabled = status == null or not status.selectable()
	_delete_button().disabled = status == null or _run_is_active()


func _run_is_active() -> bool:
	return _run_active_query.is_valid() and bool(_run_active_query.call())


func _focus_after_committed_deletion(next_active_profile_id: String) -> void:
	var list := _profile_list()
	if list.item_count == 0:
		if _profile_name().is_inside_tree() and _profile_name().is_visible_in_tree():
			_profile_name().grab_focus()
		return
	var target_index := -1
	for index: int in range(list.item_count):
		if String(list.get_item_metadata(index)) == next_active_profile_id:
			target_index = index
			break
	if target_index < 0:
		var selected := list.get_selected_items()
		target_index = selected[0] if not selected.is_empty() else 0
	list.select(target_index)
	_refresh_action_eligibility()
	if list.is_inside_tree() and list.is_visible_in_tree():
		list.grab_focus()


func _focus_delete_button() -> void:
	var delete := _delete_button()
	if delete.is_inside_tree() and delete.is_visible_in_tree() and delete.focus_mode != Control.FOCUS_NONE:
		delete.grab_focus()


func _profile_list() -> ItemList:
	return get_node("Layout/ProfileList") as ItemList


func _profile_name() -> LineEdit:
	return get_node("Layout/CreateRow/ProfileName") as LineEdit


func _preferred_color() -> OptionButton:
	return get_node("Layout/CreateRow/PreferredColor") as OptionButton


func _populate_preferred_colors() -> void:
	var selector := _preferred_color()
	selector.clear()
	for entry: Dictionary in PlayerColorPalette.entries():
		var index := selector.item_count
		selector.add_item(String(entry["label"]))
		selector.set_item_metadata(index, entry["id"])
		selector.set_item_tooltip(index, "%s player marker" % entry["label"])
	selector.select(PlayerColorPalette.ORDER.find(PlayerColorPalette.DEFAULT_ID))


func _selected_preferred_color_id() -> StringName:
	var selector := _preferred_color()
	if selector.selected < 0:
		return PlayerColorPalette.DEFAULT_ID
	return StringName(selector.get_item_metadata(selector.selected))


func _create_button() -> Button:
	return get_node("Layout/CreateRow/Create") as Button


func _activate_button() -> Button:
	return get_node("Layout/Activate") as Button


func _delete_button() -> Button:
	return get_node("Layout/DeleteProfile") as Button


func _delete_confirmation() -> ConfirmationDialog:
	return get_node("DeleteConfirmation") as ConfirmationDialog


func _empty_state() -> Label:
	return get_node("Layout/EmptyState") as Label


func _status() -> Label:
	return get_node("Layout/Status") as Label

func _technical_details() -> Label:
	return get_node("Layout/TechnicalDetails") as Label
