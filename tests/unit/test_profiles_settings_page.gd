extends RefCounted

const SCENE_PATH := "res://scenes/ui/settings/profiles_settings_page.tscn"


class FailingProfileIndexStore extends ProfileIndexStore:
	var save_error := ""

	func save_index(index: ProfileIndex, root: String = ProfileStore.DEFAULT_ROOT) -> String:
		if not save_error.is_empty():
			return save_error
		return super.save_index(index, root)


class DeletionSpyProfileManager extends ProfileManager:
	var delete_calls: Array[String] = []
	var forced_delete_result: ProfileDeletionResult

	func delete_profile(profile_id: String) -> ProfileDeletionResult:
		delete_calls.append(profile_id)
		if forced_delete_result != null:
			return forced_delete_result
		return super.delete_profile(profile_id)


func run() -> Array[String]:
	var failures: Array[String] = []
	var root := "user://tests/profile_settings_page_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(root)
	_test_scene_and_interactions(root, failures)
	ProfileTestSupport.remove_tree(root)
	_test_deletion_confirmation_and_focus(root, failures)
	ProfileTestSupport.remove_tree(root)
	_test_cleanup_debt_presentation(root, failures)
	ProfileTestSupport.remove_tree(root)
	_test_invalid_preferred_color_rejected(root, failures)
	ProfileTestSupport.remove_tree(root)
	_test_errors_and_rebinding(root, failures)
	ProfileTestSupport.remove_tree(root)
	_test_profile_health_disclosure(root, failures)
	ProfileTestSupport.remove_tree(root)
	return failures


func _test_invalid_preferred_color_rejected(root: String, failures: Array[String]) -> void:
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return "profile-invalidcolor")
	TestAssertions.equal(manager.bootstrap(root), "", "invalid color fixture bootstraps", failures)
	var result := manager.create_profile("Invalid Color", 1000, &"chartreuse")
	TestAssertions.truthy(not result.ok() and result.error.contains("field=preferred_player_color_id"), "profile creation rejects an unsupported preferred color", failures)
	TestAssertions.truthy(manager.profiles().is_empty(), "rejected preferred color creates no profile", failures)


func _test_scene_and_interactions(root: String, failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(SCENE_PATH), "Profiles page scene exists", failures)
	if not ResourceLoader.exists(SCENE_PATH):
		return
	var ids: Array[String] = ["profile-aaaaaaaa", "profile-bbbbbbbb"]
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(root), "", "page fixture bootstraps", failures)
	var page := (load(SCENE_PATH) as PackedScene).instantiate() as ProfilesSettingsPage
	(Engine.get_main_loop() as SceneTree).root.add_child(page)
	page.call("_ready")
	page.bind(manager)
	var list := page.get_node("Layout/ProfileList") as ItemList
	var name := page.get_node("Layout/CreateRow/ProfileName") as LineEdit
	var color := page.get_node_or_null("Layout/CreateRow/PreferredColor") as OptionButton
	var create := page.get_node("Layout/CreateRow/Create") as Button
	var activate := page.get_node("Layout/Activate") as Button
	var delete := page.get_node_or_null("Layout/DeleteProfile") as Button
	var confirmation := page.get_node_or_null("DeleteConfirmation") as ConfirmationDialog
	var empty := page.get_node("Layout/EmptyState") as Label
	var status := page.get_node("Layout/Status") as Label
	var explanation := page.get_node("Layout/Explanation") as Label
	TestAssertions.equal(empty.text, "Create a profile to begin playing.", "empty copy is approved", failures)
	TestAssertions.truthy(empty.visible, "empty state begins visible", failures)
	TestAssertions.truthy(delete != null, "Profiles exposes Delete Selected Profile", failures)
	TestAssertions.truthy(confirmation != null, "Profiles exposes a deletion confirmation", failures)
	if delete != null:
		TestAssertions.equal(delete.text, "Delete Selected Profile", "delete action uses approved copy", failures)
		TestAssertions.truthy(delete.disabled, "delete is disabled without a selected row", failures)
	TestAssertions.equal(name.max_length, 32, "profile name is bounded", failures)
	TestAssertions.truthy(color != null, "profile creation exposes a preferred color selector", failures)
	if color != null:
		TestAssertions.equal(color.item_count, 8, "profile color selector exposes the bounded palette", failures)
		var color_ids: Array[StringName] = []
		for index: int in color.item_count:
			color_ids.append(StringName(color.get_item_metadata(index)))
		TestAssertions.equal(color_ids, [&"red", &"blue", &"yellow", &"green", &"purple", &"orange", &"cyan", &"white"], "profile color selector uses the fixed palette order", failures)
		color.select(1)
	TestAssertions.equal(page.initial_focus(), name, "empty page focuses name", failures)
	TestAssertions.truthy(explanation.text.contains("immediately"), "Profiles explains immediate persistence", failures)
	name.text = "Jacob"
	create.pressed.emit()
	TestAssertions.equal(list.item_count, 1, "create adds profile row", failures)
	TestAssertions.equal(manager.active_profile().display_name, "Jacob", "created profile becomes active", failures)
	TestAssertions.equal(manager.active_profile().get("preferred_player_color_id"), &"blue", "UI-created profile persists the selected preferred color", failures)
	TestAssertions.equal(page.initial_focus(), list, "populated page focuses list", failures)
	TestAssertions.truthy(list.get_item_text(0).contains("[Active]"), "active profile has a non-color state label", failures)
	TestAssertions.truthy(list.get_item_text(0).contains("Blue"), "healthy profile row shows its preferred color", failures)
	name.text = "Guest"
	name.text_submitted.emit(name.text)
	TestAssertions.equal(list.item_count, 2, "submit creates a second profile", failures)
	TestAssertions.equal(manager.active_profile().display_name, "Guest", "submitted profile becomes active", failures)
	var jacob_index := _index_for_id(list, "profile-aaaaaaaa")
	list.select(jacob_index)
	activate.pressed.emit()
	TestAssertions.equal(manager.active_profile().profile_id, "profile-aaaaaaaa", "Activate switches selected profile", failures)
	TestAssertions.equal(status.text, "", "successful activation clears status", failures)
	var reloaded := ProfileManager.new()
	TestAssertions.equal(reloaded.bootstrap(root), "", "created profiles reload", failures)
	TestAssertions.equal(reloaded.profiles().size(), 2, "both profiles persist", failures)
	TestAssertions.equal(reloaded.active_profile().profile_id, "profile-aaaaaaaa", "active selection persists", failures)
	var focus_controls: Array[Control] = [list, name, create, activate]
	if delete != null:
		focus_controls.append(delete)
	if color != null:
		focus_controls.insert(2, color)
	for control: Control in focus_controls:
		TestAssertions.truthy(control.focus_mode != Control.FOCUS_NONE, "%s is focusable" % control.name, failures)
		TestAssertions.truthy(not control.focus_next.is_empty() and not control.focus_previous.is_empty(), "%s has explicit focus neighbors" % control.name, failures)
		TestAssertions.truthy(not control.focus_neighbor_top.is_empty() and not control.focus_neighbor_bottom.is_empty(), "%s has controller focus neighbors" % control.name, failures)
	page.free()


func _test_deletion_confirmation_and_focus(root: String, failures: Array[String]) -> void:
	var page := (load(SCENE_PATH) as PackedScene).instantiate() as ProfilesSettingsPage
	(Engine.get_main_loop() as SceneTree).root.add_child(page)
	page.call("_ready")
	var delete := page.get_node_or_null("Layout/DeleteProfile") as Button
	var confirmation := page.get_node_or_null("DeleteConfirmation") as ConfirmationDialog
	var supports_run_query := page.has_method(&"set_run_active_query") and _method_argument_count(page, &"bind") == 2
	TestAssertions.truthy(delete != null and confirmation != null, "deletion controls are present for interaction coverage", failures)
	TestAssertions.truthy(supports_run_query, "Profiles bind accepts an explicit run-active query", failures)
	if delete == null or confirmation == null or not supports_run_query:
		page.free()
		return
	var ids: Array[String] = ["profile-deleteaa", "profile-deletebb"]
	var manager := DeletionSpyProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(root), "", "deletion UI fixture bootstraps", failures)
	TestAssertions.truthy(manager.create_profile("Alpha", 1000).ok(), "deletion UI creates first profile", failures)
	TestAssertions.truthy(manager.create_profile("Beta", 2000).ok(), "deletion UI creates active profile", failures)
	var run_active: Array[bool] = [false]
	page.call(&"bind", manager, func() -> bool: return run_active[0])
	var list := page.get_node("Layout/ProfileList") as ItemList
	var activate := page.get_node("Layout/Activate") as Button
	var name := page.get_node("Layout/CreateRow/ProfileName") as LineEdit
	var empty := page.get_node("Layout/EmptyState") as Label
	var status := page.get_node("Layout/Status") as Label
	var details := page.get_node("Layout/TechnicalDetails") as Label
	var deletion_states: Array[bool] = []
	page.profile_deletion_state_changed.connect(func(in_progress: bool) -> void: deletion_states.append(in_progress))
	var selected_index := _index_for_id(list, "profile-deletebb")
	list.select(selected_index)
	list.item_selected.emit(selected_index)
	TestAssertions.truthy(not delete.disabled, "healthy selected row is deletable", failures)
	TestAssertions.truthy(not activate.disabled, "healthy selected row remains activatable", failures)
	run_active[0] = true
	page.call(&"set_run_active_query", func() -> bool: return run_active[0])
	TestAssertions.truthy(delete.disabled, "active arena run disables deletion", failures)
	TestAssertions.truthy(not activate.disabled, "run state does not disable activation eligibility", failures)
	run_active[0] = false
	page.call(&"set_run_active_query", func() -> bool: return run_active[0])
	var profile_path := ProfileStore.new().profile_path("profile-deletebb", root)
	var index_path := root.path_join(ProfileIndexStore.FILE_NAME)
	var profile_before := FileAccess.get_file_as_bytes(profile_path)
	var profile_backup_before := FileAccess.get_file_as_bytes("%s.bak" % profile_path) if FileAccess.file_exists("%s.bak" % profile_path) else PackedByteArray()
	var index_before := FileAccess.get_file_as_bytes(index_path)
	var index_backup_before := FileAccess.get_file_as_bytes("%s.bak" % index_path) if FileAccess.file_exists("%s.bak" % index_path) else PackedByteArray()
	delete.pressed.emit()
	TestAssertions.truthy(confirmation.dialog_text.contains("Beta"), "confirmation names selected profile", failures)
	TestAssertions.truthy(confirmation.dialog_text.contains("resumable run and all run-owned items"), "confirmation warns about recovery loss", failures)
	confirmation.hide()
	confirmation.canceled.emit()
	TestAssertions.equal(manager.delete_calls.size(), 0, "cancel never calls profile deletion", failures)
	TestAssertions.equal(deletion_states, [], "cancel never enters deletion-in-progress state", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(profile_path), profile_before, "cancel preserves selected profile bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % profile_path) if FileAccess.file_exists("%s.bak" % profile_path) else PackedByteArray(), profile_backup_before, "cancel preserves selected profile backup bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(index_path), index_before, "cancel preserves profile index bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % index_path) if FileAccess.file_exists("%s.bak" % index_path) else PackedByteArray(), index_backup_before, "cancel preserves profile index backup bytes", failures)
	TestAssertions.equal(_selected_id(list), "profile-deletebb", "cancel preserves selected profile identity", failures)
	delete.pressed.emit()
	run_active[0] = true
	confirmation.hide()
	confirmation.confirmed.emit()
	TestAssertions.equal(manager.delete_calls.size(), 0, "a run that starts while confirmation is open blocks deletion", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(profile_path), profile_before, "commit-time run gating preserves selected profile bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(index_path), index_before, "commit-time run gating preserves profile index bytes", failures)
	TestAssertions.truthy(delete.disabled, "commit-time run gating refreshes the disabled delete action", failures)
	run_active[0] = false
	page.call(&"set_run_active_query", func() -> bool: return run_active[0])
	var failed := ProfileDeletionResult.new()
	failed.error = "PROFILE_DELETE_ERROR profile=profile-deletebb stage=remove code=30"
	manager.forced_delete_result = failed
	delete.pressed.emit()
	confirmation.hide()
	confirmation.confirmed.emit()
	TestAssertions.equal(manager.delete_calls, ["profile-deletebb"], "one confirmation calls deletion exactly once", failures)
	TestAssertions.equal(deletion_states, [true, false], "noncommitted deletion clears the in-progress state", failures)
	TestAssertions.equal(_selected_id(list), "profile-deletebb", "noncommitted deletion keeps the same selection", failures)
	TestAssertions.truthy(delete.focus_mode != Control.FOCUS_NONE, "noncommitted deletion retains a focusable Delete action", failures)
	TestAssertions.equal(status.text, "The profile action could not be completed.", "noncommitted deletion uses the friendly error channel", failures)
	TestAssertions.equal(details.text, failed.error, "noncommitted deletion preserves technical detail", failures)
	manager.forced_delete_result = null
	delete.pressed.emit()
	confirmation.hide()
	confirmation.confirmed.emit()
	TestAssertions.equal(manager.delete_calls, ["profile-deletebb", "profile-deletebb"], "second confirmation contributes one deletion call", failures)
	TestAssertions.equal(deletion_states, [true, false, true, false], "committed deletion clears the in-progress state", failures)
	TestAssertions.equal(_selected_id(list), "profile-deleteaa", "active deletion selects the replacement active row", failures)
	TestAssertions.truthy(list.focus_mode != Control.FOCUS_NONE, "active deletion retains a focusable replacement list", failures)
	delete.pressed.emit()
	confirmation.hide()
	confirmation.confirmed.emit()
	TestAssertions.equal(list.item_count, 0, "final deletion removes the final row", failures)
	TestAssertions.truthy(empty.visible, "final deletion shows the existing empty state", failures)
	TestAssertions.truthy(name.focus_mode != Control.FOCUS_NONE, "final deletion retains the focusable profile name field", failures)
	page.free()


func _test_cleanup_debt_presentation(root: String, failures: Array[String]) -> void:
	var page := (load(SCENE_PATH) as PackedScene).instantiate() as ProfilesSettingsPage
	(Engine.get_main_loop() as SceneTree).root.add_child(page)
	page.call("_ready")
	var delete := page.get_node_or_null("Layout/DeleteProfile") as Button
	var confirmation := page.get_node_or_null("DeleteConfirmation") as ConfirmationDialog
	if delete == null or confirmation == null or _method_argument_count(page, &"bind") != 2:
		page.free()
		return
	var index_store := FailingProfileIndexStore.new()
	var manager := DeletionSpyProfileManager.new(ProfileStore.new(), index_store, func() -> String: return "profile-cleanupui")
	TestAssertions.equal(manager.bootstrap(root), "", "cleanup-debt UI fixture bootstraps", failures)
	TestAssertions.truthy(manager.create_profile("Cleanup", 3000).ok(), "cleanup-debt UI creates profile", failures)
	page.call(&"bind", manager, Callable())
	var deletion_states: Array[bool] = []
	page.profile_deletion_state_changed.connect(func(in_progress: bool) -> void: deletion_states.append(in_progress))
	var list := page.get_node("Layout/ProfileList") as ItemList
	list.select(0)
	list.item_selected.emit(0)
	index_store.save_error = "PROFILE_INDEX_SAVE_ERROR path=profile_index.json stage=forced"
	delete.pressed.emit()
	confirmation.hide()
	confirmation.confirmed.emit()
	var status := page.get_node("Layout/Status") as Label
	var details := page.get_node("Layout/TechnicalDetails") as Label
	TestAssertions.equal(list.item_count, 0, "cleanup debt still refreshes the committed deletion", failures)
	TestAssertions.truthy(status.text.contains("deleted") and status.text.contains("cleanup"), "cleanup debt shows a safe committed-deletion warning", failures)
	TestAssertions.truthy(details.text.contains("PROFILE_DELETE_CLEANUP_DEBT") and details.text.contains(index_store.save_error), "cleanup debt preserves the technical result error", failures)
	TestAssertions.equal(deletion_states, [true, false], "cleanup debt clears the in-progress state", failures)
	page.free()


func _test_errors_and_rebinding(root: String, failures: Array[String]) -> void:
	var index_store := FailingProfileIndexStore.new()
	var ids: Array[String] = ["profile-error001", "profile-error002"]
	var manager := ProfileManager.new(ProfileStore.new(), index_store, func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(root), "", "error fixture bootstraps", failures)
	var page := (load(SCENE_PATH) as PackedScene).instantiate() as ProfilesSettingsPage
	(Engine.get_main_loop() as SceneTree).root.add_child(page)
	page.call("_ready")
	var list := page.get_node("Layout/ProfileList") as ItemList
	var name := page.get_node("Layout/CreateRow/ProfileName") as LineEdit
	var create := page.get_node("Layout/CreateRow/Create") as Button
	var activate := page.get_node("Layout/Activate") as Button
	var status := page.get_node("Layout/Status") as Label
	var errors: Array[String] = []
	page.profile_action_failed.connect(func(message: String) -> void: errors.append(message))
	page.bind(manager)
	page.bind(manager)
	TestAssertions.equal(manager.profiles_changed.get_connections().size(), 1, "rebinding does not duplicate profiles signal connections", failures)
	TestAssertions.equal(manager.active_profile_changed.get_connections().size(), 1, "rebinding does not duplicate active signal connections", failures)
	name.text = "   "
	create.pressed.emit()
	TestAssertions.truthy(status.text.contains("1 to 32"), "empty name is explained", failures)
	TestAssertions.truthy(not errors.is_empty() and errors.back().contains("1-32"), "empty name emits the technical diagnostic", failures)
	name.text = "Jacob"
	create.pressed.emit()
	name.text = " jacob "
	create.pressed.emit()
	TestAssertions.truthy(status.text.contains("already exists"), "duplicate name is explained", failures)
	TestAssertions.equal(list.item_count, 1, "duplicate name does not claim success", failures)
	index_store.save_error = "PROFILE_INDEX_SAVE_ERROR path=profile_index.json stage=forced"
	list.select(0)
	activate.pressed.emit()
	TestAssertions.equal(status.text, "The profile action could not be completed.", "selection persistence failure is friendly", failures)
	TestAssertions.equal(status.tooltip_text, index_store.save_error, "selection persistence failure preserves diagnostics", failures)
	TestAssertions.equal(errors.back(), index_store.save_error, "selection persistence failure emits diagnostics", failures)
	page.bind(null)
	TestAssertions.equal(manager.profiles_changed.get_connections().size(), 0, "null rebind disconnects the old profiles signal", failures)
	TestAssertions.equal(manager.active_profile_changed.get_connections().size(), 0, "null rebind disconnects the old active signal", failures)
	create.pressed.emit()
	TestAssertions.equal(status.text, "Profile service is unavailable.", "null manager has a friendly error", failures)
	TestAssertions.equal(list.item_count, 0, "null manager clears stale profiles", failures)
	page.free()

func _test_profile_health_disclosure(root: String, failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var healthy := ProfileState.new_profile("profile-uihealthy", "Healthy", 9000)
	var recovered := ProfileState.new_profile("profile-uirecover", "Recovered", 8000)
	TestAssertions.equal(store.save_profile(healthy, root), "", "health UI healthy fixture saves", failures)
	TestAssertions.equal(store.save_profile(recovered, root), "", "health UI recovered fixture first save succeeds", failures)
	recovered.updated_at_unix = 8001
	TestAssertions.equal(store.save_profile(recovered, root), "", "health UI recovered fixture creates backup", failures)
	_write_text(store.profile_path(recovered.profile_id, root), "corrupt recovered primary")
	_write_text(root.path_join("profile-uidamaged.json"), "corrupt without backup")
	var manager := ProfileManager.new()
	TestAssertions.truthy(not manager.bootstrap(root).is_empty(), "health UI fixture surfaces damaged bootstrap", failures)
	var page := (load(SCENE_PATH) as PackedScene).instantiate() as ProfilesSettingsPage
	(Engine.get_main_loop() as SceneTree).root.add_child(page)
	page.call("_ready")
	page.bind(manager)
	var list := page.get_node("Layout/ProfileList") as ItemList
	var activate := page.get_node("Layout/Activate") as Button
	var delete := page.get_node_or_null("Layout/DeleteProfile") as Button
	TestAssertions.equal(list.item_count, 3, "Profiles list visibly retains healthy recovered and damaged entries", failures)
	var recovered_index := _index_containing(list, "Recovered")
	var damaged_index := _index_containing(list, "profile-uidamaged")
	TestAssertions.truthy(recovered_index >= 0 and list.get_item_text(recovered_index).contains("[Recovered]"), "recovered profile is visibly labeled", failures)
	TestAssertions.truthy(damaged_index >= 0 and list.get_item_text(damaged_index).contains("[Damaged]"), "damaged profile is visibly labeled", failures)
	if recovered_index >= 0 and delete != null:
		list.select(recovered_index)
		list.item_selected.emit(recovered_index)
		TestAssertions.truthy(not delete.disabled, "recovered discovered row remains deletable", failures)
		TestAssertions.truthy(not activate.disabled, "recovered row remains eligible for activation", failures)
	if damaged_index >= 0:
		TestAssertions.truthy(not list.is_item_disabled(damaged_index), "damaged profile row remains selectable for deletion", failures)
		list.select(damaged_index)
		list.item_selected.emit(damaged_index)
		if delete != null:
			TestAssertions.truthy(not delete.disabled, "damaged discovered row remains deletable", failures)
		TestAssertions.truthy(activate.disabled, "damaged row remains ineligible for activation", failures)
	var has_details := page.has_node("Layout/TechnicalDetails")
	TestAssertions.truthy(has_details, "Profiles page exposes visible technical profile details", failures)
	var status := page.get_node("Layout/Status") as Label
	TestAssertions.truthy(status.text.contains("recovery") or status.text.contains("damaged"), "Profiles page explains recovery-required state", failures)
	if has_details:
		var details := page.get_node("Layout/TechnicalDetails") as Label
		TestAssertions.truthy(details.visible and details.text.contains("profile-uidamaged"), "Profiles page shows damaged profile technical details", failures)
	page.free()


func _index_for_id(list: ItemList, profile_id: String) -> int:
	for index: int in range(list.item_count):
		if str(list.get_item_metadata(index)) == profile_id:
			return index
	return -1

func _index_containing(list: ItemList, fragment: String) -> int:
	for index: int in range(list.item_count):
		if list.get_item_text(index).contains(fragment):
			return index
	return -1


func _selected_id(list: ItemList) -> String:
	var selected := list.get_selected_items()
	return "" if selected.is_empty() else str(list.get_item_metadata(selected[0]))


func _method_argument_count(object: Object, method_name: StringName) -> int:
	for method: Dictionary in object.get_method_list():
		if StringName(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return -1

func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
