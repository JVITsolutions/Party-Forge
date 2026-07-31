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
	var entries := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries") as GridContainer
	var stats_content := stats_page.get_node("Layout/Content") as SplitContainer
	var upgrades_content := upgrades_page.get_node("Layout/Content") as SplitContainer
	var status := ledger.get_node("Overlay/Frame/Layout/Status") as Label
	var status_font_size := status.get_theme_font_size(&"font_size")
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
	TestAssertions.truthy(selected_member.text.begins_with("[Selected] "), "member selection has a non-color text cue", failures)
	ledger.refresh()
	selected_member = ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_1") as Button
	TestAssertions.equal(selected_member.text.count("[Selected] "), 1, "selection marker does not accumulate on refresh", failures)
	TestAssertions.truthy(stats_page.initial_focus() is Button, "Stats supplies an explicit first focus row", failures)

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
