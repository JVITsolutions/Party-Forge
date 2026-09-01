extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const LEVEL_UP_SCENE := preload("res://scenes/ui/level_up_panel.tscn")
const EXTRACTION_SCENE := preload("res://scenes/ui/run_result/terminal_extraction_panel.tscn")
const RESULT_SCENE := preload("res://scenes/ui/run_result_panel.tscn")
const EXTRACTION_ITEM_TYPE := preload("res://scripts/ui/run_result/terminal_extraction_item_projection.gd")
const EXTRACTION_PROJECTION_TYPE := preload("res://scripts/ui/run_result/terminal_extraction_projection.gd")
const RESULT_FIXTURE_TYPE := preload("res://tests/unit/test_run_recap_projection.gd")
const RESULT_VIEW_MODEL_TYPE := preload("res://scripts/ui/run_result/run_result_view_model.gd")

const SETTINGS_MATRIX: Array[Dictionary] = [
	{"label": "normal default", "high_contrast": false, "reduced_motion": false, "ui": 100, "text": 100},
	{"label": "high contrast", "high_contrast": true, "reduced_motion": false, "ui": 100, "text": 100},
	{"label": "reduced motion", "high_contrast": false, "reduced_motion": true, "ui": 100, "text": 100},
	{"label": "UI 150", "high_contrast": false, "reduced_motion": false, "ui": 150, "text": 100},
	{"label": "text 150", "high_contrast": false, "reduced_motion": false, "ui": 100, "text": 150},
	{"label": "UI 150 text 150", "high_contrast": false, "reduced_motion": false, "ui": 150, "text": 150},
	{"label": "UI 80 text 150", "high_contrast": false, "reduced_motion": false, "ui": 80, "text": 150},
	{"label": "high contrast UI 150 text 150", "high_contrast": true, "reduced_motion": false, "ui": 150, "text": 150},
	{"label": "high contrast UI 80 text 150", "high_contrast": true, "reduced_motion": false, "ui": 80, "text": 150},
]


class TestRun:
	extends Node

	func elapsed_time() -> float:
		return 92.0


var _failures: Array[String] = []
var _semantic_baseline: Dictionary = {}
var _sequence := 13000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for row: Dictionary in SETTINGS_MATRIX:
		await _exercise_matrix_row(row)
	_finish()


func _exercise_matrix_row(row: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var settings := _settings(row)
	var label := String(row["label"])
	await _exercise_hud(viewport, settings, label)
	await _exercise_level_up(viewport, settings, label)
	await _exercise_extraction(viewport, settings, label)
	await _exercise_results(viewport, settings, label)
	viewport.free()
	await process_frame


func _exercise_hud(viewport: SubViewport, settings: PartyForgeSettings, label: String) -> void:
	var fixture := _hud_fixture(24)
	for member_id: int in range(2, 8):
		(fixture.health_by_member[member_id] as HealthComponent).apply_damage(80.0)
	var hud := HUD_SCENE.instantiate() as HUD
	hud.custom_viewport = viewport
	viewport.add_child(hud)
	(hud.get_node("ClassSelection") as ClassSelectionPanel).close()
	hud.configure(fixture.run, fixture.party, fixture.experience, fixture.context, settings)
	var shell := hud.get_node("Margin/CombatStatus") as Control
	var overflow := hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	if not await _wait_until(
		func() -> bool: return hud.current_projection != null and overflow.visible and shell.get_global_rect().size.x > 0.0,
		"HUD projection, overflow alerts, and layout at %s" % label,
	):
		hud.free()
		_cleanup_hud_fixture(fixture)
		return
	_assert(shell.theme == LivingForgeThemeCatalog.resolve(settings.high_contrast, settings.ui_scale_percent, settings.text_scale_percent), "HUD uses the shared resolved theme at %s" % label)
	_assert(overflow.visible and not overflow.disabled, "HUD exposes overflow alerts at %s" % label)
	_assert_named_action(overflow, "combat alerts", "HUD overflow", label)
	await _assert_visible_focus(overflow, "HUD overflow", label)

	var next := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
	var page_guard := 0
	while not next.disabled and page_guard < 30:
		var prior_page_text := (hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageStatus") as Label).text
		next.pressed.emit()
		page_guard += 1
		if not await _wait_until(
			func() -> bool: return next.disabled or (hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageStatus") as Label).text != prior_page_text,
			"HUD compact page advance %d at %s" % [page_guard, label],
		):
			break
	var final_member := _hud_member(hud, 24)
	_assert(final_member != null, "HUD paging reaches member 24 at %s" % label)
	if final_member != null:
		_assert(final_member.accessibility_name.contains("Member 24"), "HUD member 24 uses production identity wording at %s" % label)
		_assert_member_semantics(final_member, "HUD member 24", label)
		await _assert_visible_focus(final_member, "HUD member 24", label)
		_assert(hud.open_inspector_for_member(24, final_member), "HUD member 24 opens the production inspector at %s" % label)
		var inspector := hud.get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel
		var close := inspector.get_node("Overlay/Frame/Layout/Close") as Button
		await _wait_until(func() -> bool: return inspector.visible and close.has_focus(), "HUD inspector open focus at %s" % label)
		_assert_named_action(close, "close", "HUD inspector close", label)
		close.pressed.emit()
		await _wait_until(func() -> bool: return not inspector.visible and final_member.has_focus(), "HUD inspector exact return focus at %s" % label)
		_assert(final_member.has_focus(), "HUD inspector restores exact member 24 focus at %s" % label)

	overflow.grab_focus()
	overflow.pressed.emit()
	var tray := hud.get_node("CombatAlertTray") as CombatAlertTray
	await _wait_until(func() -> bool: return tray.visible and _focus_within(tray.get_node("Overlay") as Control, viewport), "HUD alert tray open focus at %s" % label)
	_assert(tray.visible, "HUD complete alert tray opens at %s" % label)
	var tray_close := tray.get_node("Overlay/Frame/Layout/Close") as Button
	_assert_named_action(tray_close, "close", "HUD alert tray close", label)
	tray_close.pressed.emit()
	await _wait_until(func() -> bool: return not tray.visible and overflow.has_focus(), "HUD alert tray exact return focus at %s" % label)
	_assert(overflow.has_focus(), "HUD alert tray restores exact overflow focus at %s" % label)

	var visible_alert := hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts").get_child(0) as ForgeAlertCard
	_assert_alert_semantics(visible_alert, "HUD critical alert", label)
	_assert_surface_controls(hud, "HUD", label)
	_assert_hidden_or_disabled_excluded(shell, "HUD combat shell", label)
	await _assert_navigation_skips_excluded(shell, viewport, overflow, "HUD combat shell", label)
	_assert_semantic_parity("hud-member", _member_semantic_signature(final_member), label)
	_assert_semantic_parity("hud-alert", _alert_semantic_signature(visible_alert), label)

	var party_header := hud.get_node("Margin/CombatStatus/PartyHeader") as Button
	var alerts_header := hud.get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	_assert(party_header.accessibility_description == "Party region is EXPANDED. Activate to COLLAPSE party details.", "expanded Party header exposes exact state/action description at %s" % label)
	_assert(alerts_header.accessibility_description == "Alerts region is EXPANDED. Activate to COLLAPSE alert details.", "expanded Alerts header exposes exact state/action description at %s" % label)
	for icon_path: NodePath in [^"Content/StateIcon", ^"../AlertRegion/Header/Content/StateIcon"]:
		var severity_icon := party_header.get_node(icon_path) as TextureRect
		var icon_material := severity_icon.material as ShaderMaterial
		_assert(severity_icon.visible and icon_material != null and icon_material.shader != null, "HUD severity icon uses a visible alpha-mask material at %s path=%s" % [label, icon_path])
		_assert(icon_material != null and (icon_material.get_shader_parameter(&"icon_color") as Color).is_equal_approx(LivingForgeTokens.color(&"error", settings.high_contrast)), "HUD severity icon uses the semantic error token at %s path=%s" % [label, icon_path])
	var party_roots: Array[Control] = [
		hud.get_node("Margin/CombatStatus/LeaderCard") as Control,
		hud.get_node("Margin/CombatStatus/Experience") as Control,
		hud.get_node("Margin/CombatStatus/PartyRegion") as Control,
	]
	var focused_party_member_id := int(final_member.get_meta(&"member_id", 0))
	final_member.grab_focus()
	final_member = null
	party_header.pressed.emit()
	await process_frame
	_assert(party_header.has_focus(), "collapsed Party moves hidden descendant focus to its accessible header at %s" % label)
	_assert(party_header.accessibility_description == "Party region is COLLAPSED. Activate to EXPAND party details.", "collapsed Party header exposes exact state/action description at %s" % label)
	for party_root: Control in party_roots:
		_assert(_focus_modes_none(party_root), "collapsed Party descendants are unreachable at %s root=%s" % [label, party_root.name])
		_assert(_accessible_exposure(party_root).is_empty(), "collapsed Party descendants are absent from the accessibility exposure helper at %s root=%s" % [label, party_root.name])
	party_header.pressed.emit()
	await process_frame
	var rebuilt_final_member := _hud_member(hud, focused_party_member_id)
	var rebuilt_focus_owner := viewport.gui_get_focus_owner() as Control
	_assert(rebuilt_final_member != null and rebuilt_focus_owner == rebuilt_final_member and rebuilt_focus_owner.is_in_group(&"combat_hud_member") and int(rebuilt_focus_owner.get_meta(&"member_id", 0)) == focused_party_member_id, "expanded Party restores viewport focus to the rebuilt accessible member at %s" % label)

	var inspect := visible_alert.get_node("Surface/Content/Actions/Inspect") as Button
	inspect.grab_focus()
	alerts_header.pressed.emit()
	await process_frame
	_assert(alerts_header.has_focus(), "collapsed Alerts moves hidden descendant focus to its accessible header at %s" % label)
	_assert(alerts_header.accessibility_description == "Alerts region is COLLAPSED. Activate to EXPAND alert details.", "collapsed Alerts header exposes exact state/action description at %s" % label)
	_assert(_focus_modes_none(hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control), "collapsed Alerts descendants are unreachable at %s" % label)
	_assert(_accessible_exposure(hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control).is_empty(), "collapsed Alerts descendants are absent from the accessibility exposure helper at %s" % label)
	alerts_header.pressed.emit()
	await process_frame
	_assert(inspect.has_focus(), "expanded Alerts restores exact accessible action focus at %s" % label)
	var party_tween := _disclosure_tween_for(hud, &"party")
	if settings.reduced_motion:
		_assert(party_tween == null and is_equal_approx((party_header.get_node("Content/DisclosureGlyph/RotatingGlyph") as Label).rotation, PI / 2.0), "reduced-motion HUD disclosure has no active Tween and reaches final glyph state at %s" % label)
	else:
		_assert(party_tween != null and party_tween.is_valid(), "normal-motion HUD disclosure uses a glyph-only Tween at %s" % label)
	for member_id: int in range(2, 8):
		(fixture.health_by_member[member_id] as HealthComponent).heal(100.0)
	await process_frame
	for clear_path: NodePath in [^"Content/AllClearGlyph", ^"../AlertRegion/Header/Content/AllClearGlyph"]:
		var clear_glyph := party_header.get_node(clear_path) as Label
		_assert(clear_glyph.visible and clear_glyph.get_theme_color(&"font_color").is_equal_approx(LivingForgeTokens.color(&"valid", settings.high_contrast)), "HUD all-clear glyph uses the semantic valid token at %s path=%s" % [label, clear_path])
	(fixture.health_by_member[1] as HealthComponent).kill()
	party_header.pressed.emit()
	await process_frame
	var zero_health_cluster := party_header.get_node("Content/LeaderHealthCluster") as Control
	var zero_health_bar := zero_health_cluster.get_node("Bar") as ProgressBar
	var zero_health_value := zero_health_cluster.get_node("Value") as Label
	var zero_track := zero_health_bar.get_theme_stylebox(&"background") as StyleBoxFlat
	var header_style := party_header.get_theme_stylebox(&"normal") as StyleBoxFlat
	var expected_track_width := 2 if settings.high_contrast else 1
	_assert(is_zero_approx(zero_health_bar.value) and zero_health_value.text == "0 / 100", "collapsed zero-health HUD exposes exact text without fake fill at %s" % label)
	_assert(zero_health_cluster.get_global_rect().encloses(zero_health_bar.get_global_rect()) and zero_health_cluster.get_global_rect().encloses(zero_health_value.get_global_rect()), "collapsed zero-health bar and text remain contained at %s" % label)
	_assert(not zero_health_bar.get_global_rect().intersection(zero_health_value.get_global_rect()).has_area(), "collapsed zero-health text never overlaps the track at %s" % label)
	_assert(zero_track != null and zero_track.border_width_left == expected_track_width and zero_track.border_width_top == expected_track_width and zero_track.border_width_right == expected_track_width and zero_track.border_width_bottom == expected_track_width, "collapsed zero-health track exposes the required outline width at %s" % label)
	_assert(zero_track != null and header_style != null and _contrast_ratio(zero_track.border_color, header_style.bg_color) >= 3.0, "collapsed zero-health track remains distinguishable from its actual header surface at %s" % label)

	hud.free()
	_cleanup_hud_fixture(fixture)
	await process_frame


func _exercise_level_up(viewport: SubViewport, settings: PartyForgeSettings, label: String) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := _party(24, catalog, "Member")
	var panel := LEVEL_UP_SCENE.instantiate() as LevelUpPanel
	viewport.add_child(panel)
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	panel.configure_visual_settings(settings)
	var choices: Array[UpgradeChoice] = [
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"fleetfoot")),
	]
	panel.show_choices(choices, party)
	var first_card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards/Card1") as UpgradeCard
	if not await _wait_until(
		func() -> bool: return first_card.visible and not first_card.bound_choice_key().is_empty() and first_card.get_global_rect().size.x > 0.0,
		"level-up final offer binding and layout at %s" % label,
	):
		panel.free()
		party.free()
		return
	if settings.reduced_motion:
		if not await _wait_until(func() -> bool: return first_card.has_focus(), "reduced-motion immediate level-up focus at %s" % label):
			panel.free()
			party.free()
			return
		_assert(first_card.has_focus(), "reduced motion reveals final level-up offers immediately at %s" % label)
	elif not first_card.has_focus():
		var reveal := panel.get_node("RevealController") as LevelUpRevealController
		if not await _wait_until(func() -> bool: return reveal.is_revealing(), "default-motion level-up reveal start at %s" % label):
			panel.free()
			party.free()
			return
		# Exact authentic reveal-skip action and frame order from the production geometry runner.
		await _action(viewport, &"ui_cancel")
		if not await _wait_until(func() -> bool: return first_card.has_focus(), "default-motion skipped level-up focus at %s" % label):
			panel.free()
			party.free()
			return
	_assert(first_card.has_focus(), "level-up establishes a visible first-offer focus at %s" % label)
	_assert_named_action(first_card, "Vanguard", "level-up first offer", label)
	await _assert_visible_focus(first_card, "level-up first offer", label)

	var targeted_card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards/Card2") as UpgradeCard
	targeted_card.pressed.emit()
	var recipients := panel.get_node("Frame/Content/Recipient/Content/RecipientsScroll/Rows") as VBoxContainer
	if not await _wait_until(func() -> bool: return recipients.is_visible_in_tree() and recipients.get_node_or_null("Member_24") != null, "level-up recipient 24 presentation at %s" % label):
		panel.free()
		party.free()
		return
	var final_recipient := recipients.get_node_or_null("Member_24") as Button
	_assert(final_recipient != null and final_recipient.visible, "level-up exposes member 24 in the production recipient picker at %s" % label)
	_assert_named_action(final_recipient, "Member 24", "level-up member 24 recipient", label)
	await _assert_visible_focus(final_recipient, "level-up member 24 recipient", label)
	final_recipient.pressed.emit()
	var cancel := panel.get_node("Frame/Content/Confirmation/Actions/Cancel") as Button
	var confirm := panel.get_node("Frame/Content/Confirmation/Actions/Confirm") as Button
	await _wait_until(func() -> bool: return cancel.is_visible_in_tree() and (cancel.has_focus() or confirm.has_focus()), "level-up confirmation default focus at %s" % label)
	_assert(cancel.has_focus() and not confirm.has_focus(), "level-up confirmation defaults only to safe Back to Offers, never consequential Confirm, at %s" % label)
	_assert_named_action(cancel, "Back to Offers", "level-up safe confirmation return", label)
	_assert_named_action(confirm, "Confirm", "level-up confirmation", label)
	cancel.pressed.emit()
	await _wait_until(func() -> bool: return targeted_card.is_visible_in_tree() and targeted_card.has_focus(), "level-up exact offer return focus at %s" % label)
	_assert(targeted_card.has_focus(), "level-up confirmation cancel restores the exact initiating offer at %s" % label)
	_assert_hidden_or_disabled_excluded(panel, "level-up", label)
	await _assert_navigation_skips_excluded(panel, viewport, targeted_card, "level-up", label)
	_assert_surface_controls(panel, "level-up", label)
	_assert_semantic_parity("level-up", _level_up_semantic_signature(first_card), label)

	panel.free()
	party.free()
	await process_frame


func _exercise_extraction(viewport: SubViewport, settings: PartyForgeSettings, label: String) -> void:
	var panel := EXTRACTION_SCENE.instantiate() as TerminalExtractionPanel
	viewport.add_child(panel)
	panel.apply_visual_settings(settings)
	var projection := _extraction_projection(24, 2, 8)
	panel.present(projection)
	if not await _wait_until(func() -> bool: return panel.visible and _extraction_cards(panel).size() == 24 and (panel.get_node("Frame") as Control).get_global_rect().size.x > 0.0, "extraction item matrix and layout at %s" % label):
		panel.free()
		return
	var cards := _extraction_cards(panel)
	_assert(cards.size() == 24, "extraction exposes all 24 eligible items at %s" % label)
	if cards.is_empty():
		panel.free()
		return
	var last := cards[-1]
	_assert(String(last.get_meta(&"item_id", "")) == "item-24", "extraction final item keeps canonical identity at %s" % label)
	_assert_named_action(last, "Twin Band", "extraction final item", label)
	_assert_extraction_semantics(last, "extraction final item", label)
	await _assert_visible_focus(last, "extraction final item", label)
	panel.show_detail(projection.eligible_items[-1], last)
	var detail_close := panel.get_node("ItemTooltipDetail/Frame/Tooltip/Layout/Header/Close") as Button
	await _wait_until(func() -> bool: return detail_close.is_visible_in_tree() and detail_close.has_focus(), "extraction detail open focus at %s" % label)
	_assert_named_action(detail_close, "back", "extraction detail close", label)
	detail_close.pressed.emit()
	await _wait_until(func() -> bool: return not detail_close.is_visible_in_tree() and last.has_focus(), "extraction detail exact return focus at %s" % label)
	_assert(last.has_focus(), "extraction detail restores exact item 24 focus at %s" % label)

	panel.show_unused_capacity_warning(1, 22, last)
	var warning_title := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Title") as Label
	var warning_message := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Message") as Label
	var back := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Back") as Button
	var accept := panel.get_node("UnusedCapacityWarning/Frame/Padding/Layout/Actions/Acknowledge") as Button
	await _wait_until(func() -> bool: return back.is_visible_in_tree() and (back.has_focus() or accept.has_focus()), "extraction consequence default focus at %s" % label)
	_assert(warning_title.accessibility_name == "ACCEPT UNUSED CAPACITY?", "extraction consequence title exposes exact accessible wording at %s" % label)
	_assert(warning_message.accessibility_name == "You are leaving 1 extraction slots unused. 22 items will be lost.", "extraction consequence body exposes exact accessible wording at %s" % label)
	_assert_named_action(back, "Back", "extraction consequence safe action", label)
	_assert_named_action(accept, "Accept Consequence", "extraction consequence primary action", label)
	_assert(back.has_focus(), "extraction consequence confirmation uses safe Back default at %s" % label)
	_assert(not accept.has_focus(), "extraction consequence action is never default-focused at %s" % label)
	back.pressed.emit()
	await _wait_until(func() -> bool: return not back.is_visible_in_tree() and last.has_focus(), "extraction consequence exact return focus at %s" % label)
	_assert(last.has_focus(), "extraction consequence cancel restores exact item 24 focus at %s" % label)

	panel.set_pending(true)
	await _wait_until(func() -> bool: return (_extraction_cards(panel)[0] as Button).disabled and (panel.get_node("Frame/Content/Actions/Confirm") as Button).disabled, "extraction pending availability at %s" % label)
	_assert_hidden_or_disabled_excluded(panel, "pending extraction", label)
	await _assert_navigation_skips_excluded(panel, viewport, null, "pending extraction", label, false)
	panel.set_pending(false)
	await _wait_until(func() -> bool: return not (_extraction_cards(panel)[0] as Button).disabled and not (panel.get_node("Frame/Content/Actions/Confirm") as Button).disabled, "extraction availability restored at %s" % label)
	_assert_surface_controls(panel, "extraction", label)
	_assert_semantic_parity("extraction", _extraction_semantic_signature(last), label)

	panel.free()
	await process_frame


func _exercise_results(viewport: SubViewport, settings: PartyForgeSettings, label: String) -> void:
	var fixtures: Variant = RESULT_FIXTURE_TYPE.new()
	var view_model: Variant = RESULT_VIEW_MODEL_TYPE.new()
	var fixture: Dictionary = fixtures.call(&"_fixture", 24, 26, RunTerminalSnapshot.Outcome.VICTORY)
	var build_result: Variant = view_model.call(&"build", fixture.snapshot, fixture.resolution, fixture.profile, [])
	_assert(bool(build_result.call(&"ok")), "result projection builds from durable truth at %s" % label)
	if not bool(build_result.call(&"ok")):
		return
	var finalized := (build_result.get("projection") as RunResultProjection).with_visual_settings(settings)
	var panel := RESULT_SCENE.instantiate() as RunResultPanel
	viewport.add_child(panel)
	panel.present(finalized)
	var return_to_forge := panel.get_node("Frame/Content/Footer/Actions/ReturnToForge") as Button
	var restart := panel.get_node("Frame/Content/Footer/Actions/RestartRun") as Button
	var quit_action := panel.get_node("Frame/Content/Footer/Actions/QuitApplication") as Button
	await _wait_until(func() -> bool: return panel.visible and return_to_forge.has_focus() and _result_rows(panel).size() >= 50, "final result recap and safe focus at %s" % label)
	_assert(return_to_forge.has_focus(), "final result defaults to safe Return to Forge at %s" % label)
	_assert(not restart.has_focus() and not quit_action.has_focus(), "final result never defaults to Restart or Quit at %s" % label)
	for action: Button in [restart, return_to_forge, quit_action]:
		_assert_named_action(action, action.text, "result action", label)
	var recap_rows := _result_rows(panel)
	_assert(recap_rows.size() >= 50, "long result recap keeps party and loot rows reachable at %s" % label)
	if not recap_rows.is_empty():
		var last := recap_rows[-1]
		await _assert_visible_focus(last, "final result recap row", label)
		_assert_result_overlay_accessibility(panel, last, settings, label)
		var body := panel.get_node("Frame/Content/Body") as ScrollContainer
		await _wait_until(func() -> bool: return _scroll_visible_global_rect(body).encloses(last.get_global_rect()), "focused final presented result row fully enclosed by the Frame/Content/Body visible clip at %s" % label)

	var automatic_evaluation := RunResolutionEvaluation.create(fixture.resolution.accepted_extraction, 2, 0, 0, "automatic-only blocked", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need more destination space.")
	var preflight := RunResolutionPreflightResult.from_evaluation(automatic_evaluation)
	var guarded_result: Variant = view_model.call(&"resolution_interrupted", fixture.snapshot, preflight.player_reason, _durable_safety(fixture.snapshot), preflight)
	_assert(bool(guarded_result.call(&"ok")), "guarded result projection builds from a durable RESOLUTION_INTERRUPTED record at %s" % label)
	if not bool(guarded_result.call(&"ok")):
		panel.free()
		return
	var guarded := (guarded_result.get("projection") as RunResultProjection).with_visual_settings(settings)
	panel.present(guarded)
	var protect := panel.get_node("Frame/Content/Footer/Actions/ProtectDisplacedGear") as Button
	await _wait_until(func() -> bool: return protect.is_visible_in_tree() and protect.has_focus(), "guarded result protection focus at %s" % label)
	protect.pressed.emit()
	var cancel := panel.get_node("Frame/Content/Confirmation/Content/Actions/Cancel") as Button
	var confirm := panel.get_node("Frame/Content/Confirmation/Content/Actions/Confirm") as Button
	await _wait_until(func() -> bool: return cancel.is_visible_in_tree() and (cancel.has_focus() or confirm.has_focus()), "result protection confirmation focus at %s" % label)
	_assert(cancel.has_focus() and not confirm.has_focus(), "result protection confirmation uses safe Cancel default at %s" % label)
	for background: Button in _result_actions(panel):
		_assert(background.disabled and background.focus_mode == Control.FOCUS_NONE, "result confirmation excludes background %s from focus at %s" % [background.name, label])
	await _assert_navigation_skips_excluded(panel.get_node("Frame/Content/Confirmation") as Control, viewport, cancel, "result protection confirmation", label)
	cancel.pressed.emit()
	await _wait_until(func() -> bool: return not cancel.is_visible_in_tree() and protect.has_focus(), "result protection exact return focus at %s" % label)
	_assert(protect.has_focus(), "result confirmation restores exact Protect action focus at %s" % label)
	_assert_hidden_or_disabled_excluded(panel, "results", label)
	_assert_surface_controls(panel, "results", label)
	_assert_semantic_parity("results", _result_semantic_signature(panel, guarded), label)

	panel.free()
	await process_frame


func _assert_result_overlay_accessibility(panel: RunResultPanel, row: Button, settings: PartyForgeSettings, label: String) -> void:
	var primary := row.get_node_or_null("Primary") as Control
	_assert(primary != null and primary.is_visible_in_tree(), "results expose one visible Primary overlay at %s" % label)
	if primary == null:
		return
	var primary_text := String(primary.get("text"))
	_assert(row.text.is_empty(), "result native Button text is empty so AccessKit receives no appended duplicate text at %s" % label)
	_assert(row.accessibility_name == primary_text.replace("   ", ": "), "result row owns one exact accessibility name matching the visible Primary at %s" % label)
	_assert(primary.accessibility_name.strip_edges().is_empty(), "result Primary overlay does not duplicate the row accessibility name at %s" % label)
	var accessibility_element := primary.get_accessibility_element()
	if AccessibilityServer.is_supported():
		_assert(accessibility_element.is_valid() and AccessibilityServer.has_element(accessibility_element), "result Primary participates in the enabled real accessibility tree at %s; valid=%s registered=%s" % [label, accessibility_element.is_valid(), AccessibilityServer.has_element(accessibility_element) if accessibility_element.is_valid() else false])
	else:
		_assert(not accessibility_element.is_valid(), "disabled accessibility support publishes no untracked Primary element at %s" % label)
	_assert(primary is Container and not primary is Label, "result Primary publishes only an ignored ROLE_CONTAINER visual primitive, never ROLE_STATIC_TEXT, at %s" % label)
	var expected_theme := LivingForgeThemeCatalog.resolve(settings.high_contrast, settings.ui_scale_percent, settings.text_scale_percent)
	_assert(primary.get_theme_font(&"font") == expected_theme.get_font(&"font", row.theme_type_variation), "result Primary uses the resolved Living Forge Button font at %s" % label)
	_assert(primary.get_theme_font_size(&"font_size") == expected_theme.get_font_size(&"font_size", row.theme_type_variation), "result Primary uses the resolved Living Forge Button font size at %s" % label)
	var expected_primary_color := expected_theme.get_color(&"font_color", row.theme_type_variation) if expected_theme.has_color(&"font_color", row.theme_type_variation) else expected_theme.get_color(&"font_color", &"Button")
	_assert(primary.get_theme_color(&"font_color") == expected_primary_color, "result Primary uses the resolved Living Forge semantic color at %s" % label)
	_assert(primary.get_theme_color(&"font_color").a > 0.0, "result Primary remains visibly readable at %s" % label)
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		_assert(row.get_theme_color(color_name) == Color.TRANSPARENT, "result native Button %s stays transparent behind the overlay at %s" % [color_name, label])
	var focus_style := row.get_theme_stylebox(&"focus")
	_assert(row.has_focus() and focus_style != null and not (focus_style is StyleBoxEmpty), "result row keeps readable focus semantics around its visible overlay at %s" % label)


func _settings(row: Dictionary) -> PartyForgeSettings:
	var settings := PartyForgeSettings.new()
	settings.high_contrast = bool(row["high_contrast"])
	settings.reduced_motion = bool(row["reduced_motion"])
	settings.ui_scale_percent = int(row["ui"])
	settings.text_scale_percent = int(row["text"])
	return settings


func _hud_fixture(count: int) -> Dictionary:
	_sequence += 1
	var catalog := GameCatalog.load_defaults()
	var party := _party(count, catalog, "Member")
	var context := PlayerRunContext.new()
	assert(context.configure(StringName("accessibility-run-%d" % _sequence), 0, ProfileState.new_profile("accessibility-%d" % _sequence, "Accessibility", 1000), _sequence, party, 100).is_empty())
	var experience := ExperienceSystem.new()
	experience.configure_context(context, 1)
	var actors: Array[Node3D] = []
	var health_by_member: Dictionary = {}
	for member_id: int in range(1, count + 1):
		var actor := Node3D.new()
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		actor.add_child(health)
		health.configure(100.0, member_id == 1, 8.0, 0.5, member_id == 1)
		assert(context.bind_actor(member_id, actor))
		actors.append(actor)
		health_by_member[member_id] = health
	return {"party": party, "context": context, "experience": experience, "actors": actors, "health_by_member": health_by_member, "run": TestRun.new()}


func _party(count: int, catalog: GameCatalog, prefix: String) -> PartyManager:
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.configure_identity(_sequence, catalog.generic_name_pool)
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.members[0].character_name = "%s 1" % prefix
	for member_id: int in range(2, count + 1):
		assert(party.recruit(catalog.class_by_id(&"fighter")))
		party.members[-1].character_name = "%s %d" % [prefix, member_id]
	return party


func _cleanup_hud_fixture(fixture: Dictionary) -> void:
	(fixture.experience as ExperienceSystem).free()
	(fixture.party as PartyManager).free()
	for actor: Node3D in fixture.actors as Array:
		actor.free()
	(fixture.run as Node).free()


func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	return (maxf(first_luminance, second_luminance) + 0.05) / (minf(first_luminance, second_luminance) + 0.05)


func _relative_luminance(value: Color) -> float:
	return 0.2126 * _linear_channel(value.r) + 0.7152 * _linear_channel(value.g) + 0.0722 * _linear_channel(value.b)


func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _hud_member(hud: HUD, member_id: int) -> ForgePartyMemberCard:
	for node: Node in hud.get_tree().get_nodes_in_group(&"combat_hud_member"):
		if node is ForgePartyMemberCard and hud.is_ancestor_of(node) and int(node.get_meta(&"member_id", 0)) == member_id:
			return node as ForgePartyMemberCard
	return null


func _extraction_projection(count: int, capacity: int, automatic_count: int) -> TerminalExtractionProjection:
	var automatic: Array = []
	for index: int in automatic_count:
		automatic.append(_extraction_item("automatic-%02d" % index, true, false, false, 1, index))
	var eligible: Array = []
	var lost: Array[String] = []
	for index: int in count:
		var item_id := "item-%02d" % (index + 1)
		eligible.append(_extraction_item(item_id, false, false, true, 2 + (index % 3), index))
		lost.append(item_id)
	return EXTRACTION_PROJECTION_TYPE.create(automatic, eligible, capacity, [], lost, [], "", true) as TerminalExtractionProjection


func _extraction_item(item_id: String, automatic: bool, selected: bool, lost: bool, member_id: int, slot: int) -> TerminalExtractionItemProjection:
	var owner := "Fighter · Member %d" % member_id
	var detail := {"name": "Twin Band", "instance_id": item_id}
	return EXTRACTION_ITEM_TYPE.create_with_source(item_id, "Twin Band", "Common", &"common", owner, "Fighter Equipment", automatic, selected, lost, detail, [], member_id, "Fighter", StringName("run-equipment-%03d" % member_id), slot) as TerminalExtractionItemProjection


func _extraction_cards(panel: TerminalExtractionPanel) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in panel.find_children("*", "ForgeExtractionItemCard", true, false):
		if String(node.get_meta(&"item_id", "")).begins_with("item-"):
			result.append(node as Button)
	return result


func _result_rows(panel: RunResultPanel) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in panel.find_children("*", "Button", true, false):
		if not StringName(node.get_meta(&"recap_section_id", &"")).is_empty():
			result.append(node as Button)
	return result


func _result_actions(panel: RunResultPanel) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in panel.get_node("Frame/Content/Footer/Actions").get_children():
		if node is Button and (node as Button).visible:
			result.append(node as Button)
	return result


func _durable_safety(snapshot: RunTerminalSnapshot) -> RunTerminalRecoverySafetyResult:
	var empty: Array[String] = []
	var displaced: Array[String] = ["displaced-a", "displaced-b"]
	var record_result := RunTerminalRecoveryRecord.create(RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, snapshot, empty, "accessibility-transaction", displaced, "Automatic retained items need more destination space.", null, "")
	return RunTerminalRecoverySafetyResult.success(record_result.record) if record_result.ok() else RunTerminalRecoverySafetyResult.failure(record_result.error)


func _assert_member_semantics(card: ForgePartyMemberCard, surface: String, label: String) -> void:
	var state_id := card.semantic_state_id()
	var cue := card.semantic_state_inventory().get(state_id, {}) as Dictionary
	var state_text := card.get_node("Surface/Content/StateCue/StateText") as Label
	var state_icon := card.get_node("Surface/Content/StateCue/StateIcon") as TextureRect
	var shape := card.get_node("Surface/Content/StateCue/StateShape/Geometry") as Polygon2D
	var expected_icon_root := ForgePartyMemberCard.OWNED_ICON_ROOT if bool(cue.get("owned", false)) else ForgePartyMemberCard.TABLER_ICON_ROOT
	_assert(not state_id.is_empty() and not cue.is_empty() and state_text.text == String(cue.get("text", "")), "%s exposes its catalogued text state cue at %s" % [surface, label])
	_assert(_texture_path(state_icon) == expected_icon_root + String(cue.get("icon", "")), "%s exposes the exact catalogued semantic icon at %s" % [surface, label])
	_assert(shape.polygon.size() >= 3, "%s exposes a semantic state shape at %s" % [surface, label])
	_assert(card.accessibility_description.contains("State:"), "%s exposes the same state to assistive technology at %s" % [surface, label])


func _assert_alert_semantics(card: ForgeAlertCard, surface: String, label: String) -> void:
	var state_id := card.semantic_state_id()
	var cue := card.semantic_state_inventory().get(state_id, {}) as Dictionary
	var state_text := card.get_node("Surface/StateText") as Label
	var state_icon := card.get_node("Surface/StateIcon") as TextureRect
	var shape := card.get_node("Surface/StateShape/Geometry") as Polygon2D
	var expected_icon_root := ForgeAlertCard.OWNED_ICON_ROOT if bool(cue.get("owned", false)) else ForgeAlertCard.TABLER_ICON_ROOT
	_assert(not state_id.is_empty() and state_text.text == String(cue.get("text", "")), "%s exposes a text state cue at %s" % [surface, label])
	_assert(_texture_path(state_icon) == expected_icon_root + String(cue.get("icon", "")), "%s exposes the exact catalogued semantic icon at %s" % [surface, label])
	_assert(shape.polygon.size() >= 3, "%s exposes a semantic state shape at %s" % [surface, label])
	_assert(card.accessibility_name.contains(String(state_id).capitalize()), "%s exposes the same state to assistive technology at %s" % [surface, label])


func _assert_extraction_semantics(card: Button, surface: String, label: String) -> void:
	var state_text := card.get_node("Content/Footer/State/StateText") as Label
	var state_icon := card.get_node("Content/Footer/State/StateIcon") as TextureRect
	_assert(state_text.text == "WILL BE LOST", "%s carries exact consequence text at %s" % [surface, label])
	_assert(_texture_path(state_icon) == ForgeExtractionItemCard.ICON_ROOT + "alert-triangle.svg", "%s carries the exact lost-consequence icon at %s" % [surface, label])
	_assert(card.accessibility_description.contains("will be lost"), "%s exposes the same consequence to assistive technology at %s" % [surface, label])


func _assert_named_action(control: Control, expected_wording: String, surface: String, label: String) -> void:
	if control == null:
		_assert(false, "%s exists for accessible production wording '%s' at %s" % [surface, expected_wording, label])
		return
	var accessible_name := control.accessibility_name.strip_edges()
	_assert(not accessible_name.is_empty() and expected_wording.to_lower() in accessible_name.to_lower(), "%s has an accessible name using production wording '%s' at %s" % [surface, expected_wording, label])


func _assert_visible_focus(control: Control, surface: String, label: String) -> void:
	if control == null:
		_assert(false, "%s exists for visible focus verification at %s" % [surface, label])
		return
	_assert(control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE, "%s is focus eligible at %s" % [surface, label])
	if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return
	control.grab_focus()
	await _wait_until(func() -> bool: return control.has_focus(), "%s focus ownership at %s" % [surface, label])
	_assert(control.has_focus(), "%s accepts focus at %s" % [surface, label])
	var focus_frame := control.get_node_or_null("FocusFrame") as Control
	if focus_frame != null:
		_assert(focus_frame.visible, "%s draws its explicit focus frame at %s" % [surface, label])
	else:
		var focus_style := control.get_theme_stylebox(&"focus")
		_assert(focus_style != null and not (focus_style is StyleBoxEmpty), "%s resolves a visible focus style at %s" % [surface, label])


func _assert_surface_controls(scope: Node, surface: String, label: String) -> void:
	for node: Node in scope.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.is_visible_in_tree() or button.disabled or button.focus_mode == Control.FOCUS_NONE:
			continue
		_assert(button.get_global_rect().size.x >= 48.0 and button.get_global_rect().size.y >= 48.0, "%s %s has an actual 48px target at %s" % [surface, button.name, label])
		_assert(not button.accessibility_name.strip_edges().is_empty(), "%s %s has an accessible name at %s" % [surface, button.name, label])


func _assert_hidden_or_disabled_excluded(scope: Node, surface: String, label: String) -> void:
	var violations: Array[String] = []
	for node: Node in scope.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and not button.disabled:
			continue
		if button.focus_mode != Control.FOCUS_NONE or button.has_focus():
			var identity := String(button.name)
			if identity not in violations:
				violations.append(identity)
	_assert(violations.is_empty(), "%s hidden/disabled controls use exact FOCUS_NONE and own no focus at %s; controls=%s" % [surface, label, _bounded_names(violations)])


func _focus_modes_none(root_control: Control) -> bool:
	if root_control.focus_mode != Control.FOCUS_NONE:
		return false
	for node: Node in root_control.find_children("*", "Control", true, false):
		if (node as Control).focus_mode != Control.FOCUS_NONE:
			return false
	return true


func _accessible_exposure(root_control: Control) -> Array[Control]:
	var exposed: Array[Control] = []
	var candidates: Array[Control] = [root_control]
	for node: Node in root_control.find_children("*", "Control", true, false):
		candidates.append(node as Control)
	for control: Control in candidates:
		if control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE and not control.accessibility_name.strip_edges().is_empty():
			exposed.append(control)
	return exposed


func _disclosure_tween_for(hud: HUD, region: StringName) -> Tween:
	var value: Variant = hud.get("_disclosure_tweens")
	if not value is Dictionary:
		return null
	return (value as Dictionary).get(region) as Tween


func _bounded_names(names: Array[String], limit := 8) -> String:
	if names.size() <= limit:
		return str(names)
	return "%s (+%d more)" % [names.slice(0, limit), names.size() - limit]


func _assert_navigation_skips_excluded(scope: Control, viewport: SubViewport, start: Control, surface: String, label: String, require_owner := true) -> void:
	if start != null and is_instance_valid(start) and start.is_visible_in_tree() and start.focus_mode != Control.FOCUS_NONE:
		start.grab_focus()
		await _wait_until(func() -> bool: return start.has_focus(), "%s navigation start focus at %s" % [surface, label])
	for action_name: StringName in [&"ui_focus_next", &"ui_down", &"ui_focus_prev", &"ui_up"]:
		await _action(viewport, action_name)
		var owner := viewport.gui_get_focus_owner() as Control
		var owner_valid := owner != null and scope.is_ancestor_of(owner) and owner.is_visible_in_tree() and owner.focus_mode != Control.FOCUS_NONE and not (owner is BaseButton and (owner as BaseButton).disabled)
		_assert(owner_valid or (not require_owner and owner == null), "%s authentic %s navigation skips every hidden/disabled control at %s; owner=%s" % [surface, action_name, label, owner])


func _member_semantic_signature(card: ForgePartyMemberCard) -> Dictionary:
	if card == null:
		return {}
	return {
		"accessibility_name": card.accessibility_name,
		"accessibility_description": card.accessibility_description,
		"state": card.semantic_state_id(),
		"state_text": (card.get_node("Surface/Content/StateCue/StateText") as Label).text,
		"icon_path": _texture_path(card.get_node("Surface/Content/StateCue/StateIcon") as TextureRect),
		"shape_points": _polygon_points((card.get_node("Surface/Content/StateCue/StateShape/Geometry") as Polygon2D).polygon),
	}


func _alert_semantic_signature(card: ForgeAlertCard) -> Dictionary:
	return {
		"accessibility_name": card.accessibility_name,
		"accessibility_description": card.accessibility_description,
		"state": card.semantic_state_id(),
		"state_text": (card.get_node("Surface/StateText") as Label).text,
		"icon_path": _texture_path(card.get_node("Surface/StateIcon") as TextureRect),
		"shape_points": _polygon_points((card.get_node("Surface/StateShape/Geometry") as Polygon2D).polygon),
	}


func _level_up_semantic_signature(card: UpgradeCard) -> Dictionary:
	return {
		"accessibility_name": card.accessibility_name,
		"accessibility_description": card.accessibility_description,
		"name": (card.get_node("Content/Name") as Label).text,
		"effect": (card.get_node("Content/DetailsScroll/Body/Summary") as Label).text,
		"scope": (card.get_node("Content/DetailsScroll/Body/Scope") as Label).text,
		"action": (card.get_node("Content/Footer/Action") as Label).text,
		"icon_path": _texture_path(card.get_node("Content/Identity/Icon") as TextureRect),
		"fallback_icon": (card.get_node("Content/Identity/FallbackIcon") as Label).text,
	}


func _extraction_semantic_signature(card: Button) -> Dictionary:
	return {
		"accessibility_name": card.accessibility_name,
		"accessibility_description": card.accessibility_description,
		"state_text": (card.get_node("Content/Footer/State/StateText") as Label).text,
		"icon_path": _texture_path(card.get_node("Content/Footer/State/StateIcon") as TextureRect),
	}


func _result_semantic_signature(panel: RunResultPanel, projection: RunResultProjection) -> Dictionary:
	var actions: Array[String] = []
	for action: Button in _result_actions(panel):
		actions.append(action.accessibility_name)
	return {
		"headline": (panel.get_node("Frame/Content/Header/OutcomeHeadline") as Label).text,
		"state": (panel.get_node("Frame/Content/Header/State") as Label).text,
		"section_ids": projection.section_ids(),
		"actions": actions,
	}


func _assert_semantic_parity(surface: String, signature: Dictionary, label: String) -> void:
	if not _semantic_baseline.has(surface):
		_semantic_baseline[surface] = signature.duplicate(true)
		return
	_assert(signature == _semantic_baseline[surface], "%s text, icon, shape, and accessibility semantics match normal-default truth at %s" % [surface, label])


func _texture_path(texture_rect: TextureRect) -> String:
	return "" if texture_rect == null or texture_rect.texture == null else texture_rect.texture.resource_path


func _polygon_points(points: PackedVector2Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Vector2 in points:
		result.append(point)
	return result


func _scroll_visible_global_rect(scroll: ScrollContainer) -> Rect2:
	var visible_rect := scroll.get_global_rect()
	var vertical_bar := scroll.get_v_scroll_bar()
	if vertical_bar != null and vertical_bar.is_visible_in_tree():
		visible_rect.size.x = maxf(visible_rect.size.x - vertical_bar.get_global_rect().size.x, 0.0)
	var horizontal_bar := scroll.get_h_scroll_bar()
	if horizontal_bar != null and horizontal_bar.is_visible_in_tree():
		visible_rect.size.y = maxf(visible_rect.size.y - horizontal_bar.get_global_rect().size.y, 0.0)
	var ancestor := scroll.get_parent_control()
	while ancestor != null:
		if ancestor.clip_contents:
			visible_rect = visible_rect.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent_control()
	return visible_rect


func _focus_within(scope: Control, viewport: SubViewport) -> bool:
	if scope == null:
		return false
	var owner := viewport.gui_get_focus_owner()
	return owner != null and scope.is_ancestor_of(owner)


func _wait_until(condition: Callable, description: String, max_frames := 30) -> bool:
	for _frame_index: int in max_frames:
		if bool(condition.call()):
			return true
		await process_frame
	_failures.append("condition deadline expired waiting for %s after %d frames" % [description, max_frames])
	return false


func _action(viewport: SubViewport, action_name: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	viewport.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("COMBAT_LOOP_ACCESSIBILITY_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("COMBAT_LOOP_ACCESSIBILITY_FAILURE: %s" % failure)
	print("COMBAT_LOOP_ACCESSIBILITY_SUMMARY: FAIL failures=%d" % _failures.size())
	quit(1)
