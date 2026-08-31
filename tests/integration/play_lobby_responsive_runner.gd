extends SceneTree

const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]
const MAX_WAIT_FRAMES := 45

var _failures: Array[String] = []
var _fixture_root := ""
var _desktop_card_size := Vector2.ZERO
var _scale_observations: Dictionary = {}


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_fixture_root = "user://tests/play_lobby_responsive/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var profile_root := _fixture_root.path_join("profiles")
	var settings_path := _fixture_root.path_join("settings.cfg")
	ProfileTestSupport.remove_tree(_fixture_root)
	var profile_id := _create_profile(profile_root)
	if profile_id.is_empty():
		_finish(null)
		return
	var save_settings_error := PartyForgeSettingsStore.new().save_settings(PartyForgeSettings.new(), settings_path)
	_assert(save_settings_error.is_empty(), "responsive fixture settings save")
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	var main_scene := load("res://scenes/game/main.tscn") as PackedScene
	_assert(main_scene != null, "production Main scene loads")
	if main_scene == null:
		_finish(null)
		return
	var main := main_scene.instantiate() as PartyForgeMain
	main.profile_root = profile_root
	main.settings_path = settings_path
	root.add_child(main)
	await _frames(5)
	await _mouse_click((main.get_node("MainMenuScreen") as MainMenuScreen).get_node("PrimaryAction") as Button)
	var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	_assert(lobby.is_open(), "real production route opens the Play lobby")
	await _mouse_click(lobby.selection_focus(&"fighter") as Button)
	_assert(lobby.selected_class_id() == &"fighter", "responsive fixture selects Fighter")
	await _assert_hero_success_and_fallback(main, lobby)

	for viewport_size: Vector2i in VIEWPORT_SIZES:
		await _apply_size_and_scales(main, lobby, viewport_size, 100, 100)
		await _assert_geometry(lobby, viewport_size, 100, 100, true)
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for text_scale: int in PartyForgeSettings.UI_SCALE_OPTIONS:
			await _apply_size_and_scales(main, lobby, viewport_size, 100, text_scale)
			await _assert_geometry(lobby, viewport_size, 100, text_scale, false)
		for ui_scale: int in PartyForgeSettings.UI_SCALE_OPTIONS:
			await _apply_size_and_scales(main, lobby, viewport_size, ui_scale, 100)
			await _assert_geometry(lobby, viewport_size, ui_scale, 100, false)
		for pair: Vector2i in [Vector2i(80, 150), Vector2i(150, 80), Vector2i(150, 150)]:
			await _apply_size_and_scales(main, lobby, viewport_size, pair.x, pair.y)
			await _assert_geometry(lobby, viewport_size, pair.x, pair.y, false)
	_assert_independent_scales()
	_finish(main)


func _create_profile(profile_root: String) -> String:
	var manager := ProfileManager.new()
	_assert(manager.bootstrap(profile_root).is_empty(), "responsive profile manager bootstraps")
	var created := manager.create_profile("Responsive Qualification")
	_assert(created.ok(), "responsive profile is created")
	if not created.ok():
		return ""
	var profile_id := created.profile.profile_id
	var completion := ProfileMutationService.new(ProfileStore.new()).complete_prologue(profile_id, "play-lobby-responsive-complete", profile_root)
	_assert(completion.ok(), "responsive profile completes prologue")
	var loaded := ProfileStore.new().load_profile(profile_id, profile_root)
	if not loaded.ok():
		_assert(false, "responsive profile reloads")
		return ""
	var profile := loaded.profile
	for unlock: String in ["bring_in_gear", "equipment_inventory", "stash"]:
		if unlock not in profile.permanent_feature_unlocks:
			profile.permanent_feature_unlocks.append(unlock)
	_assert(ProfileStore.new().save_profile(profile, profile_root).is_empty(), "responsive storage unlocks persist")
	return profile_id


func _apply_size_and_scales(main: PartyForgeMain, lobby: ClassSelectionPanel, viewport_size: Vector2i, ui_scale: int, text_scale: int) -> void:
	root.size = viewport_size
	main.saved_settings.ui_scale_percent = ui_scale
	main.saved_settings.text_scale_percent = text_scale
	main.call(&"_present_lobby")
	lobby.apply_viewport_size(Vector2(viewport_size))
	await _wait_for_layout(lobby, "layout %dx%d ui=%d text=%d" % [viewport_size.x, viewport_size.y, ui_scale, text_scale])
	var prompt := lobby.get_node("Content/Margin/Layout/Footer/InputPrompt") as ForgeInputPrompt
	_scale_observations["%dx%d:%d:%d" % [viewport_size.x, viewport_size.y, ui_scale, text_scale]] = {
		"font": prompt.get_theme_font_size(&"font_size"),
		"padding": lobby.theme.get_constant(&"panel_padding", &"LivingForgeMetrics"),
	}


func _assert_geometry(lobby: ClassSelectionPanel, viewport_size: Vector2i, ui_scale: int, text_scale: int, size_baseline: bool) -> void:
	var label := "%dx%d ui=%d text=%d" % [viewport_size.x, viewport_size.y, ui_scale, text_scale]
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var content := lobby.get_node("Content") as Control
	var margin := lobby.get_node("Content/Margin") as Control
	var body := lobby.get_node("Content/Margin/Layout/Body") as Control
	var footer := lobby.get_node("Content/Margin/Layout/Footer") as HBoxContainer
	var prompt := lobby.get_node("Content/Margin/Layout/Footer/InputPrompt") as ForgeInputPrompt
	var action_bar := lobby.get_node("Content/Margin/Layout/Footer/ActionBar") as ForgeActionBar
	var status := lobby.get_node("Content/Margin/Layout/Status") as Label
	var seats := lobby.get_node("Content/Margin/Layout/Body/LeftColumn/Seats") as GridContainer
	var roster_scroll := lobby.get_node("Content/Margin/Layout/Body/LeftColumn/ClassRoster/Scroll") as ScrollContainer
	var roster := lobby.get_node("Content/Margin/Layout/Body/LeftColumn/ClassRoster/Scroll/Grid") as GridContainer
	var details := lobby.get_node("Content/Margin/Layout/Body/Details") as ScrollContainer
	var selected := lobby.selection_focus(&"fighter") as ForgeClassCard
	var compatibility := lobby.get_node("Content/Margin/Layout/Body/Details/DetailContent/Compatibility") as Label
	var start := lobby.action_focus(&"start") as Button
	var p1_identity := seats.get_node("Seat_1/Content/Identity") as Label
	var expected_width := minf(float(viewport_size.x), RunSetupResponsiveLayout.MAX_CONTENT_WIDTH)
	var expected_content := Rect2(Vector2((float(viewport_size.x) - expected_width) * 0.5, 0.0), Vector2(expected_width, viewport_size.y))
	if not content.get_global_rect().grow(0.5).encloses(margin.get_global_rect()):
		var left := lobby.get_node("Content/Margin/Layout/Body/LeftColumn") as Control
		var hero := lobby.get_node("Content/Margin/Layout/Body/HeroStage") as Control
		print("PLAY_LOBBY_SCALE_DIAGNOSTIC %s content=%s margin=%s body_min=%s left_min=%s seats_min=%s roster_min=%s hero_min=%s details_min=%s footer_min=%s prompt_min=%s actions_min=%s" % [label, content.get_global_rect(), margin.get_global_rect(), body.get_combined_minimum_size(), left.get_combined_minimum_size(), seats.get_combined_minimum_size(), roster_scroll.get_combined_minimum_size(), hero.get_combined_minimum_size(), details.get_combined_minimum_size(), footer.get_combined_minimum_size(), prompt.get_combined_minimum_size(), action_bar.get_combined_minimum_size()])
		for seat_node: Node in seats.get_children():
			var seat := seat_node as Control
			print("PLAY_LOBBY_SEAT_DIAGNOSTIC %s seat=%s min=%s content=%s identity=%s ready=%s future=%s" % [label, seat.name, seat.get_combined_minimum_size(), (seat.get_node("Content") as Control).get_combined_minimum_size(), (seat.get_node("Content/Identity") as Label).get_combined_minimum_size(), (seat.get_node("Content/Ready") as Label).get_combined_minimum_size(), (seat.get_node("Content/FuturePlate") as Control).get_combined_minimum_size()])
	_assert_rect_near(content.get_global_rect(), expected_content, "bounded centered content %s" % label)
	_assert(viewport_rect.grow(0.5).encloses(content.get_global_rect()), "content remains inside viewport %s" % label)
	_assert(content.get_global_rect().grow(0.5).encloses(margin.get_global_rect()), "content margins remain contained %s" % label)
	_assert(margin.get_global_rect().grow(0.5).encloses(body.get_global_rect()), "body remains contained %s" % label)
	_assert(margin.get_global_rect().grow(0.5).encloses(footer.get_global_rect()), "fixed footer remains visible and contained %s" % label)
	_assert(margin.get_global_rect().grow(0.5).encloses(status.get_global_rect()), "status remains visible and contained %s" % label)
	_assert(body.get_global_rect().end.y <= footer.get_global_rect().position.y + 0.5, "body never overlaps fixed footer %s" % label)
	_assert(footer.get_global_rect().grow(0.5).encloses(prompt.get_global_rect()) and footer.get_global_rect().grow(0.5).encloses(action_bar.get_global_rect()), "one-row footer contains prompt and ActionBar %s" % label)
	_assert(prompt.focus_mode == Control.FOCUS_NONE and prompt.mouse_filter == Control.MOUSE_FILTER_IGNORE, "prompt remains passive %s" % label)
	_assert(seats.columns == (4 if viewport_size.x < 1600 or viewport_size.y < 900 else 2), "seat layout mode is correct %s" % label)
	var expected_roster_columns := (1 if viewport_size.x < 1600 or viewport_size.y < 900 else 2) if text_scale >= 125 else (2 if viewport_size.x < 1600 or viewport_size.y < 900 else 3)
	_assert(roster.columns == expected_roster_columns, "roster density mode is correct %s" % label)
	_assert(p1_identity.is_visible_in_tree() and not p1_identity.text.strip_edges().is_empty(), "selected profile remains visible %s" % label)
	var compact := viewport_size.x < 1600 or viewport_size.y < 900
	for index: int in seats.get_child_count():
		var seat := seats.get_child(index) as ForgeSeatCard
		var seat_rect := seat.get_global_rect().grow(0.5)
		var seat_heading := seat.get_node("Content/Seat") as Label
		_assert(seat_heading.is_visible_in_tree() and seat_rect.encloses(seat_heading.get_global_rect()), "P%d heading remains visible and contained %s" % [index + 1, label])
		if index == 0:
			var ready := seat.get_node("Content/Ready") as Label
			_assert(seat_rect.encloses(p1_identity.get_global_rect()) and seat_rect.encloses(ready.get_global_rect()), "P1 identity and prompt-ready line remain contained %s" % label)
			continue
		var future_identity := seat.get_node("Content/Identity") as Label
		var lock_shape := seat.find_child("LockShape", true, false) as TextureRect
		var availability := seat.find_child("Availability", true, false) as Label
		_assert(future_identity.is_visible_in_tree() == not compact, "future identity uses the intended density %s seat=P%d" % [label, index + 1])
		_assert(lock_shape.is_visible_in_tree() and seat_rect.encloses(lock_shape.get_global_rect()), "P%d lock icon remains visible and contained %s" % [index + 1, label])
		_assert(availability.is_visible_in_tree() and seat_rect.encloses(availability.get_global_rect()), "P%d Coming Soon label remains visible and contained %s" % [index + 1, label])
		_assert(availability.text == ForgeSeatCard.COMING_SOON_COPY, "P%d Coming Soon copy remains exact %s" % [index + 1, label])
	for child: Node in roster.get_children():
		_assert_class_card_bands(child as ForgeClassCard, label, text_scale, compact)
	_assert(selected.is_visible_in_tree() and (selected.get_node("SelectionNotch") as Control).is_visible_in_tree(), "selected class remains visible %s" % label)
	if viewport_size == Vector2i(1280, 720) and text_scale == 150 and ui_scale in [100, 150]:
		roster_scroll.ensure_control_visible(selected)
		await _frames(2)
		var roster_viewport_rect := roster_scroll.get_global_rect()
		var selected_rect := selected.get_global_rect()
		var clipped_rect := roster_viewport_rect.intersection(selected_rect)
		if not roster_viewport_rect.grow(0.5).encloses(selected_rect):
			var compact_seat := seats.get_child(1) as Control
			var compact_future := compact_seat.get_node("Content/FuturePlate") as Control
			var compact_copy := compact_seat.find_child("Availability", true, false) as Label
			print("PLAY_LOBBY_ATOMIC_CARD_DIAGNOSTIC %s seats=%s seat_min=%s content_min=%s future_min=%s copy_min=%s copy_size=%s" % [label, seats.get_global_rect(), compact_seat.get_combined_minimum_size(), (compact_seat.get_node("Content") as Control).get_combined_minimum_size(), compact_future.get_combined_minimum_size(), compact_copy.get_combined_minimum_size(), compact_copy.size])
		_assert(roster_viewport_rect.grow(0.5).encloses(selected_rect), "one complete selected class card fits the roster viewport %s viewport=%s card=%s clipped=%s" % [label, roster_viewport_rect, selected_rect, clipped_rect])
		_assert(clipped_rect.size.is_equal_approx(selected_rect.size), "selected class preview, identity, Selection, and Ready bands are atomically visible %s" % label)
	_assert(compatibility.is_visible_in_tree() and not compatibility.text.strip_edges().is_empty(), "compatibility remains visible %s" % label)
	_assert(start.is_visible_in_tree() and not start.disabled, "Start remains visible and authoritative %s" % label)
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		var action := lobby.action_focus(action_id) as Button
		_assert(action.size.x >= 48.0 and action.size.y >= 48.0, "%s action meets 48x48 floor %s" % [action_id, label])
		_assert(footer.get_global_rect().grow(0.5).encloses(action.get_global_rect()), "%s action is untruncated inside footer %s" % [action_id, label])
	var last_card := roster.get_child(roster.get_child_count() - 1) as Control
	roster_scroll.ensure_control_visible(last_card)
	details.ensure_control_visible(compatibility)
	await _frames(2)
	_assert(roster_scroll.get_global_rect().grow(1.0).intersects(last_card.get_global_rect()), "last roster card is reachable by scrolling %s" % label)
	_assert(details.get_global_rect().grow(1.0).intersects(compatibility.get_global_rect()), "compatibility detail is reachable by scrolling %s" % label)
	_assert_closed_focus_graph(lobby, label)
	if size_baseline and viewport_size == Vector2i(1920, 1080):
		_desktop_card_size = selected.get_global_rect().size
	if size_baseline and viewport_size == Vector2i(3840, 2160):
		_assert(selected.get_global_rect().size.is_equal_approx(_desktop_card_size), "4K retains 1080p class-card information density")


func _assert_class_card_bands(card: ForgeClassCard, label: String, text_scale: int, compact: bool) -> void:
	if card == null or not card.is_visible_in_tree():
		return
	var card_rect := card.get_global_rect().grow(0.5)
	var content := card.get_node("Content") as Control
	var portrait := card.get_node("Content/Portrait") as Control
	var identity := card.get_node("Content/Identity") as Control
	var name := card.get_node("Content/Identity/Name") as Label
	var expected_height := (128.0 if compact else 144.0) + maxf(0.0, roundf(float(text_scale - 100) * 0.64))
	_assert(card.size.y >= expected_height, "%s card uses deterministic text-scale height %s expected>=%.0f actual=%.0f" % [card.name, label, expected_height, card.size.y])
	_assert(card_rect.encloses(content.get_global_rect()) and card_rect.encloses(portrait.get_global_rect()) and card_rect.encloses(identity.get_global_rect()), "%s portrait and identity remain inside card bounds %s" % [card.name, label])
	_assert(not portrait.get_global_rect().intersects(identity.get_global_rect()), "%s portrait and identity never intersect %s" % [card.name, label])
	_assert(not name.clip_text and name.autowrap_mode != TextServer.AUTOWRAP_OFF, "%s title never clips or escapes its card %s" % [card.name, label])
	_assert(card_rect.encloses(name.get_global_rect()), "%s title rectangle stays contained %s" % [card.name, label])
	for layer_name: String in ["PreviewIndicator", "SelectionNotch", "CompatibilityBadge", "AttentionBadge"]:
		var layer := card.get_node(layer_name) as Control
		if layer.is_visible_in_tree():
			_assert(card_rect.encloses(layer.get_global_rect()), "%s %s remains inside card bounds %s" % [card.name, layer_name, label])
	var preview := card.get_node("PreviewIndicator") as Control
	for label_path: String in ["Content/Identity/Name", "Content/Identity/Role", "PreviewIndicator/Text", "SelectionNotch/Text", "CompatibilityBadge/Text", "AttentionBadge/Text"]:
		var scaled_label := card.get_node(label_path) as Label
		_assert(not scaled_label.has_theme_font_size_override(&"font_size"), "%s %s keeps theme-scaled card typography without local shrinking %s" % [card.name, label_path, label])
	if preview.is_visible_in_tree():
		var content_rect := (card.get_node("Content") as Control).get_global_rect()
		_assert(not content_rect.intersects(preview.get_global_rect()), "%s identity and Preview bands never intersect %s" % [card.name, label])
		_assert(preview.get_global_rect().position.x - content_rect.end.x >= 8.0, "%s identity and Preview bands keep an 8px horizontal gutter %s" % [card.name, label])
	var selection := card.get_node("SelectionNotch") as Control
	for state_name: String in ["CompatibilityBadge", "AttentionBadge"]:
		var state := card.get_node(state_name) as Control
		if selection.is_visible_in_tree() and state.is_visible_in_tree():
			_assert(not selection.get_global_rect().intersects(state.get_global_rect()), "%s Selection and %s bands never intersect %s" % [card.name, state_name, label])
			_assert(state.get_global_rect().position.x - selection.get_global_rect().end.x >= 8.0, "%s Selection and %s keep an 8px gutter %s" % [card.name, state_name, label])
	var role := card.get_node("Content/Identity/Role") as Label
	var visible_bottom_bands: Array[Control] = []
	for bottom_name: String in ["SelectionNotch", "CompatibilityBadge", "AttentionBadge"]:
		var bottom_band := card.get_node(bottom_name) as Control
		if bottom_band.is_visible_in_tree():
			visible_bottom_bands.append(bottom_band)
	for bottom_band: Control in visible_bottom_bands:
		_assert(not role.get_global_rect().intersects(bottom_band.get_global_rect()), "%s role and %s bands never intersect %s" % [card.name, bottom_band.name, label])
		_assert(bottom_band.get_global_rect().position.y - role.get_global_rect().end.y >= 8.0, "%s identity and %s bands keep an 8px gutter %s" % [card.name, bottom_band.name, label])
	if (card.get_node("CompatibilityBadge") as Control).is_visible_in_tree():
		_assert((card.get_node("CompatibilityBadge/Text") as Label).text == "READY", "%s production compatibility badge says READY %s" % [card.name, label])
	if (card.get_node("AttentionBadge") as Control).is_visible_in_tree():
		_assert((card.get_node("AttentionBadge/Text") as Label).text == "REVIEW", "%s production attention badge says REVIEW %s" % [card.name, label])


func _assert_closed_focus_graph(lobby: ClassSelectionPanel, label: String) -> void:
	var start := lobby.selection_focus(&"fighter") as Control
	var visited: Dictionary = {}
	var current := start
	for _step: int in 32:
		_assert(current != null and lobby.is_ancestor_of(current), "focus graph remains inside lobby %s" % label)
		if current == null:
			return
		_assert(current.is_visible_in_tree() and current.focus_mode != Control.FOCUS_NONE, "focus target remains visible and enabled %s node=%s" % [label, current.name])
		if current is BaseButton:
			_assert(not (current as BaseButton).disabled, "focus graph excludes disabled buttons %s node=%s" % [label, current.name])
		if visited.has(current.get_instance_id()):
			_assert(current == start, "focus graph closes at its first roster card %s" % label)
			return
		visited[current.get_instance_id()] = true
		var next_path := current.focus_next
		_assert(not next_path.is_empty(), "focus target has explicit next edge %s node=%s" % [label, current.name])
		if next_path.is_empty():
			return
		current = current.get_node_or_null(next_path) as Control
	_assert(false, "focus graph closes within 32 controls %s" % label)


func _assert_hero_success_and_fallback(main: PartyForgeMain, lobby: ClassSelectionPanel) -> void:
	var preview := lobby.get_node("Content/Margin/Layout/Body/HeroStage/Preview") as CharacterEquipmentPreview
	await _frames(3)
	_assert(preview.active_preview != null and not (preview.get_node("Fallback") as Control).visible, "live production Fighter hero renders successfully")
	preview.show_fallback(&"forced_evidence", "Preview safely unavailable.")
	await _frames(2)
	_assert(preview.active_preview == null and (preview.get_node("Fallback") as Control).is_visible_in_tree(), "forced missing-presentation path shows the neutral safe fallback")
	var fighter := main.catalog.class_by_id(&"fighter") if main.catalog != null else null
	_assert(preview.show_class(fighter), "live Fighter hero recovers after forced fallback")
	await _frames(2)
	_assert(preview.active_preview != null and not (preview.get_node("Fallback") as Control).visible, "recovered live hero replaces fallback")


func _assert_independent_scales() -> void:
	var base_theme := LivingForgeThemeCatalog.resolve(false, 100, 100)
	var combined_theme := LivingForgeThemeCatalog.resolve(false, 150, 150)
	var text_only_theme := LivingForgeThemeCatalog.resolve(false, 80, 150)
	var ui_only_theme := LivingForgeThemeCatalog.resolve(false, 150, 80)
	_assert(combined_theme.get_font_size(&"font_size", &"LivingForgePromptLabel") == text_only_theme.get_font_size(&"font_size", &"LivingForgePromptLabel"), "UI scale never multiplies text scale")
	_assert(combined_theme.get_constant(&"panel_padding", &"LivingForgeMetrics") == ui_only_theme.get_constant(&"panel_padding", &"LivingForgeMetrics"), "text scale never multiplies UI geometry scale")
	_assert(combined_theme.get_font_size(&"font_size", &"LivingForgePromptLabel") == roundi(float(base_theme.get_font_size(&"font_size", &"LivingForgePromptLabel")) * 1.5), "150 percent typography applies exactly once")


func _wait_for_layout(lobby: ClassSelectionPanel, description: String) -> void:
	var previous := PackedFloat32Array()
	var stable := 0
	for _frame: int in MAX_WAIT_FRAMES:
		await process_frame
		var body := lobby.get_node("Content/Margin/Layout/Body") as Control
		var footer := lobby.get_node("Content/Margin/Layout/Footer") as Control
		var signature := PackedFloat32Array([body.position.x, body.position.y, body.size.x, body.size.y, footer.position.y, footer.size.x, footer.size.y])
		if signature == previous and body.size.x > 0.0 and footer.size.x > 0.0:
			stable += 1
			if stable >= 2:
				return
		else:
			stable = 0
		previous = signature
	_failures.append("timed out waiting for %s" % description)


func _mouse_click(target: Control) -> void:
	var position := target.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.relative = position - root.get_mouse_position()
	root.push_input(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	root.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	root.push_input(release)
	await process_frame


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _assert_rect_near(actual: Rect2, expected: Rect2, label: String) -> void:
	_assert(actual.position.distance_to(expected.position) <= 0.5 and actual.size.distance_to(expected.size) <= 0.5, "%s expected=%s actual=%s" % [label, expected, actual])


func _finish(main: PartyForgeMain) -> void:
	if main != null and is_instance_valid(main):
		main.free()
	ProfileTestSupport.remove_tree(_fixture_root)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_fixture_root)):
		_failures.append("disposable responsive fixture root was not removed")
	if _failures.is_empty():
		print("PLAY_LOBBY_RESPONSIVE_SUMMARY: PASS (5 sizes)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PLAY_LOBBY_RESPONSIVE_FAILURE: %s" % failure)
	print("PLAY_LOBBY_RESPONSIVE_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
