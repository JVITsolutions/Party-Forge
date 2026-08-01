extends RefCounted

const RESPONSIVE_PATH := "res://scripts/ui/ledger/ledger_responsive_layout.gd"
const LEDGER_SCENE_PATH := "res://scenes/ui/ledger/character_ledger.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_mode_policy(failures)
	_test_layout_controller_and_pause_edges(failures)
	return failures


func _test_mode_policy(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(RESPONSIVE_PATH), "ledger responsive policy exists", failures)
	if not ResourceLoader.exists(RESPONSIVE_PATH):
		return
	var policy := load(RESPONSIVE_PATH) as Script
	TestAssertions.equal(int(policy.call("mode_for_size", Vector2(1920.0, 1080.0))), 0, "1920x1080 resolves to DESKTOP", failures)
	TestAssertions.equal(int(policy.call("mode_for_size", Vector2(3840.0, 2160.0))), 0, "3840x2160 resolves to DESKTOP", failures)
	TestAssertions.equal(int(policy.call("mode_for_size", Vector2(960.0, 540.0))), 1, "960x540 resolves to COMPACT", failures)
	TestAssertions.equal(int(policy.call("mode_for_size", Vector2(1099.0, 1080.0))), 1, "width below threshold resolves to COMPACT", failures)
	TestAssertions.equal(int(policy.call("mode_for_size", Vector2(1920.0, 649.0))), 1, "height below threshold resolves to COMPACT", failures)


func _test_layout_controller_and_pause_edges(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var ledger := (load(LEDGER_SCENE_PATH) as PackedScene).instantiate() as CharacterLedger
	tree.root.add_child(ledger)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for member_id: int in range(2, 25):
		party.members.append(PartyMemberState.new(member_id, catalog.class_by_id(&"fighter"), false, "Extra %d" % member_id))
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vitality", catalog, party, 1), "responsive fixture owns one upgrade", failures)
	var run := GameRun.new()
	run.start_run()
	var context := LedgerPlayerContext.new(0)
	ledger.configure(run, party, catalog, Callable(), [context])

	TestAssertions.truthy(ledger.has_method("apply_viewport_size"), "ledger exposes deterministic viewport policy", failures)
	var stats_page := ledger.get_node("Overlay/Frame/Layout/Body/PageHost/StatsLedgerPage") as CharacterLedgerPage
	var upgrades_page := ledger.get_node("Overlay/Frame/Layout/Body/PageHost/UpgradesLedgerPage") as CharacterLedgerPage
	for page: CharacterLedgerPage in [stats_page, upgrades_page]:
		TestAssertions.truthy(page.has_method("apply_compact"), "%s exposes compact contract" % page.name, failures)
		TestAssertions.truthy(page.has_method("pin_active_detail"), "%s exposes pin contract" % page.name, failures)
		TestAssertions.truthy(page.has_method("dismiss_pinned_detail"), "%s exposes dismiss contract" % page.name, failures)
	if not ledger.has_method("apply_viewport_size"):
		_cleanup(ledger, run, party)
		return

	var body := ledger.get_node("Overlay/Frame/Layout/Body") as SplitContainer
	var party_scroll := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll") as ScrollContainer
	var entries := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries") as GridContainer
	var stats_content := stats_page.get_node("Layout/Content") as SplitContainer
	var upgrades_content := upgrades_page.get_node("Layout/Content") as SplitContainer
	var status := ledger.get_node("Overlay/Frame/Layout/Status") as Label
	var status_font_size := status.get_theme_font_size(&"font_size")
	TestAssertions.truthy(party_scroll.follow_focus, "party scroll follows keyboard and controller focus", failures)
	TestAssertions.equal(party_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "party scroll disables horizontal scrolling", failures)
	ledger.call("apply_viewport_size", Vector2(1920.0, 1080.0))
	TestAssertions.truthy(not body.vertical, "desktop outer split is horizontal", failures)
	TestAssertions.equal(entries.columns, 1, "desktop party rail uses one column", failures)
	TestAssertions.truthy(not stats_content.vertical and not upgrades_content.vertical, "desktop page detail splits are horizontal", failures)
	ledger.call("apply_viewport_size", Vector2(960.0, 540.0))
	TestAssertions.truthy(body.vertical, "compact outer split is vertical", failures)
	TestAssertions.equal(entries.columns, 3, "compact party rail uses three columns", failures)
	TestAssertions.truthy(stats_content.vertical and upgrades_content.vertical, "compact page detail splits are vertical", failures)
	TestAssertions.equal(status.get_theme_font_size(&"font_size"), status_font_size, "responsive policy leaves font size unchanged", failures)
	TestAssertions.truthy(stats_page.get_node("Layout/Content/DetailPanel") is ScrollContainer, "Stats detail scrolls independently", failures)
	TestAssertions.truthy(upgrades_page.get_node("Layout/Content/DetailPanel") is ScrollContainer, "Upgrades detail scrolls independently", failures)

	TestAssertions.truthy(ledger.open_for_player(), "responsive ledger opens", failures)
	var selected_member := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_1") as Button
	var member_3 := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_3") as Button
	var member_4 := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_4") as Button
	var member_21 := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_21") as Button
	var member_24 := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_24") as Button
	var stats_focus := stats_page.initial_focus()
	TestAssertions.equal(member_4.focus_neighbor_top, member_4.get_path_to(selected_member), "compact member 4 moves up to member 1", failures)
	TestAssertions.equal(member_4.focus_neighbor_left, member_4.get_path_to(member_3), "compact member 4 moves left to member 3", failures)
	TestAssertions.equal(member_24.focus_neighbor_top, member_24.get_path_to(member_21), "compact member 24 moves up to member 21", failures)
	TestAssertions.equal(selected_member.focus_neighbor_bottom, selected_member.get_path_to(member_4), "compact bridge preserves member 1 internal down route", failures)
	TestAssertions.equal(selected_member.focus_neighbor_right, selected_member.get_path_to(stats_focus), "compact selected member moves right to active page", failures)
	TestAssertions.equal(stats_focus.focus_neighbor_left, stats_focus.get_path_to(selected_member), "compact active page moves left to selected member", failures)
	TestAssertions.truthy(ledger.select_member(24), "compact fixture selects last roster member", failures)
	stats_focus = stats_page.initial_focus()
	TestAssertions.equal(member_24.focus_neighbor_bottom, member_24.get_path_to(stats_focus), "compact last-row member moves down to active page", failures)
	TestAssertions.equal(stats_focus.focus_neighbor_top, stats_focus.get_path_to(member_24), "compact active page moves up to last-row member", failures)
	ledger.apply_viewport_size(Vector2(1920.0, 1080.0))
	TestAssertions.equal(member_24.focus_neighbor_top, member_24.get_path_to(ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_23")), "desktop member 24 moves up to member 23", failures)
	TestAssertions.equal(selected_member.focus_neighbor_bottom, selected_member.get_path_to(ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_2")), "desktop member 1 moves down to member 2", failures)
	TestAssertions.equal(member_24.focus_neighbor_right, member_24.get_path_to(stats_focus), "desktop selected member moves right to active page", failures)
	TestAssertions.equal(stats_focus.focus_neighbor_left, stats_focus.get_path_to(member_24), "desktop active page moves left to selected member", failures)
	ledger.apply_viewport_size(Vector2(960.0, 540.0))
	ledger.select_member(1)
	TestAssertions.truthy(selected_member.text.begins_with("[Selected] "), "member selection has a non-color text cue", failures)
	ledger.refresh()
	selected_member = ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_1") as Button
	TestAssertions.equal(selected_member.text.count("[Selected] "), 1, "selection marker does not accumulate on refresh", failures)
	stats_focus = stats_page.initial_focus()
	TestAssertions.truthy(stats_focus is Button, "Stats supplies an explicit first focus row", failures)
	TestAssertions.equal(stats_focus.focus_neighbor_left, stats_focus.get_path_to(selected_member), "refresh restores the active page route to the selected member", failures)
	member_24 = ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_24") as Button
	if member_24.is_inside_tree():
		member_24.grab_focus()
	ledger.context.last_focus_path = ledger.get_path_to(member_24)
	ledger.close()
	TestAssertions.truthy(ledger.open_for_player(), "ledger reopens with remembered roster focus", failures)
	member_24 = ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_24") as Button
	TestAssertions.equal(ledger.get_node(ledger.context.last_focus_path), member_24, "reopen retains remembered member 24 focus target", failures)
	if ledger.is_inside_tree():
		TestAssertions.equal(ledger.get_viewport().gui_get_focus_owner(), member_24, "reopen restores member 24 as the actual focus owner", failures)
	TestAssertions.equal(ledger.context.selected_member_id, 1, "remembered focus does not change selected member", failures)
	TestAssertions.truthy(ledger.has_method("_apply_member_visibility_request"), "ledger exposes revision-keyed visibility delivery", failures)
	var reopen_revision := 0
	if ledger.has_method("_apply_member_visibility_request"):
		reopen_revision = int(ledger.get("_member_visibility_request_revision"))
		TestAssertions.equal(int(ledger.get("_member_visibility_request_target_id")), 24, "reopen visibility request captures member 24", failures)
	var member_23 := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_23") as Button
	ledger.context.last_focus_path = ledger.get_path_to(member_23)
	TestAssertions.truthy(ledger.select_member(24), "refresh-removal fixture selects member 24", failures)
	if member_24.is_inside_tree():
		member_24.grab_focus()
	party.members.remove_at(23)
	ledger.refresh()
	TestAssertions.equal(ledger.context.selected_member_id, 1, "removed member 24 falls back to member 1", failures)
	if ledger.has_method("_apply_member_visibility_request"):
		var refresh_revision := int(ledger.get("_member_visibility_request_revision"))
		TestAssertions.truthy(refresh_revision > reopen_revision, "refresh visibility request supersedes reopen request", failures)
		TestAssertions.equal(int(ledger.get("_member_visibility_request_target_id")), 1, "in-session refresh captures fallback member 1", failures)
		TestAssertions.truthy(not bool(ledger.call("_apply_member_visibility_request", 24, reopen_revision)), "older reopen callback is a no-op after refresh request", failures)
		TestAssertions.truthy(bool(ledger.call("_apply_member_visibility_request", 1, refresh_revision)), "current refresh callback applies fallback member 1", failures)
		ledger.close()
		TestAssertions.truthy(not bool(ledger.call("_apply_member_visibility_request", 1, refresh_revision)), "close invalidates outstanding visibility callbacks", failures)
		TestAssertions.truthy(ledger.open_for_player(), "ledger reopens after visibility invalidation check", failures)

	ledger.call("_unhandled_input", _action_event(&"ledger_next_page"))
	TestAssertions.truthy(upgrades_page.visible and not stats_page.visible, "next bumper moves Stats to Current Upgrades", failures)
	ledger.call("_unhandled_input", _action_event(&"ledger_next_page"))
	TestAssertions.truthy(stats_page.visible and not upgrades_page.visible, "next bumper wraps past Coming Soon back to Stats", failures)
	ledger.call("_unhandled_input", _action_event(&"ledger_previous_page"))
	TestAssertions.truthy(upgrades_page.visible and not stats_page.visible, "previous bumper skips Coming Soon", failures)
	ledger.activate_page(&"stats")

	var coming_tab := _tab_for(ledger, &"equipment_inventory")
	TestAssertions.truthy(coming_tab != null and coming_tab.focus_mode != Control.FOCUS_NONE, "Coming Soon tab remains focusable", failures)
	if coming_tab != null:
		coming_tab.focus_entered.emit()
		TestAssertions.equal(status.text, "Equipment & Inventory: Coming Soon", "Coming Soon explains itself on focus", failures)
		TestAssertions.truthy(stats_page.visible and not upgrades_page.visible, "Coming Soon focus never activates a page", failures)
		coming_tab.pressed.emit()
		TestAssertions.equal(status.text, "Equipment & Inventory: Coming Soon", "Coming Soon activation keeps exact explanation", failures)
		TestAssertions.truthy(stats_page.visible and not upgrades_page.visible, "Coming Soon activation preserves available page", failures)

	var stats_detail := stats_page.get_node("Layout/Content/DetailPanel") as Control
	TestAssertions.truthy(not stats_detail.visible, "compact detail starts dismissed", failures)
	ledger.call("_unhandled_input", _action_event(&"ui_accept"))
	TestAssertions.truthy(stats_detail.visible, "ui_accept pins the active row detail", failures)
	ledger.call("_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(ledger.is_open() and not stats_detail.visible, "first compact cancel dismisses pinned detail only", failures)
	TestAssertions.truthy(stats_page.initial_focus() is Button and stats_page.initial_focus().focus_mode != Control.FOCUS_NONE, "dismiss restores a valid originating row target", failures)
	ledger.call("_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(not ledger.is_open(), "second compact cancel closes the ledger", failures)
	TestAssertions.truthy(not tree.paused, "RUNNING ledger close restores unpaused tree", failures)

	run.begin_level_up()
	TestAssertions.truthy(tree.paused, "level-up owns pause before ledger", failures)
	TestAssertions.truthy(ledger.open_for_player(), "ledger may inspect during level-up", failures)
	ledger.close()
	TestAssertions.truthy(tree.paused, "ledger close preserves level-up pause", failures)
	run.resume_run()
	TestAssertions.truthy(not tree.paused, "level-up resume still controls its pause", failures)

	run.advance_run_time(RunStateMachine.BOSS_TIME)
	TestAssertions.equal(run.current_state(), RunStateMachine.State.BOSS, "fixture reaches BOSS", failures)
	TestAssertions.truthy(not tree.paused, "BOSS starts unpaused", failures)
	TestAssertions.truthy(ledger.open_for_player(), "ledger opens during BOSS", failures)
	ledger.close()
	TestAssertions.truthy(not tree.paused, "ledger close restores unpaused BOSS", failures)

	_cleanup(ledger, run, party)


func _tab_for(ledger: CharacterLedger, page_id: StringName) -> Button:
	for child: Node in ledger.get_node("Overlay/Frame/Layout/Tabs").get_children():
		var button := child as Button
		if button != null and button.get_meta("page_id", &"") == page_id:
			return button
	return null


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _cleanup(ledger: CharacterLedger, run: GameRun, party: PartyManager) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if ledger.is_open():
		ledger.close()
	ledger.free()
	run.free()
	party.free()
	tree.paused = false
