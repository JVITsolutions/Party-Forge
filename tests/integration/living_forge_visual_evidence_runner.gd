extends SceneTree

const BOARD_SCENE := preload("res://scenes/dev/living_forge_state_board.tscn")
const MAIN_SCENE := preload("res://scenes/game/main.tscn")
const SCREENSHOT_ROOT := "res://docs/validation/screenshots/living-forge-foundation"
const MANIFEST_NAME := "manifest.json"
const EXPECTED_FILES: Array[String] = [
	"living-forge-state-board-normal.png",
	"living-forge-state-board-compound-states.png",
	"living-forge-state-board-action-states-pressed-proof.png",
	"living-forge-state-board-normal-keyboard-focus.png",
	"living-forge-state-board-normal-controller-focus.png",
	"living-forge-state-board-high-contrast.png",
	"living-forge-state-board-high-contrast-controller-focus.png",
	"living-forge-state-board-class-card-hover-preview.png",
	"living-forge-state-board-normal-mouse-hover.png",
	"settings-1920x1080-game-controls.png",
	"settings-1920x1080-reduced-motion.png",
	"settings-1280x720-text150.png",
	"settings-3840x2160.png",
	"play-lobby-1920x1080-compatible-keyboard.png",
	"play-lobby-1920x1080-select-fighter-preview-mage.png",
	"play-lobby-1920x1080-controller-focus.png",
	"play-lobby-1920x1080-high-contrast.png",
	"play-lobby-1920x1080-checking.png",
	"play-lobby-1920x1080-needs-attention.png",
	"play-lobby-1920x1080-starting.png",
	"play-lobby-1920x1080-safe-error.png",
	"play-lobby-1920x1080-settings-return.png",
	"play-lobby-1920x1080-armoury-return-direct.png",
	"play-lobby-1920x1080-armoury-return-warning.png",
	"play-lobby-1920x1080-live-hero.png",
	"play-lobby-1920x1080-missing-presentation-fallback.png",
	"play-lobby-1280x720-ui100-text100.png",
	"play-lobby-1280x720-ui100-text150.png",
	"play-lobby-1280x720-ui150-text80.png",
	"play-lobby-1280x720-ui150-text150.png",
	"play-lobby-2560x1440-ui100-text100.png",
	"play-lobby-3440x1440-ui100-text100.png",
	"play-lobby-3840x2160-ui100-text100.png",
]

var _failures: Array[String] = []
var _entries: Array[Dictionary] = []
var _captured: Dictionary = {}
var _fixture_root := ""
var _started_unix := 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--capture-evidence" not in OS.get_cmdline_user_args():
		_failures.append("capture mode requires --capture-evidence")
		_finish()
		return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	_started_unix = int(Time.get_unix_time_from_system())
	_fixture_root = "user://tests/living_forge_visual_evidence/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_fixture_root)
	_assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_ROOT)) == OK, "evidence directory is available")
	_assert_no_extra_pngs()
	if not _failures.is_empty():
		_finish()
		return
	print("LIVING_FORGE_VISUAL_EVIDENCE_CAPTURE_START files=%d" % EXPECTED_FILES.size())
	await _capture_state_board()
	await _capture_compatible_main()
	await _capture_warning_main()
	await _write_and_validate_manifest()
	ProfileTestSupport.remove_tree(_fixture_root)
	_finish()


func _capture_state_board() -> void:
	root.size = Vector2i(1920, 1080)
	var board := BOARD_SCENE.instantiate() as LivingForgeStateBoard
	root.add_child(board)
	await _frames(5)
	_assert(board != null and board.is_visible_in_tree(), "production state board renders")
	if board == null:
		return
	board.apply_theme_variant(false)
	_release_focus()
	await _capture("living-forge-state-board-normal.png", "state board normal", Vector2i(1920, 1080))
	var compound := board.compound_control(&"focused_selected") as Button
	compound.grab_focus()
	await _capture("living-forge-state-board-compound-states.png", "state board compound focus selected compatible", Vector2i(1920, 1080))
	_release_focus()
	board.set_action_evidence_mode(true)
	await _capture("living-forge-state-board-action-states-pressed-proof.png", "state board pressed and unavailable actions", Vector2i(1920, 1080))
	board.set_action_evidence_mode(false)
	var inspect := board.action_button(&"inspect") as Button
	inspect.grab_focus()
	await _capture("living-forge-state-board-normal-keyboard-focus.png", "state board keyboard focus", Vector2i(1920, 1080))
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	_assert(board.active_prompt_mode() == &"controller", "state board observes real simulated controller input")
	await _capture("living-forge-state-board-normal-controller-focus.png", "state board controller focus", Vector2i(1920, 1080))
	_release_focus()
	board.apply_theme_variant(true)
	await _capture("living-forge-state-board-high-contrast.png", "state board high contrast", Vector2i(1920, 1080))
	inspect.grab_focus()
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	await _capture("living-forge-state-board-high-contrast-controller-focus.png", "state board high contrast controller focus", Vector2i(1920, 1080))
	board.apply_theme_variant(false)
	_release_focus()
	var preview_b := board.compound_control(&"preview_b") as Button
	await _mouse_motion(preview_b.get_global_rect().get_center())
	await _capture("living-forge-state-board-class-card-hover-preview.png", "state board select A preview B", Vector2i(1920, 1080))
	var mouse_target := board.action_button(&"inspect") as Button
	await _mouse_motion(mouse_target.get_global_rect().get_center())
	await _capture("living-forge-state-board-normal-mouse-hover.png", "state board mouse hover", Vector2i(1920, 1080))
	board.free()
	await _frames(3)


func _capture_compatible_main() -> void:
	var paths := _fixture_paths("compatible")
	_assert(not _create_completed_profile(paths.profile_root, "Visual Review", false).is_empty(), "compatible evidence profile is created")
	var main := await _instantiate_main(paths)
	if main == null:
		return
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	await _mouse_click(menu.get_node("PrimaryAction") as Button)
	var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	await _mouse_click(lobby.selection_focus(&"fighter") as Button)
	_assert(lobby.selected_class_id() == &"fighter", "compatible evidence selects Fighter through real mouse input")
	await _apply_lobby_presentation(main, lobby, Vector2i(1920, 1080), 100, 100, false, false)
	_assert((lobby.get_node("Content/Margin/Layout/Body/Details/DetailContent/Compatibility") as Label).text.contains("COMPATIBLE"), "compatible evidence has authoritative compatibility copy")
	await _capture("play-lobby-1920x1080-compatible-keyboard.png", "compatible lobby keyboard and mouse prompts with P1 plus three future seats", Vector2i(1920, 1080))
	var compatibility_projection: Variant = main.get("_lobby_compatibility")
	main.set("_lobby_compatibility", null)
	main.call(&"_present_lobby")
	await _frames(4)
	_assert((lobby.get_node("Content/Margin/Layout/Status") as Label).text == RunSetupLobbyViewModel.CHECKING_COPY, "Checking evidence uses production pending projection")
	_assert((lobby.selection_focus(&"fighter").get_node("LockOverlay/Plate/Content/Text") as Label).text == "CHECKING", "Checking evidence exposes the production pending card")
	await _capture("play-lobby-1920x1080-checking.png", "Checking pending class compatibility", Vector2i(1920, 1080))
	main.set("_lobby_compatibility", compatibility_projection)
	main.call(&"_present_lobby")
	await _frames(4)

	await _mouse_motion((lobby.selection_focus(&"mage") as Button).get_global_rect().get_center())
	_assert(lobby.selected_class_id() == &"fighter" and lobby.previewed_class_id() == &"mage", "evidence preserves selected Fighter while previewing Mage")
	await _capture("play-lobby-1920x1080-select-fighter-preview-mage.png", "selected Fighter and previewed Mage", Vector2i(1920, 1080))
	(lobby.selection_focus(&"fighter") as Button).grab_focus()
	await _joy_button(JOY_BUTTON_LEFT_STICK)
	_assert(lobby.active_prompt_mode() == &"controller", "lobby evidence observes simulated controller input")
	await _capture("play-lobby-1920x1080-controller-focus.png", "controller prompts and focus", Vector2i(1920, 1080))

	await _apply_lobby_presentation(main, lobby, Vector2i(1920, 1080), 100, 100, true, false)
	_assert_preview_authority(lobby, "high-contrast re-presentation")
	await _capture("play-lobby-1920x1080-high-contrast.png", "high contrast lobby", Vector2i(1920, 1080))
	await _apply_lobby_presentation(main, lobby, Vector2i(1920, 1080), 100, 100, false, false)
	_assert_preview_authority(lobby, "standard-contrast re-presentation")
	main.call(&"_present_lobby", "", true)
	await _frames(4)
	_assert((lobby.get_node("Content/Margin/Layout/Status") as Label).text == RunSetupLobbyViewModel.STARTING_COPY, "Starting evidence uses production starting projection")
	await _capture("play-lobby-1920x1080-starting.png", "Starting state", Vector2i(1920, 1080))
	main.call(&"_present_lobby", "Unable to start run.", false)
	await _frames(4)
	_assert((lobby.get_node("Content/Margin/Layout/Status") as Label).text == "Unable to start run.", "safe error evidence uses player-safe copy")
	_assert_preview_authority(lobby, "safe-error re-presentation")
	await _capture("play-lobby-1920x1080-safe-error.png", "safe run-start error", Vector2i(1920, 1080))
	main.call(&"_present_lobby")
	await _frames(4)

	var settings_button := lobby.action_focus(&"settings") as Button
	await _mouse_click(settings_button)
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	_assert(settings.is_open(), "production Settings opens from lobby")
	_assert_settings_controls(settings)
	await _capture("settings-1920x1080-game-controls.png", "Settings High Contrast UI Scale and Text Scale", Vector2i(1920, 1080))
	await _key(KEY_ESCAPE)
	_assert(root.gui_get_focus_owner() == settings_button, "Settings returns to exact lobby origin")
	_assert_preview_authority(lobby, "Settings return re-presentation")
	await _capture("play-lobby-1920x1080-settings-return.png", "exact Settings return focus", Vector2i(1920, 1080))

	var armoury_button := lobby.action_focus(&"armoury") as Button
	await _mouse_click(armoury_button)
	var armoury := main.get_node("ArmouryScreen") as ArmouryScreen
	_assert(armoury.is_open(), "direct Armoury opens from the lobby")
	await _joy_button(JOY_BUTTON_B)
	_assert(lobby.is_open() and root.gui_get_focus_owner() == armoury_button, "direct Armoury returns to exact lobby origin")
	await _capture("play-lobby-1920x1080-armoury-return-direct.png", "direct Armoury exact return", Vector2i(1920, 1080))

	var preview := lobby.get_node("Content/Margin/Layout/Body/HeroStage/Preview") as CharacterEquipmentPreview
	var fighter := main.catalog.class_by_id(&"fighter")
	_assert(preview.show_class(fighter), "live hero evidence renders Fighter")
	await _frames(4)
	await _capture("play-lobby-1920x1080-live-hero.png", "live Fighter hero", Vector2i(1920, 1080))
	preview.show_fallback(&"missing_evidence", "Preview safely unavailable.")
	await _frames(3)
	_assert((preview.get_node("Fallback") as Control).is_visible_in_tree(), "missing presentation evidence uses production fallback")
	await _capture("play-lobby-1920x1080-missing-presentation-fallback.png", "missing presentation safe fallback", Vector2i(1920, 1080))
	_assert(preview.show_class(fighter), "live hero recovers after fallback evidence")

	main.saved_settings.reduced_motion = true
	main.call(&"_present_lobby")
	await _mouse_click(settings_button)
	var reduced_motion := settings.get_node("Overlay/Frame/Layout/Tabs/Game Settings/Layout/ReducedMotion") as CheckButton
	reduced_motion.button_pressed = true
	await _capture("settings-1920x1080-reduced-motion.png", "reduced motion enabled", Vector2i(1920, 1080))
	await _key(KEY_ESCAPE)

	await _apply_lobby_presentation(main, lobby, Vector2i(1280, 720), 100, 100, false, false)
	await _capture("play-lobby-1280x720-ui100-text100.png", "720p compact lobby pinned footer", Vector2i(1280, 720))
	await _apply_lobby_presentation(main, lobby, Vector2i(1280, 720), 100, 150, false, false)
	await _capture("play-lobby-1280x720-ui100-text150.png", "720p compact lobby text 150 pinned footer", Vector2i(1280, 720))
	await _mouse_click(settings_button)
	settings.open_additional(settings_button)
	await _frames(4)
	_assert_additional_settings_geometry(settings)
	await _capture("settings-1280x720-text150.png", "720p text 150 Additional Settings scrollbar and pinned actions", Vector2i(1280, 720))
	await _key(KEY_ESCAPE)
	await _apply_lobby_presentation(main, lobby, Vector2i(1280, 720), 150, 80, false, false)
	await _capture("play-lobby-1280x720-ui150-text80.png", "720p UI 150 text 80 corner", Vector2i(1280, 720))
	await _apply_lobby_presentation(main, lobby, Vector2i(1280, 720), 150, 150, false, false)
	await _capture("play-lobby-1280x720-ui150-text150.png", "720p UI 150 text 150 corner", Vector2i(1280, 720))
	await _apply_lobby_presentation(main, lobby, Vector2i(2560, 1440), 100, 100, false, false)
	await _capture("play-lobby-2560x1440-ui100-text100.png", "1440p lobby", Vector2i(2560, 1440))
	await _apply_lobby_presentation(main, lobby, Vector2i(3440, 1440), 100, 100, false, false)
	await _capture("play-lobby-3440x1440-ui100-text100.png", "ultrawide bounded lobby", Vector2i(3440, 1440))
	await _apply_lobby_presentation(main, lobby, Vector2i(3840, 2160), 100, 100, false, false)
	await _capture("play-lobby-3840x2160-ui100-text100.png", "4K lobby unchanged information density", Vector2i(3840, 2160))
	await _mouse_click(settings_button)
	_select_settings_tab(settings, "Game Settings")
	await _frames(3)
	_assert_settings_controls(settings)
	await _capture("settings-3840x2160.png", "4K Settings", Vector2i(3840, 2160))
	await _key(KEY_ESCAPE)
	main.free()
	await _frames(4)
	ProfileTestSupport.remove_tree(paths.fixture_root)


func _capture_warning_main() -> void:
	root.size = Vector2i(1920, 1080)
	var paths := _fixture_paths("warning")
	_assert(not _create_completed_profile(paths.profile_root, "Warning Visual Review", true).is_empty(), "warning evidence profile is created")
	var main := await _instantiate_main(paths)
	if main == null:
		return
	await _mouse_click((main.get_node("MainMenuScreen") as MainMenuScreen).get_node("PrimaryAction") as Button)
	var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	await _mouse_click(lobby.selection_focus(&"mage") as Button)
	_assert((lobby.get_node("Content/Margin/Layout/Body/Details/DetailContent/Compatibility") as Label).text.contains("NEEDS ATTENTION"), "warning evidence uses production incompatibility")
	await _capture("play-lobby-1920x1080-needs-attention.png", "Needs Attention selected Mage", Vector2i(1920, 1080))
	await _mouse_click(lobby.action_focus(&"start") as Button)
	var warning := main.get_node("LoadoutWarningDialog")
	_assert(bool(warning.call(&"is_open")), "production warning opens")
	await _mouse_click(warning.get_node("Overlay/Frame/Layout/Actions/Armoury") as Button)
	var armoury := main.get_node("ArmouryScreen") as ArmouryScreen
	_assert(armoury.is_open(), "warning Armoury opens")
	await _joy_button(JOY_BUTTON_B)
	_assert(lobby.is_open() and root.gui_get_focus_owner() == lobby.selection_focus(&"mage"), "warning Armoury returns to exact selected class")
	await _capture("play-lobby-1920x1080-armoury-return-warning.png", "warning Armoury exact return", Vector2i(1920, 1080))
	main.free()
	await _frames(4)
	ProfileTestSupport.remove_tree(paths.fixture_root)


func _apply_lobby_presentation(main: PartyForgeMain, lobby: ClassSelectionPanel, size: Vector2i, ui_scale: int, text_scale: int, high_contrast: bool, reduced_motion: bool) -> void:
	root.size = size
	main.saved_settings.ui_scale_percent = ui_scale
	main.saved_settings.text_scale_percent = text_scale
	main.saved_settings.high_contrast = high_contrast
	main.saved_settings.reduced_motion = reduced_motion
	main.call(&"_present_lobby")
	lobby.apply_viewport_size(Vector2(size))
	await _frames(6)
	var footer := lobby.get_node("Content/Margin/Layout/Footer") as Control
	var margin := lobby.get_node("Content/Margin") as Control
	_assert(margin.get_global_rect().grow(0.5).encloses(footer.get_global_rect()), "pinned footer is contained at %dx%d ui=%d text=%d" % [size.x, size.y, ui_scale, text_scale])
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		var action := lobby.action_focus(action_id) as Button
		_assert(action.size.x >= 48.0 and action.size.y >= 48.0 and footer.get_global_rect().grow(0.5).encloses(action.get_global_rect()), "%s remains an untruncated 48px action at %dx%d ui=%d text=%d" % [action_id, size.x, size.y, ui_scale, text_scale])
	if size == Vector2i(1280, 720) and text_scale == 150 and ui_scale in [100, 150]:
		var roster_scroll := lobby.get_node("Content/Margin/Layout/Body/LeftColumn/ClassRoster/Scroll") as ScrollContainer
		var focused_selected := lobby.selection_focus(lobby.selected_class_id()) as Control
		roster_scroll.ensure_control_visible(focused_selected)
		await _frames(2)
		var roster_viewport_rect := roster_scroll.get_global_rect()
		var selected_rect := focused_selected.get_global_rect()
		var clipped_rect := roster_viewport_rect.intersection(selected_rect)
		_assert(roster_viewport_rect.grow(0.5).encloses(selected_rect) and clipped_rect.size.is_equal_approx(selected_rect.size), "rendered selected class is fully visible at 720p ui=%d text=%d viewport=%s card=%s clipped=%s" % [ui_scale, text_scale, roster_viewport_rect, selected_rect, clipped_rect])


func _assert_preview_authority(lobby: ClassSelectionPanel, label: String) -> void:
	var preview_id := lobby.previewed_class_id()
	var visible_ids: Array[StringName] = []
	var roster := lobby.get_node("Content/Margin/Layout/Body/LeftColumn/ClassRoster/Scroll/Grid") as GridContainer
	for child: Node in roster.get_children():
		var card := child as ForgeClassCard
		if card != null and (card.get_node("PreviewIndicator") as Control).is_visible_in_tree():
			visible_ids.append(card.class_id)
	_assert(visible_ids == ([preview_id] as Array[StringName]), "%s exposes exactly one visible Preview cue on %s, got %s" % [label, preview_id, visible_ids])
	var authoritative_card := lobby.selection_focus(preview_id) as ForgeClassCard
	var authoritative_name := (authoritative_card.get_node("Content/Identity/Name") as Label).text if authoritative_card != null else ""
	_assert((lobby.get_node("Content/Margin/Layout/Body/Details/DetailContent/ClassName") as Label).text == authoritative_name, "%s details match authoritative preview %s" % [label, preview_id])
	var preview := lobby.get_node("Content/Margin/Layout/Body/HeroStage/Preview") as CharacterEquipmentPreview
	var signature: Variant = preview.get("_active_signature")
	var definition: ClassDefinition = signature.get("class_definition") as ClassDefinition if signature != null else null
	_assert(definition != null and definition.id == preview_id, "%s hero matches authoritative preview %s" % [label, preview_id])


func _assert_settings_controls(settings: SettingsScreen) -> void:
	for path: String in [
		"Overlay/Frame/Layout/Tabs/Game Settings/Layout/HighContrast",
		"Overlay/Frame/Layout/Tabs/Game Settings/Layout/UIScale",
		"Overlay/Frame/Layout/Tabs/Game Settings/Layout/TextScale",
	]:
		var control := settings.get_node(path) as Control
		_assert(control.is_visible_in_tree() and control.get_global_rect().has_area(), "Settings control is visible: %s" % path)


func _select_settings_tab(settings: SettingsScreen, tab_name: String) -> void:
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	for index: int in tabs.get_tab_count():
		if tabs.get_tab_title(index) == tab_name:
			tabs.current_tab = index
			tabs.get_tab_bar().current_tab = index
			return
	_failures.append("Settings tab is available: %s" % tab_name)


func _assert_additional_settings_geometry(settings: SettingsScreen) -> void:
	var page := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as Control
	var scroll := page.get_node("Layout/Scroll") as ScrollContainer
	var actions := page.get_node("Layout/Actions") as HBoxContainer
	_assert(page.is_visible_in_tree() and scroll.is_visible_in_tree() and actions.is_visible_in_tree(), "Additional Settings content, scroll region, and actions are visible")
	_assert(scroll.get_v_scroll_bar().is_visible_in_tree(), "Additional Settings exposes a visible scrollbar gutter at 720p text 150")
	_assert(scroll.get_global_rect().end.y + 8.0 <= actions.get_global_rect().position.y, "Additional Settings keeps an 8px gutter above pinned actions")
	_assert(page.get_global_rect().grow(0.5).encloses(scroll.get_global_rect()) and page.get_global_rect().grow(0.5).encloses(actions.get_global_rect()), "Additional Settings scroll region and pinned actions remain contained")
	for name: String in ["ResetDeveloperOptions", "ApplyAndReturn", "Cancel"]:
		var action := actions.get_node(name) as Button
		_assert(action.is_visible_in_tree() and action.size.y >= 48.0 and actions.get_global_rect().grow(0.5).encloses(action.get_global_rect()), "Additional Settings pinned %s action is visible, contained, and 48px" % name)


func _fixture_paths(label: String) -> Dictionary:
	var fixture := _fixture_root.path_join("%s-%d" % [label, Time.get_ticks_usec()])
	return {"fixture_root": fixture, "profile_root": fixture.path_join("profiles"), "settings_path": fixture.path_join("settings.cfg")}


func _create_completed_profile(profile_root: String, display_name: String, warning_item: bool) -> String:
	var manager := ProfileManager.new()
	_assert(manager.bootstrap(profile_root).is_empty(), "%s profile manager bootstraps" % display_name)
	var created := manager.create_profile(display_name)
	_assert(created.ok(), "%s profile creates" % display_name)
	if not created.ok():
		return ""
	var profile_id := created.profile.profile_id
	var completion := ProfileMutationService.new(ProfileStore.new()).complete_prologue(profile_id, "visual-evidence-%s" % profile_id, profile_root)
	_assert(completion.ok(), "%s profile completes prologue" % display_name)
	var loaded := ProfileStore.new().load_profile(profile_id, profile_root)
	if not loaded.ok():
		_assert(false, "%s profile reloads" % display_name)
		return ""
	var profile := loaded.profile
	for unlock: String in ["bring_in_gear", "equipment_inventory", "stash"]:
		if unlock not in profile.permanent_feature_unlocks:
			profile.permanent_feature_unlocks.append(unlock)
	if warning_item:
		var item := ItemInstance.new()
		item.instance_id = "item-visual-warning-%s" % profile_id
		item.base_definition_id = &"dawn_bulwark_plate"
		item.item_level = 28
		item.rarity_id = &"common"
		item.origin = {"issuer_namespace": "profile:%s" % profile_id, "seed": 710, "sequence": 0, "source": "living_forge_visual_evidence_runner"}
		profile.item_records = ItemRegistry.new([item]).to_dictionary()
		profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, profile_id, EquipmentSlotIndex.capacity(), {EquipmentSlotIndex.index_for(&"body_armour"): item.instance_id}).to_dictionary()
		profile.leader_loadout_class_id = "fighter"
	_assert(ProfileStore.new().save_profile(profile, profile_root).is_empty(), "%s profile persists evidence inventory" % display_name)
	return profile_id


func _instantiate_main(paths: Dictionary) -> PartyForgeMain:
	_assert(PartyForgeSettingsStore.new().save_settings(PartyForgeSettings.new(), String(paths.settings_path)).is_empty(), "evidence settings fixture saves")
	var main := MAIN_SCENE.instantiate() as PartyForgeMain
	_assert(main != null, "production Main instantiates")
	if main == null:
		return null
	main.profile_root = String(paths.profile_root)
	main.settings_path = String(paths.settings_path)
	root.add_child(main)
	await _frames(6)
	return main


func _capture(file_name: String, state: String, expected_size: Vector2i) -> void:
	await _frames(4)
	var image := root.get_texture().get_image()
	_assert(image != null and not image.is_empty(), "%s returns rendered pixels" % file_name)
	if image == null or image.is_empty():
		return
	_assert(image.get_size() == expected_size, "%s has exact %dx%d dimensions, actual=%s" % [file_name, expected_size.x, expected_size.y, image.get_size()])
	_assert(_image_is_nonblank(image), "%s is nonblank" % file_name)
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_ROOT.path_join(file_name))
	_assert(image.save_png(absolute_path) == OK, "%s saves" % file_name)
	if not FileAccess.file_exists(absolute_path):
		return
	var hash := _sha256(FileAccess.get_file_as_bytes(absolute_path))
	_assert(not hash.is_empty(), "%s has SHA-256" % file_name)
	_captured[file_name] = hash
	_entries.append({"file": file_name, "sha256": hash, "width": image.get_width(), "height": image.get_height(), "state": state})


func _write_and_validate_manifest() -> void:
	var expected_sorted := EXPECTED_FILES.duplicate()
	expected_sorted.sort()
	var captured_sorted: Array[String] = []
	for file_name: Variant in _captured.keys():
		captured_sorted.append(String(file_name))
	captured_sorted.sort()
	_assert(captured_sorted == expected_sorted, "current run captures every expected screenshot exactly once")
	var unique_hashes: Dictionary = {}
	for hash: Variant in _captured.values():
		unique_hashes[String(hash)] = true
	_assert(unique_hashes.size() == EXPECTED_FILES.size(), "every named evidence state has distinct rendered pixels")
	var manifest := {
		"schema_version": 2,
		"run_id": "%d-%d" % [OS.get_process_id(), _started_unix],
		"captured_at_utc": Time.get_datetime_string_from_system(true, true),
		"source_head": _source_head(),
		"source_tree_fingerprint": _source_tree_fingerprint(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"window_mode": "windowed",
		"entries": _entries,
	}
	var manifest_path := ProjectSettings.globalize_path(SCREENSHOT_ROOT.path_join(MANIFEST_NAME))
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	_assert(file != null, "current-run manifest opens for writing")
	if file != null:
		file.store_string(JSON.stringify(manifest, "  ") + "\n")
		file.close()
	_assert_no_extra_pngs(true)
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var parsed := parsed_value as Dictionary if parsed_value is Dictionary else {}
	_assert(not parsed.is_empty() and int(parsed.get("schema_version", 0)) == 2, "manifest parses with expected schema")
	var parsed_fingerprint := parsed.get("source_tree_fingerprint", {}) as Dictionary
	var current_fingerprint := _source_tree_fingerprint()
	_assert(String(parsed_fingerprint.get("sha256", "")) == String(current_fingerprint.get("sha256", "")) \
			and int(parsed_fingerprint.get("path_count", -1)) == int(current_fingerprint.get("path_count", -2)) \
			and JSON.stringify(parsed_fingerprint.get("inputs", [])) == JSON.stringify(current_fingerprint.get("inputs", [])),
		"manifest source-tree fingerprint matches current tracked and untracked Task 9 inputs")
	var manifest_files: Array[String] = []
	for entry: Dictionary in parsed.get("entries", [] as Array):
		var name := String(entry.get("file", ""))
		manifest_files.append(name)
		var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_ROOT.path_join(name))
		_assert(FileAccess.file_exists(absolute_path), "manifest file exists: %s" % name)
		if FileAccess.file_exists(absolute_path):
			_assert(_sha256(FileAccess.get_file_as_bytes(absolute_path)) == String(entry.get("sha256", "")), "manifest hash matches current bytes: %s" % name)
			_assert(int(FileAccess.get_modified_time(absolute_path)) >= _started_unix, "manifest rejects stale evidence: %s" % name)
	manifest_files.sort()
	_assert(manifest_files == expected_sorted, "manifest rejects missing or extra evidence entries")


func _assert_no_extra_pngs(require_complete := false) -> void:
	var directory := DirAccess.open(SCREENSHOT_ROOT)
	_assert(directory != null, "evidence directory opens")
	if directory == null:
		return
	var actual: Array[String] = []
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "png":
			actual.append(file_name)
	actual.sort()
	var expected := EXPECTED_FILES.duplicate()
	expected.sort()
	if require_complete:
		_assert(actual == expected, "evidence directory contains no missing or extra PNG files")
		return
	for file_name: String in actual:
		_assert(file_name in EXPECTED_FILES, "evidence directory rejects extra PNG: %s" % file_name)


func _source_head() -> String:
	var output: Array = []
	var exit_code := OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"]), output, true)
	_assert(exit_code == 0 and not output.is_empty(), "source HEAD resolves for manifest")
	return String(output[0]).strip_edges() if exit_code == 0 and not output.is_empty() else "unresolved"


func _source_tree_fingerprint() -> Dictionary:
	var output: Array = []
	var repository_root := ProjectSettings.globalize_path("res://")
	var exit_code := OS.execute("git", PackedStringArray(["-C", repository_root, "status", "--porcelain=v1", "--untracked-files=all"]), output, true)
	_assert(exit_code == 0, "source-tree status resolves for manifest fingerprint")
	var records: Array[Dictionary] = []
	var lines := String("".join(output)).split("\n", false)
	for raw_line: String in lines:
		if raw_line.length() < 4:
			continue
		var status_code := raw_line.substr(0, 2)
		var relative_path := raw_line.substr(3).strip_edges().replace("\\", "/")
		if " -> " in relative_path:
			relative_path = relative_path.get_slice(" -> ", 1)
		if relative_path.begins_with("docs/validation/screenshots/living-forge-foundation/") \
				or relative_path == "docs/verification/2026-08-28-living-forge-foundation-play-lobby.md":
			continue
		var absolute_path := repository_root.path_join(relative_path)
		if not FileAccess.file_exists(absolute_path):
			continue
		records.append({"status": status_code, "path": relative_path, "sha256": _sha256(FileAccess.get_file_as_bytes(absolute_path))})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.path) < String(right.path))
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		_assert(false, "source-tree fingerprint SHA-256 initializes")
		return {}
	for record: Dictionary in records:
		var status := String(record.status)
		var path := String(record.path)
		var file_hash := String(record.sha256)
		var canonical_line := "%d:%s%d:%s%d:%s\n" % [status.length(), status, path.length(), path, file_hash.length(), file_hash]
		if context.update(canonical_line.to_utf8_buffer()) != OK:
			_assert(false, "source-tree fingerprint hashes %s" % String(record.path))
			return {}
	var fingerprint := context.finish().hex_encode()
	_assert(not records.is_empty() and fingerprint.length() == 64, "source-tree fingerprint covers nonempty Task 9 inputs")
	return {
		"algorithm": "sha256",
		"method": "Sort git status --porcelain tracked/untracked Task 9 input paths; exclude generated evidence and verification; SHA-256 a length-prefixed status/path/file-SHA record stream.",
		"path_count": records.size(),
		"sha256": fingerprint,
		"inputs": records,
	}


func _image_is_nonblank(image: Image) -> bool:
	var first := image.get_pixel(0, 0)
	for y: int in range(0, image.get_height(), maxi(1, image.get_height() / 24)):
		for x: int in range(0, image.get_width(), maxi(1, image.get_width() / 24)):
			var sample := image.get_pixel(x, y)
			var delta := absf(sample.r - first.r) + absf(sample.g - first.g) + absf(sample.b - first.b) + absf(sample.a - first.a)
			if delta > 0.025:
				return true
	return false


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


func _mouse_motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - root.get_mouse_position()
	root.push_input(event, true)
	await process_frame


func _mouse_click(target: Control) -> void:
	await _mouse_motion(target.get_global_rect().get_center())
	var press := InputEventMouseButton.new()
	press.position = target.get_global_rect().get_center()
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _joy_button(button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = button
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventJoypadButton
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _release_focus() -> void:
	var owner := root.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("LIVING_FORGE_VISUAL_EVIDENCE_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LIVING_FORGE_VISUAL_EVIDENCE_FAILURE: %s" % failure)
	print("LIVING_FORGE_VISUAL_EVIDENCE_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)
