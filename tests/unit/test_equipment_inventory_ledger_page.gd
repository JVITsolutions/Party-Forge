extends RefCounted

const PAGE_SCENE_PATH := "res://scenes/ui/ledger/equipment_inventory_ledger_page.tscn"
const PAGE_RESOURCE_PATH := "res://data/ui/ledger_pages/equipment_inventory.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_resource_contract(failures)
	if not ResourceLoader.exists(PAGE_SCENE_PATH):
		return failures
	_test_page_projection_transactions_tooltip_and_focus(failures)
	_test_exact_drag_drop_transactions(failures)
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
	var preview := page.get_node("Layout/Body/EquipmentRegion/Doll/PreviewProtectedCenter/CharacterEquipmentPreview") as Control
	TestAssertions.truthy(preview != null, "equipment ledger embeds the reusable character preview", failures)
	if preview != null:
		var subviewport := preview.get_node_or_null("SubViewport") as SubViewport
		TestAssertions.truthy(subviewport != null, "ledger preview owns a SubViewport", failures)
		TestAssertions.truthy(subviewport != null and subviewport.own_world_3d, "equipment preview owns an isolated World3D", failures)
		TestAssertions.truthy(preview.get_node_or_null("SubViewport/World/Camera3D") is Camera3D, "ledger preview owns its camera", failures)
		TestAssertions.truthy(preview.get_node_or_null("SubViewport/World/KeyLight") is DirectionalLight3D, "ledger preview owns controlled lighting", failures)
		var initial_active := preview.get("active_preview") as CharacterPresentation
		var initial_active_id := initial_active.get_instance_id() if initial_active != null else 0
		TestAssertions.truthy(initial_active != null, "active equipment page renders selected member", failures)
		TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "headless active equipment page builds its preview while invisible rendering stays suspended", failures)
		page.deactivate()
		TestAssertions.truthy(preview.get("active_preview") == null, "deactivation releases preview actor", failures)
		TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "deactivation suspends preview rendering", failures)
		page.deactivate()
		TestAssertions.truthy(preview.get("active_preview") == null, "repeated deactivation keeps preview actor released", failures)
		TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "repeated deactivation keeps preview rendering suspended", failures)
		page.activate()
		var reactivated := preview.get("active_preview") as CharacterPresentation
		var reactivated_model := reactivated.active_model as ForgeHumanoidModel if reactivated != null else null
		TestAssertions.truthy(reactivated != null and reactivated.get_instance_id() != initial_active_id, "reactivation rebuilds the selected member preview", failures)
		TestAssertions.truthy(initial_active_id == 0 or not is_instance_id_valid(initial_active_id), "deactivation frees the previous preview actor immediately", failures)
		TestAssertions.truthy(reactivated_model != null and reactivated_model.equipped_definitions.has(&"helmet"), "reactivation preserves selected member equipment visuals", failures)
		TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "headless reactivation rebuilds its preview while invisible rendering stays suspended", failures)

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
	var member_one_preview_id := _active_preview_id(preview)

	# Unit-level signal routing swaps inventory cells through the accepted transaction boundary.
	inventory = page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
	var ring_one := _inventory_item(inventory, "ledger-ring-one")
	var ring_two := _inventory_item(inventory, "ledger-ring-two")
	var ring_one_source_slot := ring_one.slot
	var ring_two_source_slot := ring_two.slot
	_drag_drop(ring_one, ring_two, "inventory occupied swap", failures)
	TestAssertions.equal(run_context.run_inventory().item_id_at(ring_two_source_slot), "ledger-ring-one", "mouse drop accepts an inventory swap", failures)
	TestAssertions.equal(run_context.run_inventory().item_id_at(ring_one_source_slot), "ledger-ring-two", "mouse swap preserves the displaced item", failures)
	TestAssertions.equal(_active_preview_id(preview), member_one_preview_id, "accepted inventory-only transaction does not rebuild the equipment preview", failures)

	# Unit-level inventory-to-equipment routing delegates to the accepted equipment assignment.
	inventory = page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
	ring_one = _inventory_item(inventory, "ledger-ring-one")
	var ring_left := equipment_slots.get_node("Slot_ring_left") as StorageSlotButton
	var before_equip_preview_id := _active_preview_id(preview)
	_drag_drop(ring_one, ring_left, "inventory to equipment", failures)
	TestAssertions.equal(run_context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"ring_left")), "ledger-ring-one", "mouse drop equips through the accepted transition", failures)
	TestAssertions.truthy(_active_preview_id(preview) != before_equip_preview_id, "accepted equip refreshes the selected member preview", failures)
	var accepted_preview_id := _active_preview_id(preview)

	# An invalid equipment target preserves the exact ownership state.
	var state_before_invalid := run_context.item_state().to_dictionary()
	var body_armour := equipment_slots.get_node("Slot_body_armour") as StorageSlotButton
	ring_left = equipment_slots.get_node("Slot_ring_left") as StorageSlotButton
	_drag_drop(ring_left, body_armour, "invalid equipment target", failures)
	TestAssertions.equal(run_context.item_state().to_dictionary(), state_before_invalid, "invalid target leaves authoritative ownership unchanged", failures)
	TestAssertions.equal(_active_preview_id(preview), accepted_preview_id, "rejected equipment transaction leaves the preview unchanged", failures)

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


func _test_exact_drag_drop_transactions(failures: Array[String]) -> void:
	_exercise_equipped_to_exact_empty_inventory_slot(failures)
	_exercise_equipped_to_occupied_inventory_swap(false, failures)
	_exercise_equipped_to_occupied_inventory_swap(true, failures)


func _exercise_equipped_to_exact_empty_inventory_slot(failures: Array[String]) -> void:
	var fixture := _transaction_fixture("exact-empty", false, false, failures)
	var page := fixture.get("page") as CharacterLedgerPage
	var run_context := fixture.get("run_context") as PlayerRunContext
	var party := fixture.get("party") as PartyManager
	if page == null or run_context == null or party == null:
		_free_transaction_fixture(fixture)
		return
	var equipment := page.get_node("Layout/Body/EquipmentRegion/Doll/Slots") as Control
	var inventory := page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
	var source := equipment.get_node("Slot_helmet") as StorageSlotButton
	var destination := inventory.get_node("InventorySlot_004") as StorageSlotButton
	var preview := page.get_node("Layout/Body/EquipmentRegion/Doll/PreviewProtectedCenter/CharacterEquipmentPreview") as Control
	var before_preview_id := _active_preview_id(preview)
	var revision_before := party.stat_revision()
	_drag_drop(source, destination, "equipped item to exact empty inventory cell", failures)
	TestAssertions.equal(run_context.run_inventory().item_id_at(4), "exact-empty-equipped", "equipped item lands in the exact focused empty cell", failures)
	TestAssertions.equal(run_context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"helmet")), "", "exact empty-cell placement clears the equipment source", failures)
	TestAssertions.truthy(run_context.equipment_activation(1).ok(), "exact empty-cell placement republishes equipment activation", failures)
	TestAssertions.truthy(party.stat_revision() > revision_before, "exact empty-cell placement republishes member stats", failures)
	TestAssertions.truthy(_active_preview_id(preview) != before_preview_id, "accepted unequip refreshes the selected member preview", failures)
	var active := preview.get("active_preview") as CharacterPresentation if preview != null else null
	var model := active.active_model as ForgeHumanoidModel if active != null else null
	if model != null:
		TestAssertions.truthy(not model.equipped_definitions.has(&"helmet"), "accepted unequip clears the helmet visual", failures)
	_free_transaction_fixture(fixture)


func _exercise_equipped_to_occupied_inventory_swap(full_inventory: bool, failures: Array[String]) -> void:
	var label := "full-swap" if full_inventory else "occupied-swap"
	var fixture := _transaction_fixture(label, true, full_inventory, failures)
	var page := fixture.get("page") as CharacterLedgerPage
	var run_context := fixture.get("run_context") as PlayerRunContext
	var party := fixture.get("party") as PartyManager
	if page == null or run_context == null or party == null:
		_free_transaction_fixture(fixture)
		return
	var equipment := page.get_node("Layout/Body/EquipmentRegion/Doll/Slots") as Control
	var inventory := page.get_node("Layout/Body/InventoryRegion/InventoryScroll/Grid") as GridContainer
	var source := equipment.get_node("Slot_helmet") as StorageSlotButton
	var destination := inventory.get_node("InventorySlot_001") as StorageSlotButton
	var original_source_container_id := source.container_id
	var original_source_slot := source.slot
	var original_item_id := source.item_id
	var revision_before := party.stat_revision()
	destination.item_dropped.emit(original_source_container_id, original_source_slot, original_item_id, destination.container_id, destination.slot)
	TestAssertions.equal(run_context.run_inventory().item_id_at(1), "%s-equipped" % label, "%s places the equipped item in the exact occupied inventory cell" % label, failures)
	TestAssertions.equal(run_context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"helmet")), "%s-target" % label, "%s equips the displaced compatible item" % label, failures)
	TestAssertions.truthy(run_context.equipment_activation(1).ok() and run_context.equipment_activation(1).is_active("%s-target" % label), "%s republishes activation for the displaced item" % label, failures)
	TestAssertions.truthy(party.stat_revision() > revision_before, "%s republishes member stats" % label, failures)
	if full_inventory:
		TestAssertions.equal(run_context.run_inventory().occupied_slots().size(), run_context.run_inventory().capacity, "full-inventory occupied swap retains full capacity", failures)
	var accepted_state := run_context.item_state().to_dictionary()
	destination.item_dropped.emit(original_source_container_id, original_source_slot, original_item_id, destination.container_id, destination.slot)
	TestAssertions.equal(run_context.item_state().to_dictionary(), accepted_state, "%s stale duplicate drop is atomic" % label, failures)
	var invalid_source := equipment.get_node("Slot_helmet") as StorageSlotButton
	var invalid_target := equipment.get_node("Slot_ring_left") as StorageSlotButton
	_drag_drop(invalid_source, invalid_target, "%s invalid target" % label, failures)
	TestAssertions.equal(run_context.item_state().to_dictionary(), accepted_state, "%s invalid target preserves exact ownership state" % label, failures)
	_free_transaction_fixture(fixture)


func _transaction_fixture(label: String, occupied_target: bool, full_inventory: bool, failures: Array[String]) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var profile := ProfileState.new_profile("task10-%s-profile" % label, "Task 10 %s" % label, 1000)
	profile.inventory_columns = 1
	var run_context := PlayerRunContext.new()
	var errors := run_context.configure(StringName("task10_%s_owner" % label.replace("-", "_")), 0, profile, 202600 + label.length(), party, 100)
	TestAssertions.equal(errors, PackedStringArray(), "%s run context configures" % label, failures)
	if not errors.is_empty():
		return {"party": party, "catalog": catalog}
	var sequence := 0
	_create_fixture_item(run_context, catalog, sequence, 0, "%s-equipped" % label, &"dawn_bulwark_crown", failures)
	sequence += 1
	TestAssertions.truthy(run_context.assign_equipment(1, "%s-equipped" % label, &"helmet", catalog.equipment_catalog, catalog.item_foundation_catalog).ok(), "%s source helmet equips" % label, failures)
	if occupied_target:
		_create_fixture_item(run_context, catalog, sequence, 1, "%s-target" % label, &"dawn_bulwark_crown", failures)
		sequence += 1
	if full_inventory:
		for slot: int in [0, 2, 3, 4]:
			_create_fixture_item(run_context, catalog, sequence, slot, "%s-filler-%d" % [label, slot], &"windrunner_band", failures)
			sequence += 1
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable(), Callable(), run_context, run_context, catalog.equipment_catalog, catalog.item_foundation_catalog)
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 1
	var page := (load(PAGE_SCENE_PATH) as PackedScene).instantiate() as CharacterLedgerPage
	(Engine.get_main_loop() as SceneTree).root.add_child(page)
	page.configure(provider, context)
	page.activate()
	return {"party": party, "catalog": catalog, "run_context": run_context, "page": page}


func _create_fixture_item(context: PlayerRunContext, catalog: GameCatalog, sequence: int, slot: int, instance_id: String, base_id: StringName, failures: Array[String]) -> void:
	var item := _item(context, sequence, instance_id, base_id)
	var result := context.apply_item_transaction(
		ItemTransactionRequest.create("task10-create-%s" % instance_id, String(context.run_player_id), &"run-inventory", slot, item),
		catalog.equipment_catalog,
		catalog.item_foundation_catalog,
	)
	TestAssertions.truthy(result.ok(), "%s enters inventory slot %d" % [instance_id, slot], failures)


func _free_transaction_fixture(fixture: Dictionary) -> void:
	var page := fixture.get("page") as CharacterLedgerPage
	if page != null and is_instance_valid(page):
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


func _drag_drop(source: StorageSlotButton, destination: StorageSlotButton, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(source != null and destination != null, "%s has shared source and destination buttons" % label, failures)
	if source == null or destination == null:
		return
	destination.item_dropped.emit(source.container_id, source.slot, source.item_id, destination.container_id, destination.slot)


func _active_preview_id(preview: Control) -> int:
	if preview == null:
		return 0
	var active := preview.get("active_preview") as CharacterPresentation
	return active.get_instance_id() if active != null else 0


func _free_fixture(fixture: Dictionary) -> void:
	var party := fixture.get("party") as PartyManager
	if party != null and is_instance_valid(party):
		party.free()
