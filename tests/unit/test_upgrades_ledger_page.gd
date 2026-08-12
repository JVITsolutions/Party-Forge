extends RefCounted

const PAGE_SCENE_PATH := "res://scenes/ui/ledger/upgrades_ledger_page.tscn"
const LEDGER_SCENE_PATH := "res://scenes/ui/ledger/character_ledger.tscn"
const ROWS_PATH := ^"Layout/Content/UpgradeSide/UpgradeScroll/UpgradeRows"
const DETAIL_PATH := "Layout/Content/DetailPanel/Detail/"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_current_upgrades_page(failures)
	_test_member_24_context_across_pages(failures)
	_test_equipment_navigation(failures)
	return failures


func _test_current_upgrades_page(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var page_scene := load(PAGE_SCENE_PATH) as PackedScene
	TestAssertions.truthy(page_scene != null, "upgrades page scene loads", failures)
	if page_scene == null:
		return
	var page := page_scene.instantiate() as UpgradesLedgerPage
	tree.root.add_child(page)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vitality", catalog, party, 1), "Vitality rank 1 applies through the application service", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vitality", catalog, party, 1), "Vitality rank 2 applies through the application service", failures)
	TestAssertions.truthy(party.upgrade_party_stat(&"damage"), "one party damage rank applies", failures)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "second Fighter activates the Vanguard trait", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vanguard_wall", catalog, party), "applicable Vanguard upgrade applies through the application service", failures)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"mage")), "Mage fixture joins the party", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"living_flame", catalog, party, 3), "Mage signature applies to the Mage", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"arcane_convergence", catalog, party), "Arcane party upgrade applies for an eligible Mage", failures)
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable())
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 1
	page.configure(provider, context)

	for method_name: StringName in [&"select_upgrade"]:
		TestAssertions.truthy(page.has_method(method_name), "upgrades page exposes %s" % method_name, failures)
	for node_path: NodePath in [
		^"Layout/Header",
		^"Layout/Content/UpgradeSide/EmptyState",
		^"Layout/Content/UpgradeSide/UpgradeScroll/UpgradeRows",
		^"Layout/Content/DetailPanel/Detail/Title",
		^"Layout/Content/DetailPanel/Detail/Rank",
		^"Layout/Content/DetailPanel/Detail/Ownership",
		^"Layout/Content/DetailPanel/Detail/Description",
		^"Layout/Content/DetailPanel/Detail/Effects",
		^"Layout/Content/DetailPanel/Detail/Applicability",
		^"Layout/Content/DetailPanel/Detail/Keywords",
	]:
		TestAssertions.truthy(page.get_node_or_null(node_path) != null, "upgrades page owns %s" % node_path, failures)
	if not failures.is_empty():
		provider.configure(null, null, Callable())
		page.free()
		party.free()
		return

	page.refresh()
	var rows := page.get_node(ROWS_PATH) as VBoxContainer
	var vitality := rows.get_node_or_null("Upgrade_vitality") as Button
	TestAssertions.truthy(vitality != null, "personal Vitality appears", failures)
	if vitality != null:
		TestAssertions.equal(
			rows.get_children().filter(func(child: Node) -> bool: return child.name == &"Upgrade_vitality").size(),
			1,
			"personal Vitality collapses to one row",
			failures
		)
		TestAssertions.truthy("Vitality" in vitality.text and "Rank 2 / 5" in vitality.text and "Personal" in vitality.text, "Vitality row shows name, collapsed rank, and ownership", failures)
		TestAssertions.truthy(vitality.focus_mode != Control.FOCUS_NONE, "upgrade rows remain keyboard focusable", failures)
	TestAssertions.truthy(rows.get_node_or_null("Upgrade_party_damage") != null, "applicable party damage source appears", failures)
	TestAssertions.truthy(rows.get_node_or_null("Upgrade_vanguard_wall") != null, "applicable authored trait source appears", failures)
	TestAssertions.truthy(rows.get_node_or_null("Upgrade_active_trait_vanguard") != null, "applicable active trait source appears", failures)
	TestAssertions.truthy(rows.get_node_or_null("Upgrade_living_flame") == null, "unrelated Mage signature is absent for Fighter", failures)
	TestAssertions.truthy(rows.get_node_or_null("Upgrade_arcane_convergence") == null, "unrelated Arcane party signature is absent for Fighter", failures)

	var vitality_row: Dictionary
	for row: Dictionary in provider.upgrade_rows(1):
		if row.id == &"vitality":
			vitality_row = row
			break
	var expected_detail := provider.upgrade_detail(vitality_row)
	TestAssertions.truthy(page.select_upgrade(&"vitality"), "Vitality detail opens", failures)
	TestAssertions.equal((page.get_node(DETAIL_PATH + "Title") as Label).text, expected_detail.title, "detail uses canonical title", failures)
	TestAssertions.equal((page.get_node(DETAIL_PATH + "Rank") as Label).text, expected_detail.rank_text, "detail uses canonical owned rank", failures)
	TestAssertions.equal((page.get_node(DETAIL_PATH + "Ownership") as Label).text, "Personal", "detail identifies ownership", failures)
	TestAssertions.equal((page.get_node(DETAIL_PATH + "Description") as Label).text, expected_detail.description, "detail uses canonical definition", failures)
	TestAssertions.equal((page.get_node(DETAIL_PATH + "Effects") as Label).text, "\n".join(expected_detail.effect_lines), "detail shows every canonical effect", failures)
	TestAssertions.truthy("Applies to personal." in (page.get_node(DETAIL_PATH + "Applicability") as Label).text, "detail explains selected-member applicability", failures)
	TestAssertions.equal((page.get_node(DETAIL_PATH + "Keywords") as Label).text, "\n".join(expected_detail.keyword_lines), "detail shows every canonical keyword definition", failures)
	if vitality != null:
		TestAssertions.truthy(String(expected_detail.effect_lines[0]) in vitality.tooltip_text, "row affordance exposes the canonical current effect", failures)
		TestAssertions.truthy(String(expected_detail.keyword_lines[0]) in vitality.tooltip_text, "row affordance exposes canonical keyword information", failures)
		vitality.focus_entered.emit()
		TestAssertions.equal((page.get_node(DETAIL_PATH + "Title") as Label).text, expected_detail.title, "focus and activation populate the same detail", failures)
	page.refresh()
	TestAssertions.equal(page.get("selected_upgrade_id"), &"vitality", "refresh preserves a visible upgrade selection", failures)
	var title_before_rejection := (page.get_node(DETAIL_PATH + "Title") as Label).text
	TestAssertions.truthy(not page.select_upgrade(&"unknown_upgrade"), "unknown upgrade selection is rejected", failures)
	TestAssertions.equal((page.get_node(DETAIL_PATH + "Title") as Label).text, title_before_rejection, "rejected selection preserves current detail", failures)
	TestAssertions.truthy(page.initial_focus() is Button, "initial focus returns the first upgrade row", failures)

	var fresh_party := PartyManager.new()
	fresh_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	provider.configure(fresh_party, catalog, Callable())
	page.configure(provider, context)
	page.refresh()
	var empty_state := page.get_node("Layout/Content/UpgradeSide/EmptyState") as Label
	TestAssertions.truthy(empty_state.visible and empty_state.text == "No upgrades acquired yet.", "fresh party shows the deliberate empty state", failures)
	TestAssertions.equal((page.get_node(ROWS_PATH) as VBoxContainer).get_child_count(), 0, "empty state has no generated upgrade rows", failures)

	provider.configure(null, null, Callable())
	page.free()
	fresh_party.free()
	party.free()


func _test_member_24_context_across_pages(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var ledger_scene := load(LEDGER_SCENE_PATH) as PackedScene
	if ledger_scene == null:
		TestAssertions.truthy(false, "ledger scene loads for member 24 page switching", failures)
		return
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for _index: int in 23:
		TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "24-member Upgrades fixture recruits every Fighter", failures)
	var member_24 := party.member_by_id(24)
	TestAssertions.truthy(member_24 != null, "24-member Upgrades fixture includes member 24", failures)
	if member_24 == null:
		party.free()
		return
	member_24.character_name = "Twenty Four"
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vitality", catalog, party, 24), "member 24 receives the unique personal Vitality source", failures)

	var run := GameRun.new()
	run.start_run()
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 24
	context.active_page_id = &"stats"
	var ledger := ledger_scene.instantiate() as CharacterLedger
	tree.root.add_child(ledger)
	ledger.configure(run, party, catalog, Callable(), [context])
	var member_1_upgrade_ids := ledger.provider.upgrade_rows(1).map(func(row: Dictionary) -> StringName: return row.id)
	TestAssertions.truthy(&"vitality" not in member_1_upgrade_ids, "member 1 Current Upgrades data excludes member 24's unique Vitality source", failures)
	TestAssertions.truthy(ledger.open_for_player(), "ledger opens on Stats for member 24", failures)

	var page_host := ledger.get_node("Overlay/Frame/Layout/Body/PageHost") as Control
	var stats_page := page_host.get_node("StatsLedgerPage") as StatsLedgerPage
	var stats_identity := (stats_page.get_node("Layout/Header/Identity") as Label).text
	TestAssertions.truthy("Twenty Four" in stats_identity, "Stats page identifies selected member 24 before switching", failures)
	TestAssertions.equal(context.selected_member_id, 24, "member 24 context is active before switching pages", failures)

	TestAssertions.truthy(ledger.activate_page(&"current_upgrades"), "Current Upgrades activates for member 24", failures)
	var upgrades_page := page_host.get_node("UpgradesLedgerPage") as UpgradesLedgerPage
	var member_24_rows := upgrades_page.get_node(ROWS_PATH) as VBoxContainer
	TestAssertions.truthy(member_24_rows.get_node_or_null("Upgrade_vitality") != null, "Current Upgrades shows member 24's unique Vitality row", failures)
	TestAssertions.equal(context.selected_member_id, 24, "member 24 context persists on Current Upgrades", failures)

	TestAssertions.truthy(ledger.activate_page(&"stats"), "Stats reactivates after Current Upgrades", failures)
	stats_identity = (stats_page.get_node("Layout/Header/Identity") as Label).text
	TestAssertions.equal(context.selected_member_id, 24, "member 24 context persists after switching back to Stats", failures)
	TestAssertions.truthy("Twenty Four" in stats_identity, "Stats identity still renders member 24 after page switches", failures)

	ledger.close()
	tree.paused = false
	ledger.free()
	run.free()
	party.free()


func _test_equipment_navigation(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var ledger_scene := load(LEDGER_SCENE_PATH) as PackedScene
	TestAssertions.truthy(ledger_scene != null, "ledger scene loads for Equipment navigation", failures)
	if ledger_scene == null:
		return
	var ledger := ledger_scene.instantiate() as CharacterLedger
	tree.root.add_child(ledger)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var run := GameRun.new()
	run.start_run()
	var context := LedgerPlayerContext.new(0)
	context.active_page_id = &"current_upgrades"
	var feature_ids: Array[StringName] = [&"stats", &"current_upgrades", &"equipment_inventory"]
	var unlock_ids: Array[StringName] = [&"equipment_inventory"]
	ledger.configure(run, party, catalog, Callable(), [context], FeatureAccessPolicy.new(false, true, feature_ids, unlock_ids, unlock_ids))
	TestAssertions.truthy(ledger.open_for_player(), "ledger opens directly on Current Upgrades", failures)
	var page_host := ledger.get_node("Overlay/Frame/Layout/Body/PageHost") as Control
	var upgrades_page := page_host.get_node("UpgradesLedgerPage") as Control
	var stats_page := page_host.get_node("StatsLedgerPage") as Control
	var equipment_page := page_host.get_node("EquipmentInventoryLedgerPage") as Control
	var initial_page_count := page_host.get_child_count()
	var equipment_tab: Button
	for tab_node: Node in ledger.get_node("Overlay/Frame/Layout/Tabs").get_children():
		var tab := tab_node as Button
		if tab != null and tab.get_meta("page_id", &"") == &"equipment_inventory":
			equipment_tab = tab
			break
	TestAssertions.truthy(equipment_tab != null and equipment_tab.visible, "Equipment and Inventory has a visible tab", failures)
	TestAssertions.truthy(equipment_tab != null and equipment_tab.focus_mode != Control.FOCUS_NONE, "Equipment tab remains focusable", failures)
	TestAssertions.truthy(ledger.activate_page(&"equipment_inventory"), "Equipment direct activation returns true", failures)
	var status := ledger.get_node("Overlay/Frame/Layout/Status") as Label
	TestAssertions.equal(status.text, "", "Equipment direct activation clears unavailable status", failures)
	TestAssertions.truthy(equipment_page.visible and not upgrades_page.visible and not stats_page.visible, "Equipment direct activation switches pages", failures)
	TestAssertions.equal(page_host.get_child_count(), initial_page_count, "Equipment activation reuses its configured page scene", failures)

	ledger._unhandled_input(_action_event(&"ledger_next_page"))
	TestAssertions.truthy(stats_page.visible and not upgrades_page.visible and not equipment_page.visible, "next-page cycle wraps from Equipment to Stats", failures)
	TestAssertions.equal(page_host.get_child_count(), initial_page_count, "next-page cycle reuses configured pages", failures)
	TestAssertions.truthy(ledger.activate_page(&"current_upgrades"), "Current Upgrades reactivates before reverse cycle", failures)
	ledger._unhandled_input(_action_event(&"ledger_previous_page"))
	TestAssertions.truthy(stats_page.visible and not upgrades_page.visible and not equipment_page.visible, "previous-page cycle reaches Stats", failures)
	TestAssertions.equal(page_host.get_child_count(), initial_page_count, "previous-page cycle reuses configured pages", failures)

	ledger.close()
	tree.paused = false
	ledger.free()
	run.free()
	party.free()


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
