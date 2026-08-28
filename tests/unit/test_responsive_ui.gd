extends RefCounted

const ResponsiveGeometry := preload("res://tests/support/responsive_geometry.gd")
const VIEWPORT_SIZES := [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0), Vector2(2560.0, 1440.0), Vector2(3840.0, 2160.0)]


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_project_display_contract(failures)
	_test_play_lobby_compositions(failures)
	_test_retained_overlay_contracts(failures)
	return failures


func _test_project_display_contract(failures: Array[String]) -> void:
	TestAssertions.equal(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 1920, "logical viewport width is 1920", failures)
	TestAssertions.equal(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 1080, "logical viewport height is 1080", failures)
	TestAssertions.equal(str(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items", "UI uses canvas_items stretch mode", failures)
	TestAssertions.equal(str(ProjectSettings.get_setting("display/window/stretch/aspect")), "keep", "UI preserves the 16:9 aspect ratio", failures)


func _test_play_lobby_compositions(failures: Array[String]) -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	var lobby: Variant = hud.get_node("ClassSelection")
	if lobby.scene_file_path != "res://scenes/ui/run_setup/run_setup_lobby_panel.tscn":
		failures.append("responsive HUD instances the full-screen lobby scene")
		hud.free()
		return
	lobby.configure(GameCatalog.load_defaults())
	TestAssertions.equal(Vector4(lobby.anchor_left, lobby.anchor_top, lobby.anchor_right, lobby.anchor_bottom), Vector4(0.0, 0.0, 1.0, 1.0), "Play lobby fills the viewport", failures)
	TestAssertions.equal(Vector4(lobby.offset_left, lobby.offset_top, lobby.offset_right, lobby.offset_bottom), Vector4.ZERO, "Play lobby has no fixed outer offsets", failures)
	var seats := lobby.find_child("Seats", true, false) as GridContainer
	var roster := lobby.find_child("ClassRoster", true, false) as Control
	var roster_scroll := roster.find_child("Scroll", true, false) as ScrollContainer if roster != null else null
	var roster_grid := roster.find_child("Grid", true, false) as GridContainer if roster != null else null
	var hero := lobby.find_child("HeroStage", true, false) as Control
	var details := lobby.find_child("Details", true, false) as ScrollContainer
	var action_bar := lobby.find_child("ActionBar", true, false) as Control
	var status := lobby.find_child("Status", true, false) as Label
	TestAssertions.truthy(roster_scroll != null and roster_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "class roster is vertically scrollable", failures)
	TestAssertions.truthy(details != null and details.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "details are scrollable", failures)
	TestAssertions.truthy(action_bar != null and roster_scroll != null and not action_bar.is_ancestor_of(roster_scroll), "fixed footer is outside scrolling content", failures)
	TestAssertions.truthy(status != null and status.autowrap_mode != TextServer.AUTOWRAP_OFF, "status copy wraps", failures)
	if seats == null or roster_grid == null or hero == null:
		failures.append("responsive lobby composition is complete")
		hud.free()
		return

	lobby.apply_viewport_size(Vector2(1920.0, 1080.0))
	var desktop_hero_minimum := hero.custom_minimum_size
	var desktop_card_minimum := (roster_grid.get_child(0) as Control).custom_minimum_size if roster_grid.get_child_count() > 0 else Vector2.ZERO
	TestAssertions.equal(seats.columns, 2, "desktop uses a 2 by 2 seat board", failures)
	TestAssertions.equal(roster_grid.columns, 3, "desktop uses a three-column class roster", failures)

	lobby.apply_viewport_size(Vector2(1280.0, 720.0))
	TestAssertions.equal(seats.columns, 4, "compact uses a horizontal four-seat strip", failures)
	TestAssertions.equal(roster_grid.columns, 2, "compact uses a two-column class roster", failures)
	TestAssertions.truthy(hero.custom_minimum_size.x < desktop_hero_minimum.x and hero.custom_minimum_size.y < desktop_hero_minimum.y, "compact reduces the hero stage", failures)

	lobby.apply_viewport_size(Vector2(3840.0, 2160.0))
	var content := lobby.find_child("Content", true, false) as Control
	TestAssertions.equal(content.offset_right - content.offset_left, RunSetupResponsiveLayout.MAX_CONTENT_WIDTH, "4K content width remains bounded to 1920 logical pixels", failures)
	TestAssertions.equal(roster_grid.columns, 3, "4K preserves desktop information density", failures)
	if roster_grid.get_child_count() > 0:
		TestAssertions.equal((roster_grid.get_child(0) as Control).custom_minimum_size, desktop_card_minimum, "4K does not inflate class-card density", failures)
	TestAssertions.equal(roster_grid.get_child_count(), GameCatalog.load_defaults().classes.size(), "responsive modes retain every class", failures)
	for viewport_size: Vector2 in VIEWPORT_SIZES:
		lobby.apply_viewport_size(viewport_size)
		var content_rect := ResponsiveGeometry.control_rect(content, Rect2(Vector2.ZERO, viewport_size))
		TestAssertions.truthy(ResponsiveGeometry.contains(Rect2(Vector2.ZERO, viewport_size), content_rect), "lobby content remains contained at %s" % viewport_size, failures)
	hud.free()


func _test_retained_overlay_contracts(failures: Array[String]) -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	var boss_banner := hud.get_node("BossBanner") as Control
	var level_up := hud.get_node("LevelUpPanel") as Control
	var result_root := hud.get_node("RunResultPanel") as Control
	_assert_full_rect(level_up, "level-up modal root", failures)
	_assert_full_rect(result_root, "run result overlay", failures)
	TestAssertions.equal(Vector4(boss_banner.anchor_left, boss_banner.anchor_top, boss_banner.anchor_right, boss_banner.anchor_bottom), Vector4(0.5, 0.0, 0.5, 0.0), "boss banner keeps center-top anchors", failures)
	TestAssertions.truthy(level_up.get_node_or_null("ContentPanel/OfferView") is ScrollContainer, "level-up offers remain scrollable", failures)
	hud.free()


func _assert_full_rect(control: Control, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom), Vector4(0.0, 0.0, 1.0, 1.0), "%s anchors cover its parent" % label, failures)
	TestAssertions.equal(Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom), Vector4.ZERO, "%s has no edge offsets" % label, failures)
