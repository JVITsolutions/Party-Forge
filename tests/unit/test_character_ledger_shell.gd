extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var ledger_scene := load("res://scenes/ui/ledger/character_ledger.tscn") as PackedScene
	TestAssertions.truthy(ledger_scene != null, "ledger shell scene loads", failures)
	if ledger_scene == null:
		return failures
	var ledger := ledger_scene.instantiate() as CharacterLedger
	tree.root.add_child(ledger)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var run := GameRun.new()
	run.start_run()
	var player_context := LedgerPlayerContext.new(0)
	ledger.configure(run, party, catalog, func(_member_id: int) -> Dictionary:
		return {"current": 260.0, "maximum": 260.0, "is_downed": false, "is_dead": false}
	, [player_context])

	TestAssertions.truthy(not ledger.open_for_player(99), "ledger rejects an unknown local player context", failures)
	TestAssertions.truthy(ledger.open_for_player(), "ledger opens during running state", failures)
	TestAssertions.truthy(tree.paused, "ledger pauses gameplay", failures)
	var party_entries := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries") as Container
	TestAssertions.equal(party_entries.get_child_count(), 1, "rail shows only current members", failures)
	var stats_page := ledger.get_node("Overlay/Frame/Layout/Body/PageHost/StatsLedgerPage") as Control
	var upgrades_page := ledger.get_node("Overlay/Frame/Layout/Body/PageHost/UpgradesLedgerPage") as Control
	TestAssertions.truthy(stats_page.visible and not upgrades_page.visible, "opening activates only the selected page lifecycle", failures)

	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "provider refresh fixture recruits a member", failures)
	TestAssertions.equal(party_entries.get_child_count(), 2, "party signal refreshes the rail", failures)
	TestAssertions.truthy(ledger.select_member(2), "current rail member can be selected", failures)
	TestAssertions.truthy(ledger.activate_page(&"current_upgrades"), "available page activates", failures)
	TestAssertions.equal(ledger.get("context").selected_member_id, 2, "selected member persists across pages", failures)
	TestAssertions.truthy(not stats_page.visible and upgrades_page.visible, "page switch deactivates the previous page", failures)
	TestAssertions.truthy(not ledger.activate_page(&"equipment_inventory"), "Coming Soon page cannot activate", failures)
	var status := ledger.get_node("Overlay/Frame/Layout/Status") as Label
	TestAssertions.truthy("Coming Soon" in status.text, "Coming Soon activation explains itself", failures)
	TestAssertions.truthy(status.focus_mode != Control.FOCUS_NONE, "Coming Soon explanation remains focusable", failures)
	var coming_tab: Button
	for tab_node: Node in ledger.get_node("Overlay/Frame/Layout/Tabs").get_children():
		var tab := tab_node as Button
		if tab != null and tab.get_meta("page_id", &"") == &"equipment_inventory":
			coming_tab = tab
			break
	TestAssertions.truthy(coming_tab != null and not coming_tab.disabled and coming_tab.focus_mode != Control.FOCUS_NONE, "Coming Soon tab stays focusable", failures)
	TestAssertions.truthy(upgrades_page.visible, "rejected page preserves the active page", failures)

	for member_id: int in range(3, 8):
		party.members.append(PartyMemberState.new(member_id, catalog.class_by_id(&"fighter"), false, "Extra %d" % member_id))
	ledger.refresh()
	TestAssertions.equal(party_entries.get_child_count(), 7, "scrolling rail supports exceptional party sizes above six", failures)
	TestAssertions.equal(ledger.get("context").selected_member_id, 2, "rail rebuild preserves a valid selection", failures)

	ledger.close()
	TestAssertions.truthy(not tree.paused, "closing restores gameplay", failures)
	tree.paused = true
	TestAssertions.truthy(ledger.open_for_player(), "ledger opens over an existing pause", failures)
	ledger.close()
	TestAssertions.truthy(tree.paused, "closing preserves a prior pause owner", failures)
	tree.paused = false

	ledger.free()
	run.free()
	party.free()
	return failures
