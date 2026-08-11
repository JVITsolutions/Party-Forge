extends RefCounted

const PAGE_SCENE_PATH := "res://scenes/ui/ledger/equipment_inventory_ledger_page.tscn"
const PAGE_RESOURCE_PATH := "res://data/ui/ledger_pages/equipment_inventory.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resource_contract(failures)
	if not ResourceLoader.exists(PAGE_SCENE_PATH):
		return failures
	_test_page_projection_transactions_tooltip_and_focus(failures)
	return failures


func _test_resource_contract(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(PAGE_SCENE_PATH), "Equipment ledger page scene exists", failures)
	var definition := load(PAGE_RESOURCE_PATH) as LedgerPageDefinition
	TestAssertions.truthy(definition != null, "Equipment ledger resource loads", failures)
	if definition == null:
		return
	TestAssertions.equal(definition.development_state, LedgerPageDefinition.State.AVAILABLE, "Equipment ledger is completed content", failures)
	TestAssertions.equal(definition.unlock_id, &"equipment_inventory", "Equipment ledger uses the exact progression unlock", failures)
	TestAssertions.truthy(definition.page_scene != null and definition.page_scene.resource_path == PAGE_SCENE_PATH, "Equipment ledger resource owns the exact page scene", failures)
	TestAssertions.truthy("Coming Soon" not in definition.unavailable_text, "completed Equipment ledger no longer advertises Coming Soon", failures)


func _test_page_projection_transactions_tooltip_and_focus(failures: Array[String]) -> void:
	var fixture := _fixture(failures)
	var party := fixture.get("party") as PartyManager
	var run_context := fixture.get("run_context") as PlayerRunContext
	var catalog := fixture.get("catalog") as GameCatalog
	if party == null or run_context == null or catalog == null:
		_free_fixture(fixture)
		return
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable(), Callable(), run_context, run_context, catalog.equipment_catalog, catalog.item_foundation_catalog)
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 1
	var page := (load(PAGE_SCENE_PATH) as PackedScene).instantiate() as CharacterLedgerPage
	(Engine.get_main_loop() as SceneTree).root.add_child(page)
	page.configure(provider, context)
	page.activate()

	var expected_positions := {
		&"helmet": Vector2(0.18, 0.08), &"amulet": Vector2(0.82, 0.06),
		&"main_hand": Vector2(0.06, 0.46), &"body_armour": Vector2(0.18, 0.30), &"off_hand": Vector2(0.94, 0.46),
		&"gloves": Vector2(0.82, 0.22), &"belt": Vector2(0.82, 0.70), &"ring_left": Vector2(0.82, 0.38),
		&"legs": Vector2(0.18, 0.52), &"ring_right": Vector2(0.82, 0.54), &"boots": Vector2(0.18, 0.74),
	}
	var equipment_slots := page.get_node("Layout/Body/EquipmentRegion/Doll/Slots") as Control
	TestAssertions.equal(equipment_slots.get_child_count(), 11, "paper doll renders exactly eleven shared slots", failures)
	for slot_id: StringName in expected_positions:
		var button := equipment_slots.get_node_or_null("Slot_%s" % slot_id) as StorageSlotButton
		TestAssertions.truthy(button != null, "paper doll renders named slot %s" % slot_id, failures)
		if button == null:
			continue
		TestAssertions.equal(button.get_meta("normalized_position"), expected_positions[slot_id], "%s keeps the exact normalized paper-doll position" % slot_id, failures)
		TestAssertions.equal(button.text, "", "%s never renders a slot number or cutoff item name" % slot_id, failures)

	var helmet_one := equipment_slots.get_node("Slot_helmet") as StorageSlotButton
	TestAssertions.equal(helmet_one.item_id, "ledger-helmet-one", "member 1 equipment projects into the sheet", failures)
	TestAssertions.truthy(helmet_one.icon != null, "occupied equipment uses an icon", failures)
	var inventory := page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
	TestAssertions.equal(inventory.get_child_count(), run_context.run_inventory().capacity, "inventory renders every authoritative capacity cell", failures)
	TestAssertions.truthy(inventory.get_children().any(func(child: Node) -> bool: return (child as StorageSlotButton).item_id.is_empty()), "inventory renders empty cells", failures)
	var occupied := _inventory_item(inventory, "ledger-ring-one")
	TestAssertions.truthy(occupied != null and occupied.text.is_empty() and occupied.icon != null, "occupied inventory cells are icon-only", failures)
	var combat_summary := page.get_node("Layout/Body/EquipmentRegion/CombatSummary") as Label
	TestAssertions.truthy("Fighter Cleave" in combat_summary.text and "DPS" in combat_summary.text, "selected-member compact summary uses production combat estimates", failures)

	context.selected_member_id = 24
	page.refresh()
	var helmet_twenty_four := equipment_slots.get_node("Slot_helmet") as StorageSlotButton
	TestAssertions.equal(helmet_twenty_four.item_id, "ledger-helmet-twenty-four", "member 24 selection refreshes equipment", failures)
	context.selected_member_id = 1
	page.refresh()

	# Mouse-style signal routing swaps inventory cells through the accepted transaction boundary.
	inventory = page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
	var ring_one := _inventory_item(inventory, "ledger-ring-one")
	var ring_two := _inventory_item(inventory, "ledger-ring-two")
	var ring_one_source_slot := ring_one.slot
	var ring_two_source_slot := ring_two.slot
	ring_two.item_dropped.emit(ring_one.container_id, ring_one.slot, ring_one.item_id, ring_two.container_id, ring_two.slot)
	TestAssertions.equal(run_context.run_inventory().item_id_at(ring_two_source_slot), "ledger-ring-one", "mouse drop accepts an inventory swap", failures)
	TestAssertions.equal(run_context.run_inventory().item_id_at(ring_one_source_slot), "ledger-ring-two", "mouse swap preserves the displaced item", failures)

	# Mouse-style inventory-to-equipment routing delegates to the accepted equipment assignment.
	inventory = page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
	ring_one = _inventory_item(inventory, "ledger-ring-one")
	var ring_left := equipment_slots.get_node("Slot_ring_left") as StorageSlotButton
	ring_left.item_dropped.emit(ring_one.container_id, ring_one.slot, ring_one.item_id, ring_left.container_id, ring_left.slot)
	TestAssertions.equal(run_context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"ring_left")), "ledger-ring-one", "mouse drop equips through the accepted transition", failures)

	# An invalid equipment target preserves the exact ownership state.
	var state_before_invalid := run_context.item_state().to_dictionary()
	var body_armour := equipment_slots.get_node("Slot_body_armour") as StorageSlotButton
	ring_left = equipment_slots.get_node("Slot_ring_left") as StorageSlotButton
	body_armour.item_dropped.emit(ring_left.container_id, ring_left.slot, ring_left.item_id, body_armour.container_id, body_armour.slot)
	TestAssertions.equal(run_context.item_state().to_dictionary(), state_before_invalid, "invalid target leaves authoritative ownership unchanged", failures)

	# Shared tooltip layers and pin/dismiss contract stay intact.
	ring_left = equipment_slots.get_node("Slot_ring_left") as StorageSlotButton
	ring_left.inspection_started.emit(ring_left)
	var tooltips := page.find_children("*", "ItemTooltipPanel", true, false)
	TestAssertions.equal(tooltips.size(), 1, "page owns exactly one shared ItemTooltipPanel", failures)
	var tooltip := tooltips[0] as ItemTooltipPanel if not tooltips.is_empty() else null
	TestAssertions.truthy(tooltip != null and tooltip.visible, "slot inspection opens the shared tooltip", failures)
	if tooltip != null:
		tooltip.set_compare_active(true)
		tooltip.set_advanced_active(true)
		TestAssertions.truthy(tooltip.comparison_active() and tooltip.advanced_active(), "tooltip comparison and advanced-affix layers remain available", failures)
		TestAssertions.truthy(page.pin_active_detail() and tooltip.is_pinned(), "page pins the active tooltip detail", failures)
		TestAssertions.truthy(page.dismiss_pinned_detail() and not tooltip.visible, "page dismisses pinned tooltip detail", failures)

	var focus_controls: Array[Control] = []
	for child: Node in equipment_slots.get_children():
		focus_controls.append(child as Control)
	for child: Node in inventory.get_children():
		focus_controls.append(child as Control)
	TestAssertions.truthy(page.initial_focus() in focus_controls, "initial focus targets a page slot", failures)
	for control: Control in focus_controls:
		TestAssertions.truthy(not control.focus_next.is_empty() and control.get_node_or_null(control.focus_next) in focus_controls, "%s has a closed next-focus edge" % control.name, failures)
		TestAssertions.truthy(not control.focus_previous.is_empty() and control.get_node_or_null(control.focus_previous) in focus_controls, "%s has a closed previous-focus edge" % control.name, failures)
	page.apply_compact(true)
	TestAssertions.truthy((page.get_node("Layout/Body") as BoxContainer).vertical, "compact mode stacks inventory below equipment", failures)
	for slot_id: StringName in expected_positions:
		TestAssertions.equal((equipment_slots.get_node("Slot_%s" % slot_id) as StorageSlotButton).get_meta("normalized_position"), expected_positions[slot_id], "compact %s preserves normalized equipment placement" % slot_id, failures)

	page.free()
	_free_fixture(fixture)


func _fixture(failures: Array[String]) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.members.append(PartyMemberState.new(24, catalog.class_by_id(&"fighter"), false, "Twenty Four"))
	var profile := ProfileState.new_profile("task10-ledger-profile", "Task 10 Ledger", 1000)
	profile.inventory_columns = 4
	var run_context := PlayerRunContext.new()
	var errors := run_context.configure(&"task10_owner", 0, profile, 101010, party, 100)
	TestAssertions.equal(errors, PackedStringArray(), "Task 10 run context configures", failures)
	if not errors.is_empty():
		return {"party": party, "catalog": catalog}
	var items: Array[ItemInstance] = [
		_item(run_context, 0, "ledger-helmet-one", &"dawn_bulwark_crown"),
		_item(run_context, 1, "ledger-helmet-twenty-four", &"dawn_bulwark_crown"),
		_item(run_context, 2, "ledger-ring-one", &"windrunner_band"),
		_item(run_context, 3, "ledger-ring-two", &"storm_ring"),
	]
	for index: int in items.size():
		var result := run_context.apply_item_transaction(
			ItemTransactionRequest.create("task10-create-%d" % index, String(run_context.run_player_id), &"run-inventory", index, items[index]),
			catalog.equipment_catalog,
			catalog.item_foundation_catalog,
		)
		TestAssertions.truthy(result.ok(), "Task 10 fixture item %d enters inventory" % index, failures)
	TestAssertions.truthy(run_context.assign_equipment(1, items[0].instance_id, &"helmet", catalog.equipment_catalog, catalog.item_foundation_catalog).ok(), "member 1 helmet equips", failures)
	TestAssertions.truthy(run_context.assign_equipment(24, items[1].instance_id, &"helmet", catalog.equipment_catalog, catalog.item_foundation_catalog).ok(), "member 24 helmet equips", failures)
	return {"party": party, "catalog": catalog, "run_context": run_context}


func _item(context: PlayerRunContext, sequence: int, instance_id: String, base_id: StringName) -> ItemInstance:
	var decoded := ItemInstanceCodec.decode({
		"schema_version": ItemInstance.SCHEMA_VERSION,
		"instance_id": instance_id,
		"base_definition_id": String(base_id),
		"base_damage_components": [],
		"item_level": 12,
		"rarity_id": "common",
		"affixes": [],
		"origin": {"issuer_namespace": "run:%s:%d:%s" % [context.profile_id, context.run_seed, context.run_player_id], "seed": context.run_seed + sequence, "sequence": sequence, "source": "task10-ledger-test"},
	}, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	assert(decoded.ok())
	return decoded.item


func _inventory_item(grid: GridContainer, item_id: String) -> StorageSlotButton:
	for child: Node in grid.get_children():
		var button := child as StorageSlotButton
		if button != null and button.item_id == item_id:
			return button
	return null


func _free_fixture(fixture: Dictionary) -> void:
	var party := fixture.get("party") as PartyManager
	if party != null and is_instance_valid(party):
		party.free()
