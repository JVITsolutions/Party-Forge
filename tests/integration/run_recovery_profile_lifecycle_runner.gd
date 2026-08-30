extends SceneTree

const SCREENSHOT_ROOT := "res://docs/validation/screenshots/run-recovery-profile-lifecycle"

var _failures: Array[String] = []
var _fixture_counter := 0
var _capture_evidence := false


func _initialize() -> void:
	_capture_evidence = "--capture-evidence" in OS.get_cmdline_user_args()
	call_deferred(&"_run")


func _run() -> void:
	var suite_root := "user://tests/run_recovery_profile_lifecycle"
	ProfileTestSupport.remove_tree(suite_root)
	await _current_recovery_scenario()
	await _legacy_class_scenarios()
	await _abandonment_scenario()
	await _profile_deletion_scenarios()
	ProfileTestSupport.remove_tree(suite_root)
	if _failures.is_empty():
		print("RUN_RECOVERY_PROFILE_LIFECYCLE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("RUN_RECOVERY_PROFILE_LIFECYCLE_FAILURE: %s" % failure)
	print("RUN_RECOVERY_PROFILE_LIFECYCLE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _current_recovery_scenario() -> void:
	var paths := _fixture_paths("current")
	var main := await _new_main(paths)
	var profile_id := await _create_profile(main, "Current Recovery")
	await _start_class(main, &"fighter")
	_assert(main.run_started, "current checkout starts through the production Fighter button")
	var context := main.active_run_context
	var snapshot := {
		"run_id": String(context.run_id) if context != null else "",
		"run_seed": context.run_seed if context != null else 0,
		"run_player_id": String(context.run_player_id) if context != null else "",
		"leader_member_id": main.party_manager.members[0].member_id if main.party_manager != null and not main.party_manager.members.is_empty() else 0,
		"class_id": String(main.party_manager.members[0].class_definition.id) if main.party_manager != null and not main.party_manager.members.is_empty() else "",
		"item_state": context.item_state().to_dictionary() if context != null and context.item_state() != null else {},
	}
	var checked_out := _load_profile(profile_id, paths.profile_root)
	_assert(checked_out != null and not checked_out.resumable_run.is_empty(), "current checkout persists a strict recovery")
	_assert(_operation_count(checked_out, "run_loadout_checkout") == 1, "current checkout journal contains exactly one run_loadout_checkout operation")
	await _free_main(main)

	main = await _new_main(paths)
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	(menu.get_node("PrimaryAction") as Button).pressed.emit()
	await _frames(2)
	var dialog := main.get_node("RunRecoveryDialog")
	var resume := dialog.get_node("Overlay/Frame/Layout/Actions/Resume") as Button
	var abandon := dialog.get_node("Overlay/Frame/Layout/Actions/Abandon") as Button
	_assert(dialog.call("is_open") and resume.visible and abandon.visible, "current restart opens player-facing Resume Run and Abandon Run actions")
	_assert(root.gui_get_focus_owner() == resume, "current recovery gives Resume Run initial focus")
	if _capture_evidence:
		await _capture_screenshot("resume-run.png")
	resume.pressed.emit()
	await _frames(4)
	context = main.active_run_context
	_assert(main.run_started and context != null, "Resume Run starts the production runtime")
	_assert(context != null and String(context.run_id) == snapshot.run_id, "Resume Run preserves run id")
	_assert(context != null and context.run_seed == snapshot.run_seed, "Resume Run preserves run seed")
	_assert(context != null and String(context.run_player_id) == snapshot.run_player_id, "Resume Run preserves run player id")
	_assert(main.party_manager.members[0].member_id == snapshot.leader_member_id, "Resume Run preserves leader member id")
	_assert(String(main.party_manager.members[0].class_definition.id) == snapshot.class_id, "Resume Run preserves leader class")
	_assert(context != null and context.item_state().to_dictionary() == snapshot.item_state, "Resume Run restores the exact item state")
	var resumed := _load_profile(profile_id, paths.profile_root)
	_assert(_operation_count(resumed, "run_loadout_checkout") == 1, "Resume Run never performs a second checkout")
	if not _failures.any(func(message: String) -> bool: return message.begins_with("current ") or message.begins_with("Resume Run")):
		print("RUN_RECOVERY_CURRENT: PASS")
	await _free_main(main)


func _legacy_class_scenarios() -> void:
	var failures_before := _failures.size()
	var paths := _fixture_paths("legacy-compatible")
	var main := await _new_main(paths)
	var profile_id := await _create_profile(main, "Legacy Compatible")
	await _start_class(main, &"fighter")
	_assert(main.run_started, "legacy compatible fixture checks out through the production Fighter button")
	await _free_main(main)
	_convert_to_schema_four(profile_id, paths.profile_root)

	main = await _new_main(paths)
	var dialog := await _open_recovery(main)
	var picker := dialog.get_node("Overlay/Frame/Layout/ClassPicker") as OptionButton
	var bind := dialog.get_node("Overlay/Frame/Layout/Actions/Bind") as Button
	var resume := dialog.get_node("Overlay/Frame/Layout/Actions/Resume") as Button
	_assert(dialog.call("is_open") and picker.visible and bind.visible and not resume.visible, "schema-four restart presents the legacy leader-class choice")
	_assert(root.gui_get_focus_owner() == picker, "legacy class prompt gives the class picker initial focus")
	if _capture_evidence:
		await _capture_screenshot("legacy-class.png")
	_select_option_metadata(picker, &"fighter")
	bind.pressed.emit()
	await _frames(6)
	_assert(main.run_started and main.party_manager.members[0].class_definition.id == &"fighter", "compatible legacy class selection starts the recovered Fighter run")
	var bound := _load_profile(profile_id, paths.profile_root)
	_assert(bound != null and String(bound.resumable_run.get("selected_leader_class_id", "")) == "fighter", "legacy class binding persists the selected class marker")
	_assert(_operation_count(bound, "run_loadout_checkout") == 1, "legacy class binding retains exactly one original checkout")
	_assert(_operation_count(bound, "bind_run_recovery_class") == 1, "legacy class binding persists exactly one bind transaction")
	await _free_main(main)

	main = await _new_main(paths)
	dialog = await _open_recovery(main)
	picker = dialog.get_node("Overlay/Frame/Layout/ClassPicker") as OptionButton
	resume = dialog.get_node("Overlay/Frame/Layout/Actions/Resume") as Button
	_assert(dialog.call("is_open") and resume.visible and not picker.visible, "bound legacy restart routes directly to Resume Run without a second class prompt")
	resume.pressed.emit()
	await _frames(5)
	_assert(main.run_started and main.party_manager.members[0].class_definition.id == &"fighter", "bound legacy restart resumes the persisted Fighter run")
	await _free_main(main)

	paths = _fixture_paths("legacy-incompatible")
	main = await _new_main(paths)
	profile_id = await _create_profile(main, "Legacy Incompatible")
	await _start_class(main, &"fighter")
	_assert(main.run_started, "legacy incompatible fixture checks out through the production Fighter button")
	await _free_main(main)
	_convert_to_schema_four(profile_id, paths.profile_root, true)
	main = await _new_main(paths)
	dialog = await _open_recovery(main)
	picker = dialog.get_node("Overlay/Frame/Layout/ClassPicker") as OptionButton
	bind = dialog.get_node("Overlay/Frame/Layout/Actions/Bind") as Button
	_select_option_metadata(picker, &"fighter")
	var profile_path := ProfileStore.new().profile_path(profile_id, paths.profile_root)
	var before := FileAccess.get_file_as_bytes(profile_path)
	bind.pressed.emit()
	await _frames(4)
	_assert(FileAccess.get_file_as_bytes(profile_path) == before, "incompatible legacy class selection preserves exact recovery bytes")
	_assert(not main.run_started and dialog.call("is_open"), "incompatible legacy class selection leaves runtime stopped and recovery visible")
	_assert((dialog.get_node("Overlay/Frame/Layout/Status") as Label).text == "Unable to bind that leader class.", "incompatible legacy class selection uses safe player-facing status")
	_assert((dialog.get_node("Overlay/Frame/Layout/TechnicalDetail") as Label).text.contains("ineligible"), "incompatible legacy class selection retains technical eligibility detail")
	await _free_main(main)
	if _failures.size() == failures_before:
		print("RUN_RECOVERY_LEGACY_CLASS: PASS")


func _abandonment_scenario() -> void:
	var failures_before := _failures.size()
	var paths := _fixture_paths("abandon")
	var main := await _new_main(paths)
	var profile_id := await _create_profile(main, "Abandon Recovery")
	_seed_fighter_loadout(profile_id, paths.profile_root)
	await _start_class(main, &"fighter")
	_assert(main.run_started, "abandon fixture checks out through the production Fighter button")
	var checked_out := _load_profile(profile_id, paths.profile_root)
	var run_id := String(checked_out.resumable_run.get("run_id", "")) if checked_out != null else ""
	var run_item_ids := _recovery_item_ids(checked_out)
	_assert(not run_id.is_empty(), "abandon fixture persists an exact run id")
	_assert(not run_item_ids.is_empty(), "abandon fixture owns at least one run item")
	await _free_main(main)

	main = await _new_main(paths)
	var dialog := await _open_recovery(main)
	var abandon := dialog.get_node("Overlay/Frame/Layout/Actions/Abandon") as Button
	var confirmation := dialog.get_node("AbandonConfirmation") as ConfirmationDialog
	var profile_path := ProfileStore.new().profile_path(profile_id, paths.profile_root)
	var before_cancel := FileAccess.get_file_as_bytes(profile_path)
	abandon.pressed.emit()
	await _frames(2)
	_assert(confirmation.visible and confirmation.dialog_text.contains(run_id), "Abandon Run opens a confirmation naming the exact run")
	await _key(KEY_ESCAPE)
	_assert(not confirmation.visible, "keyboard Cancel closes run abandonment confirmation")
	_assert(FileAccess.get_file_as_bytes(profile_path) == before_cancel, "cancelled abandonment preserves exact profile bytes")
	_assert(root.gui_get_focus_owner() == abandon, "keyboard-cancelled abandonment restores Abandon Run focus")

	var mismatched := _load_profile(profile_id, paths.profile_root)
	mismatched.resumable_run["run_id"] = "%s-mismatch" % run_id
	var mismatch_error := ProfileStore.new().save_profile(mismatched, paths.profile_root)
	_assert(mismatch_error.is_empty(), "isolated mismatched-run fixture persists")
	var mismatch_bytes := FileAccess.get_file_as_bytes(profile_path)
	abandon.pressed.emit()
	await _frames(2)
	confirmation.get_ok_button().pressed.emit()
	await _frames(4)
	_assert(FileAccess.get_file_as_bytes(profile_path) == mismatch_bytes, "cached nonmatching run id cannot clear changed recovery bytes")
	_assert(not main.run_started and dialog.call("is_open"), "mismatched abandonment keeps runtime stopped and recovery visible")
	_assert((dialog.get_node("Overlay/Frame/Layout/TechnicalDetail") as Label).text.contains("run identity mismatch"), "mismatched abandonment exposes exact technical protection")
	await _free_main(main)

	main = await _new_main(paths)
	dialog = await _open_recovery(main)
	abandon = dialog.get_node("Overlay/Frame/Layout/Actions/Abandon") as Button
	confirmation = dialog.get_node("AbandonConfirmation") as ConfirmationDialog
	abandon.pressed.emit()
	await _frames(2)
	confirmation.get_ok_button().pressed.emit()
	await _frames(5)
	var forfeited := _load_profile(profile_id, paths.profile_root)
	_assert(forfeited != null and forfeited.resumable_run == {}, "confirmed matching abandonment durably clears the exact recovery")
	var durable_text := JSON.stringify(forfeited.to_dictionary()) if forfeited != null else ""
	for instance_id: String in run_item_ids:
		_assert(not durable_text.contains(instance_id), "confirmed matching abandonment removes run-owned item %s from all profile storage" % instance_id)
	_assert(not dialog.call("is_open") and not main.run_started, "confirmed matching abandonment returns to the stopped front end")
	await _free_main(main)
	if _failures.size() == failures_before:
		print("RUN_RECOVERY_ABANDON: PASS")


func _profile_deletion_scenarios() -> void:
	var failures_before := _failures.size()
	await _healthy_profile_deletion_lifecycle()
	await _recovered_profile_deletion()
	await _damaged_profile_deletion()
	await _active_run_deletion_gate()
	if _failures.size() == failures_before:
		print("PROFILE_DELETE_LIFECYCLE: PASS")


func _healthy_profile_deletion_lifecycle() -> void:
	var paths := _fixture_paths("delete-healthy")
	var main := await _new_main(paths)
	var inactive_id := await _create_profile(main, "Lifecycle Inactive")
	var replacement_id := await _create_profile(main, "Lifecycle Replacement")
	var active_id := await _create_profile(main, "Lifecycle Active")
	var replacement := _load_profile(replacement_id, paths.profile_root)
	if replacement != null:
		replacement.updated_at_unix = int(Time.get_unix_time_from_system()) + 100
		var save_error := ProfileStore.new().save_profile(replacement, paths.profile_root)
		_assert(save_error.is_empty(), "most-recent replacement fixture persists: %s" % save_error)
	await _free_main(main)

	main = await _new_main(paths)
	var profiles := await _open_profiles_through_front_end(main)
	var list := profiles.get_node("Layout/ProfileList") as ItemList
	var delete := profiles.get_node("Layout/DeleteProfile") as Button
	var confirmation := profiles.get_node("DeleteConfirmation") as ConfirmationDialog
	_select_profile_row(list, inactive_id)
	delete.grab_focus()
	var inactive_path := ProfileStore.new().profile_path(inactive_id, paths.profile_root)
	var replacement_path := ProfileStore.new().profile_path(replacement_id, paths.profile_root)
	var inactive_bytes := FileAccess.get_file_as_bytes(inactive_path)
	var neighbor_bytes := FileAccess.get_file_as_bytes(replacement_path)
	await _key(KEY_ENTER)
	_assert(confirmation.visible and confirmation.dialog_text.contains("Lifecycle Inactive"), "keyboard Delete opens a named inactive-profile confirmation")
	await _key(KEY_ESCAPE)
	_assert(not confirmation.visible and root.gui_get_focus_owner() == delete, "keyboard cancel restores inactive-profile Delete focus")
	_assert(FileAccess.get_file_as_bytes(inactive_path) == inactive_bytes, "inactive deletion cancel preserves exact target bytes")
	delete.pressed.emit()
	await _frames(2)
	confirmation.hide()
	confirmation.confirmed.emit()
	await _frames(4)
	_assert(_profile_artifacts_absent(inactive_id, paths.profile_root), "inactive profile deletion removes every target artifact")
	_assert(FileAccess.get_file_as_bytes(replacement_path) == neighbor_bytes, "inactive profile deletion preserves neighboring profile bytes")
	_assert(main.active_profile() != null and main.active_profile().profile_id == active_id, "inactive profile deletion preserves the active profile")

	_select_profile_row(list, active_id)
	delete.grab_focus()
	var active_path := ProfileStore.new().profile_path(active_id, paths.profile_root)
	var active_bytes := FileAccess.get_file_as_bytes(active_path)
	await _joy_button(JOY_BUTTON_A)
	_assert(confirmation.visible and confirmation.dialog_text.contains("Lifecycle Active"), "controller accept opens the named active-profile confirmation")
	if _capture_evidence:
		await _capture_screenshot("delete-profile.png")
	confirmation.get_cancel_button().grab_focus()
	await _joy_button(JOY_BUTTON_A)
	await _frames(2)
	_assert(not confirmation.visible and root.gui_get_focus_owner() == delete, "controller cancel restores active-profile Delete focus")
	_assert(FileAccess.get_file_as_bytes(active_path) == active_bytes, "controller-cancelled active deletion preserves exact target bytes")
	await _joy_button(JOY_BUTTON_A)
	_assert(confirmation.visible, "controller accept reopens active-profile confirmation")
	confirmation.hide()
	confirmation.confirmed.emit()
	await _frames(3)
	_assert(_profile_artifacts_absent(active_id, paths.profile_root), "active profile deletion removes every target artifact")
	_assert(main.active_profile() != null and main.active_profile().profile_id == replacement_id, "active deletion selects the most-recent remaining profile")
	_assert(list.item_count == 1 and String(list.get_item_metadata(0)) == replacement_id, "active deletion refreshes the replacement row")
	_assert(root.gui_get_focus_owner() == list, "committed active deletion restores focus to the replacement row")

	_select_profile_row(list, replacement_id)
	delete.pressed.emit()
	await _frames(2)
	confirmation.hide()
	confirmation.confirmed.emit()
	await _frames(4)
	_assert(_profile_artifacts_absent(replacement_id, paths.profile_root), "final profile deletion removes every target artifact")
	_assert(main.profile_manager.profiles().is_empty() and main.profile_manager.profile_statuses().is_empty(), "final deletion leaves no profiles")
	_assert(list.item_count == 0 and not list.visible and (profiles.get_node("Layout/EmptyState") as Label).visible, "final deletion shows the no-profile create state")
	_assert(root.gui_get_focus_owner() == profiles.get_node("Layout/CreateRow/ProfileName"), "final deletion restores keyboard focus to Profile Name")
	await _free_main(main)


func _recovered_profile_deletion() -> void:
	var paths := _fixture_paths("delete-recovered")
	var main := await _new_main(paths)
	var neighbor_id := await _create_profile(main, "Recovered Neighbor")
	var target_id := await _create_profile(main, "Recovered Target")
	await _free_main(main)
	var store := ProfileStore.new()
	var neighbor_path := store.profile_path(neighbor_id, paths.profile_root)
	var target_path := store.profile_path(target_id, paths.profile_root)
	var neighbor_bytes := FileAccess.get_file_as_bytes(neighbor_path)
	var valid_target_bytes := FileAccess.get_file_as_bytes(target_path)
	_write_bytes("%s.bak" % target_path, valid_target_bytes)
	_write_bytes(target_path, "task7 corrupt primary for verified backup recovery".to_utf8_buffer())

	main = await _new_main(paths)
	var recovered_status := _profile_status(main, target_id)
	_assert(recovered_status != null and recovered_status.state == ProfileEntryStatus.State.RECOVERED, "verified backup boot exposes the recovered health state")
	var profiles := await _open_profiles_through_front_end(main)
	var list := profiles.get_node("Layout/ProfileList") as ItemList
	_select_profile_row(list, target_id)
	_assert(list.get_item_text(list.get_selected_items()[0]).contains("[Recovered]"), "real Profiles UI labels the recovered row")
	var delete := profiles.get_node("Layout/DeleteProfile") as Button
	var confirmation := profiles.get_node("DeleteConfirmation") as ConfirmationDialog
	delete.pressed.emit()
	await _frames(2)
	confirmation.hide()
	confirmation.confirmed.emit()
	await _frames(4)
	_assert(_profile_artifacts_absent(target_id, paths.profile_root), "recovered profile deletion removes primary and verified backup artifacts")
	_assert(FileAccess.get_file_as_bytes(neighbor_path) == neighbor_bytes, "recovered profile deletion preserves neighboring profile bytes")
	_assert(main.active_profile() != null and main.active_profile().profile_id == neighbor_id, "recovered active deletion selects its healthy neighbor")
	await _free_main(main)


func _damaged_profile_deletion() -> void:
	var paths := _fixture_paths("delete-damaged")
	var main := await _new_main(paths)
	var target_id := await _create_profile(main, "Damaged Target")
	await _free_main(main)
	var target_path := ProfileStore.new().profile_path(target_id, paths.profile_root)
	if FileAccess.file_exists("%s.bak" % target_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.bak" % target_path))
	_write_bytes(target_path, "task7 damaged profile without valid generation".to_utf8_buffer())

	main = await _new_main(paths)
	var damaged_status := _profile_status(main, target_id)
	_assert(damaged_status != null and damaged_status.state == ProfileEntryStatus.State.DAMAGED, "invalid generations boot as the damaged health state")
	var profiles := await _open_profiles_through_front_end(main)
	var list := profiles.get_node("Layout/ProfileList") as ItemList
	_select_profile_row(list, target_id)
	_assert(list.get_item_text(list.get_selected_items()[0]).contains("[Damaged]"), "real Profiles UI labels the damaged row")
	var delete := profiles.get_node("Layout/DeleteProfile") as Button
	var confirmation := profiles.get_node("DeleteConfirmation") as ConfirmationDialog
	delete.pressed.emit()
	await _frames(2)
	confirmation.hide()
	confirmation.confirmed.emit()
	await _frames(4)
	_assert(_profile_artifacts_absent(target_id, paths.profile_root), "damaged profile deletion removes undecodable artifacts")
	_assert(main.profile_manager.profile_statuses().is_empty(), "damaged final deletion clears its discovered health entry")
	_assert(root.gui_get_focus_owner() == profiles.get_node("Layout/CreateRow/ProfileName"), "damaged final deletion restores the create-profile focus")
	await _free_main(main)


func _active_run_deletion_gate() -> void:
	var paths := _fixture_paths("delete-active-run")
	var main := await _new_main(paths)
	await _create_profile(main, "Run Active Target")
	await _start_class(main, &"fighter")
	_assert(main.run_started, "active-run deletion fixture starts through the production Fighter button")
	var selector_settings := (main.get_node("HUD/ClassSelection") as ClassSelectionPanel).action_focus(&"settings") as Button
	selector_settings.pressed.emit()
	await _frames(2)
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var profiles := await _navigate_to_profiles(settings)
	var delete := profiles.get_node("Layout/DeleteProfile") as Button
	var confirmation := profiles.get_node("DeleteConfirmation") as ConfirmationDialog
	_assert(settings.is_open() and delete.disabled, "Delete Selected Profile is disabled while run_started is true")
	delete.pressed.emit()
	await _frames(2)
	_assert(not confirmation.visible and main.profile_manager.profiles().size() == 1, "disabled active-run Delete cannot open confirmation or mutate profiles")
	await _free_main(main)


func _open_profiles_through_front_end(main: PartyForgeMain) -> ProfilesSettingsPage:
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	if main.active_profile() == null:
		(menu.get_node("PrimaryAction") as Button).pressed.emit()
		await _frames(2)
		return main.get_node("SettingsScreen/Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	(menu.get_node("Settings") as Button).pressed.emit()
	await _frames(2)
	return await _navigate_to_profiles(main.get_node("SettingsScreen") as SettingsScreen)


func _navigate_to_profiles(settings: SettingsScreen) -> ProfilesSettingsPage:
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var profiles := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var guard := 0
	while tabs.get_tab_control(tabs.current_tab) != profiles and guard < tabs.get_tab_count():
		await _joy_button(JOY_BUTTON_RIGHT_SHOULDER)
		guard += 1
	_assert(tabs.get_tab_control(tabs.current_tab) == profiles, "controller shoulder navigation reaches Settings > Profiles")
	return profiles


func _select_profile_row(list: ItemList, profile_id: String) -> void:
	for index: int in range(list.item_count):
		if String(list.get_item_metadata(index)) == profile_id:
			list.select(index)
			list.item_selected.emit(index)
			list.grab_focus()
			return
	_assert(false, "Profiles UI contains row %s" % profile_id)


func _profile_status(main: PartyForgeMain, profile_id: String) -> ProfileEntryStatus:
	for status: ProfileEntryStatus in main.profile_manager.profile_statuses():
		if status.profile_id == profile_id:
			return status
	return null


func _profile_artifacts_absent(profile_id: String, profile_root: String) -> bool:
	var primary_name := "%s.json" % profile_id
	var absolute_root := ProjectSettings.globalize_path(profile_root)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return true
	var directory := DirAccess.open(absolute_root)
	if directory == null:
		return false
	for file_name: String in directory.get_files():
		if file_name == primary_name or file_name.begins_with("%s." % primary_name):
			return false
	return true


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert(file != null, "isolated fixture bytes open at %s" % path)
	if file == null:
		return
	file.store_buffer(bytes)
	var error := file.get_error()
	file.close()
	_assert(error == OK, "isolated fixture bytes write at %s" % path)


func _seed_fighter_loadout(profile_id: String, profile_root: String) -> void:
	var profile := _load_profile(profile_id, profile_root)
	if profile == null:
		return
	var item := ItemInstance.new()
	item.instance_id = "item-abandon-owned-%d" % _fixture_counter
	item.base_definition_id = &"forge_vanguard_sword"
	item.item_level = 28
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": "profile:%s" % profile_id,
		"seed": 4501,
		"sequence": 0,
		"source": "task7_abandon_fixture",
	}
	profile.item_records = ItemRegistry.new([item]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout",
		ItemSlotContainer.PROFILE_LEADER_EQUIPMENT,
		profile_id,
		EquipmentSlotIndex.capacity(),
		{EquipmentSlotIndex.index_for(&"main_hand"): item.instance_id},
	).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	for unlock: String in ["bring_in_gear", "equipment_inventory", "stash"]:
		if unlock not in profile.permanent_feature_unlocks:
			profile.permanent_feature_unlocks.append(unlock)
	var error := ProfileStore.new().save_profile(profile, profile_root)
	_assert(error.is_empty(), "isolated Fighter loadout fixture persists: %s" % error)


func _recovery_item_ids(profile: ProfileState) -> Array[String]:
	var result: Array[String] = []
	if profile == null:
		return result
	var item_state := profile.resumable_run.get("item_state", {}) as Dictionary
	var registry := item_state.get("registry", {}) as Dictionary
	for item_value: Variant in registry.get("items", []) as Array:
		var item := item_value as Dictionary
		var instance_id := String(item.get("instance_id", "")) if item != null else ""
		if not instance_id.is_empty():
			result.append(instance_id)
	result.sort()
	return result


func _open_recovery(main: PartyForgeMain) -> Node:
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	(menu.get_node("PrimaryAction") as Button).pressed.emit()
	await _frames(2)
	return main.get_node("RunRecoveryDialog")


func _convert_to_schema_four(profile_id: String, profile_root: String, add_incompatible_item := false) -> void:
	var path := ProfileStore.new().profile_path(profile_id, profile_root)
	var document := _read_json_document(path)
	if document.is_empty():
		return
	_downgrade_document_to_schema_four(document)
	if add_incompatible_item:
		_add_incompatible_recovery_item(document)
	var validation := ProfileCodec.validate_schema_four_document(document)
	_assert(validation.is_empty(), "schema-four fixture validates before restart: %s" % validation)
	_write_json_document(path, document)


func _downgrade_document_to_schema_four(document: Dictionary) -> void:
	for record_value: Variant in (document.get("applied_transactions", {}) as Dictionary).values():
		var record := record_value as Dictionary
		if record != null and record.get("result_profile") is Dictionary:
			_downgrade_document_to_schema_four(record["result_profile"] as Dictionary)
	document["schema_version"] = ProfileCodec.SCHEMA_FOUR_VERSION
	document.erase("terminal_resolution")
	document.erase("terminal_recovery_overflow")
	var recovery := document.get("resumable_run", {}) as Dictionary
	if not recovery.is_empty():
		recovery.erase("selected_leader_class_id")


func _add_incompatible_recovery_item(document: Dictionary) -> void:
	var recovery := document.get("resumable_run", {}) as Dictionary
	var item_state := recovery.get("item_state", {}) as Dictionary
	var registry := item_state.get("registry", {}) as Dictionary
	var items := registry.get("items", []) as Array
	var item := ItemInstance.new()
	item.instance_id = "item-legacy-incompatible-%d" % _fixture_counter
	item.base_definition_id = &"storm_chaplain_vestments"
	item.item_level = 28
	item.rarity_id = &"common"
	item.origin = {
		"issuer_namespace": "run:%s" % String(recovery.get("run_id", "")),
		"seed": int(recovery.get("run_seed", 1)),
		"sequence": 0,
		"source": "task7_legacy_fixture",
	}
	items.append(item.to_dictionary())
	for container_value: Variant in item_state.get("containers", []) as Array:
		var container := container_value as Dictionary
		if container != null and String(container.get("container_kind", "")) == String(ItemSlotContainer.RUN_MEMBER_EQUIPMENT):
			(container["slots"] as Dictionary)[str(EquipmentSlotIndex.index_for(&"body_armour"))] = item.instance_id
			return
	_assert(false, "legacy incompatible fixture finds the recovered leader equipment container")


func _select_option_metadata(option: OptionButton, metadata: StringName) -> void:
	for index: int in range(option.item_count):
		if StringName(option.get_item_metadata(index)) == metadata:
			option.select(index)
			option.item_selected.emit(index)
			return
	_assert(false, "option contains metadata %s" % metadata)


func _read_json_document(path: String) -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	_assert(error == OK and parser.data is Dictionary, "isolated fixture JSON parses at %s" % path)
	return (parser.data as Dictionary).duplicate(true) if error == OK and parser.data is Dictionary else {}


func _write_json_document(path: String, document: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert(file != null, "isolated fixture JSON opens for writing at %s" % path)
	if file == null:
		return
	file.store_string(JSON.stringify(document, "\t", false))
	var error := file.get_error()
	file.close()
	_assert(error == OK, "isolated fixture JSON writes at %s" % path)


func _fixture_paths(label: String) -> Dictionary:
	_fixture_counter += 1
	var suffix := "%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), _fixture_counter]
	var base := "user://tests/run_recovery_profile_lifecycle/%s/%s" % [label.validate_filename(), suffix]
	return {
		"base": base,
		"profile_root": base.path_join("profiles"),
		"settings_path": base.path_join("settings.json"),
	}


func _new_main(paths: Dictionary) -> PartyForgeMain:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = String(paths.profile_root)
	main.settings_path = String(paths.settings_path)
	root.add_child(main)
	await _frames(2)
	return main


func _create_profile(main: PartyForgeMain, display_name: String) -> String:
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	(menu.get_node("PrimaryAction") as Button).pressed.emit()
	await _frames(2)
	var profiles := main.get_node("SettingsScreen/Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var name_field := profiles.get_node("Layout/CreateRow/ProfileName") as LineEdit
	name_field.text = display_name
	(profiles.get_node("Layout/CreateRow/Create") as Button).pressed.emit()
	await _frames(3)
	var active := main.active_profile()
	_assert(active != null and active.display_name == display_name, "profile UI creates %s" % display_name)
	return active.profile_id if active != null else ""


func _start_class(main: PartyForgeMain, class_id: StringName) -> void:
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	(menu.get_node("PrimaryAction") as Button).pressed.emit()
	await _frames(2)
	var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var button := lobby.selection_focus(class_id) as Button
	button.pressed.emit()
	await _frames(1)
	_assert(not main.run_started and lobby.selected_class_id() == class_id, "%s confirmation is ephemeral before Start Run" % class_id)
	(lobby.action_focus(&"start") as Button).pressed.emit()
	await _frames(5)


func _load_profile(profile_id: String, profile_root: String) -> ProfileState:
	var loaded := ProfileStore.new().load_profile(profile_id, profile_root)
	_assert(loaded.ok(), "fixture profile %s loads from its isolated root" % profile_id)
	return loaded.profile if loaded.ok() else null


func _operation_count(profile: ProfileState, operation: String) -> int:
	if profile == null:
		return 0
	var count := 0
	for record_value: Variant in profile.applied_transactions.values():
		var record := record_value as Dictionary
		if record != null and String(record.get("operation", "")) == operation:
			count += 1
	return count


func _capture_screenshot(file_name: String) -> void:
	await _frames(2)
	var absolute_root := ProjectSettings.globalize_path(SCREENSHOT_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var image := root.get_texture().get_image()
	var error := image.save_png(absolute_root.path_join(file_name)) if image != null else ERR_UNAVAILABLE
	_assert(error == OK, "windowed screenshot %s saves" % file_name)


func _free_main(main: PartyForgeMain) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	await _frames(3)


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _joy_button(button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
