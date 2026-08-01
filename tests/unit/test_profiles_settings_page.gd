extends RefCounted

const SCENE_PATH := "res://scenes/ui/settings/profiles_settings_page.tscn"


class FailingProfileIndexStore extends ProfileIndexStore:
	var save_error := ""

	func save_index(index: ProfileIndex, root: String = ProfileStore.DEFAULT_ROOT) -> String:
		if not save_error.is_empty():
			return save_error
		return super.save_index(index, root)


func run() -> Array[String]:
	var failures: Array[String] = []
	var root := "user://tests/profile_settings_page_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(root)
	_test_scene_and_interactions(root, failures)
	ProfileTestSupport.remove_tree(root)
	_test_errors_and_rebinding(root, failures)
	ProfileTestSupport.remove_tree(root)
	return failures


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
	var create := page.get_node("Layout/CreateRow/Create") as Button
	var activate := page.get_node("Layout/Activate") as Button
	var empty := page.get_node("Layout/EmptyState") as Label
	var status := page.get_node("Layout/Status") as Label
	var explanation := page.get_node("Layout/Explanation") as Label
	TestAssertions.equal(empty.text, "Create a profile to begin playing.", "empty copy is approved", failures)
	TestAssertions.truthy(empty.visible, "empty state begins visible", failures)
	TestAssertions.equal(name.max_length, 32, "profile name is bounded", failures)
	TestAssertions.equal(page.initial_focus(), name, "empty page focuses name", failures)
	TestAssertions.truthy(explanation.text.contains("immediately"), "Profiles explains immediate persistence", failures)
	name.text = "Jacob"
	create.pressed.emit()
	TestAssertions.equal(list.item_count, 1, "create adds profile row", failures)
	TestAssertions.equal(manager.active_profile().display_name, "Jacob", "created profile becomes active", failures)
	TestAssertions.equal(page.initial_focus(), list, "populated page focuses list", failures)
	TestAssertions.truthy(list.get_item_text(0).contains("[Active]"), "active profile has a non-color state label", failures)
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
	for control: Control in [list, name, create, activate]:
		TestAssertions.truthy(control.focus_mode != Control.FOCUS_NONE, "%s is focusable" % control.name, failures)
		TestAssertions.truthy(not control.focus_next.is_empty() and not control.focus_previous.is_empty(), "%s has explicit focus neighbors" % control.name, failures)
		TestAssertions.truthy(not control.focus_neighbor_top.is_empty() and not control.focus_neighbor_bottom.is_empty(), "%s has controller focus neighbors" % control.name, failures)
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


func _index_for_id(list: ItemList, profile_id: String) -> int:
	for index: int in range(list.item_count):
		if str(list.get_item_metadata(index)) == profile_id:
			return index
	return -1
