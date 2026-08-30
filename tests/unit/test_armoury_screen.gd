extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var storage := Task9StorageFixture.storage(false)
	var screen := (load("res://scenes/ui/armoury/armoury_screen.tscn") as PackedScene).instantiate() as ArmouryScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	TestAssertions.truthy(screen.has_method(&"set_pending_run_class"), "Armoury exposes display-only pending run class", failures)
	screen.configure_classes(GameCatalog.load_defaults().classes)
	screen.open(storage)
	TestAssertions.equal(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "Armoury processes while the game tree is paused", failures)
	TestAssertions.equal(screen.equipment_button_count(), 11, "Armoury owns exactly eleven leader equipment buttons", failures)
	TestAssertions.equal(screen.stash_tab_count(), 3, "Armoury directly reaches every unlocked stash tab", failures)
	TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/Body/Follower") == null, "Armoury v1 has no follower sheet selector", failures)
	TestAssertions.truthy((screen.get_node("Overlay/Frame/Layout/Header/ClassChooser") as OptionButton).visible, "empty loadout exposes target class chooser", failures)
	screen.call("_select_item", "item-ring")
	TestAssertions.equal(screen.selected_item_detail()["instance_id"], "item-ring", "Armoury selected-item API remains available without a persistent inspector", failures)
	TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/Body/Inspector") == null, "Armoury removes the persistent inspector column", failures)
	var empty_ring_slot := screen.get_node("Overlay/Frame/Layout/Body/Equipment/Slots").get_child(6) as StorageSlotButton
	TestAssertions.equal(empty_ring_slot.text, "Ring Left", "empty equipment cell retains its equipment label", failures)
	TestAssertions.truthy(empty_ring_slot.accessibility_name.contains("empty"), "empty equipment cell exposes an accessible empty state", failures)
	var occupied_stash := screen.get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid").get_child(99) as StorageSlotButton
	TestAssertions.equal(occupied_stash.text, "", "occupied stash cell renders no slot number or truncated item name", failures)
	TestAssertions.truthy(occupied_stash.icon != null, "occupied stash cell renders the authored item icon", failures)
	var equip: Array = []
	screen.equip_requested.connect(func(item_id: String, slot_id: StringName, class_id: StringName) -> void: equip.append([item_id, slot_id, class_id]))
	screen.request_drop(&"stash-tab-zeta", 99, "item-ring", &"leader-loadout", 6)
	TestAssertions.equal((equip[0] as Array).slice(0, 2) if not equip.is_empty() else [], ["item-ring", &"ring_left"], "mouse/controller placement emits class-qualified equip intent", failures)
	var moved: Array = []
	screen.move_requested.connect(func(item_id: String, container_id: StringName, slot: int) -> void: moved.append([item_id, container_id, slot]))
	screen.request_drop(&"leader-loadout", 6, "item-ring", &"stash-tab-alpha", 4)
	TestAssertions.equal(moved[0] if not moved.is_empty() else [], ["item-ring", &"stash-tab-alpha", 4], "Armoury emits intent-only stash placement", failures)
	screen.apply_viewport_size(Vector2i(1920, 1080))
	TestAssertions.truthy(not (screen.get_node("Overlay/Frame/Layout/Body") as BoxContainer).vertical, "1080p Armoury uses wide responsive layout", failures)
	screen.apply_viewport_size(Vector2i(1200, 700))
	TestAssertions.truthy((screen.get_node("Overlay/Frame/Layout/Body") as BoxContainer).vertical, "compact Armoury stacks without offscreen fixed positioning", failures)

	var nonempty := Task9StorageFixture.storage(true)
	screen.open(nonempty)
	TestAssertions.truthy(not (screen.get_node("Overlay/Frame/Layout/Header/ClassChooser") as OptionButton).visible, "nonempty loadout hides direct target-class chooser", failures)
	TestAssertions.equal(screen.projection().leader_slots[0]["instance_id"], "item-crown", "Armoury retains exact shared leader item identity", failures)
	TestAssertions.equal(screen.projection().stash_tabs[0]["slots"], {"99": "item-ring"}, "Armoury retains exact shared sparse placement", failures)
	var occupied_leader := screen.get_node("Overlay/Frame/Layout/Body/Equipment/Slots").get_child(0) as StorageSlotButton
	TestAssertions.equal(occupied_leader.text, "", "occupied leader cell is icon-only", failures)
	TestAssertions.truthy(occupied_leader.icon != null, "occupied leader cell renders the authored icon", failures)
	var transitions: Array[StringName] = []
	screen.loadout_class_change_requested.connect(func(class_id: StringName) -> void: transitions.append(class_id))
	screen.choose_class(&"mage")
	TestAssertions.equal(transitions, [&"mage"], "nonempty class choice emits future compatibility-transition intent", failures)

	var empty_mage := Task9StorageFixture.storage(false, &"mage")
	screen.open(empty_mage)
	var chooser := screen.get_node("Overlay/Frame/Layout/Header/ClassChooser") as OptionButton
	TestAssertions.equal(StringName(chooser.get_item_metadata(chooser.selected)), &"mage", "empty loadout chooser selects stored active class", failures)
	equip.clear()
	screen.request_drop(&"stash-tab-zeta", 99, "item-ring", &"leader-loadout", 6)
	TestAssertions.equal((equip[0] as Array)[2] if not equip.is_empty() else &"", &"mage", "first empty-loadout equip submits stored Mage target", failures)

	var compare_storage := _comparison_storage()
	screen.open(compare_storage, null, true)
	var compare_button := screen.get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid").get_child(99) as StorageSlotButton
	compare_button.inspection_started.emit(compare_button)
	var tooltip := screen.get_node("Overlay/ItemTooltip") as Control
	TestAssertions.truthy(tooltip.visible, "focus or hover opens the shared item tooltip", failures)
	var inspected_card := tooltip.get_node("Layout/BodyScroll/Cards").get_child(0) as Control
	TestAssertions.truthy(String(inspected_card.call("rendered_text")).contains("Fire Damage: 3-7"), "Armoury passes the shared typed base-range detail unchanged", failures)
	tooltip.call("set_compare_active", true)
	TestAssertions.equal(int(tooltip.call("card_count")), 3, "stash ring compares against both occupied leader ring slots", failures)
	tooltip.call("toggle_pin")
	screen.close()
	TestAssertions.truthy(not tooltip.visible and not bool(tooltip.call("is_pinned")), "closing Armoury force-dismisses and unpins its tooltip", failures)
	_test_real_recovery_overflow_focus_inspect_and_input_parity(screen, failures)
	screen.free()
	return failures


func _test_real_recovery_overflow_focus_inspect_and_input_parity(screen: ArmouryScreen, failures: Array[String]) -> void:
	var item := _item("overflow-ring", &"windrunner_band", 0)
	var profile := ProfileState.new_profile("armoury-overflow", "Armoury Overflow", 1000)
	profile.inventory_columns = 1
	profile.item_records = ItemRegistry.new([item]).to_dictionary()
	profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-overflow", ItemSlotContainer.PROFILE_STASH_TAB, profile.profile_id, 100).to_dictionary()]
	profile.terminal_recovery_overflow = ItemSlotContainer.create(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW, profile.profile_id, EquipmentSlotIndex.capacity(), {0: item.instance_id}).to_dictionary()
	var projection := ProfileStorageProjection.from_profile(profile, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, null)
	TestAssertions.truthy(projection.valid, "real Armoury projection accepts populated recovery overflow ownership", failures)
	if not projection.valid:
		return
	screen.open(projection)
	var grid := screen.get_node_or_null("Overlay/Frame/Layout/Body/RecoveryOverflow/Scroll/Grid") as GridContainer
	TestAssertions.truthy(grid != null and grid.get_child_count() == EquipmentSlotIndex.capacity(), "real Armoury instance renders the exact recovery overflow capacity", failures)
	if grid == null or grid.get_child_count() == 0:
		return
	var overflow_button := grid.get_child(0) as StorageSlotButton
	TestAssertions.truthy(overflow_button != null and overflow_button.detail().get("instance_id", "") == item.instance_id, "overflow focus target owns the exact projected item", failures)
	overflow_button.inspection_started.emit(overflow_button)
	var tooltip := screen.get_node("Overlay/ItemTooltip") as Control
	TestAssertions.truthy(tooltip.visible, "keyboard/controller focus inspection opens the shared item tooltip for overflow", failures)
	screen.call("_select_item", item.instance_id)
	TestAssertions.equal(screen.selected_item_detail().get("instance_id", ""), item.instance_id, "overflow mouse selection and focus inspection share exact item identity", failures)
	var moves: Array = []
	screen.move_requested.connect(func(item_id: String, container_id: StringName, slot: int) -> void: moves.append([item_id, container_id, slot]), CONNECT_ONE_SHOT)
	screen.request_drop(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0, item.instance_id, &"stash-tab-overflow", 4)
	TestAssertions.equal(moves[0] if not moves.is_empty() else [], [item.instance_id, &"stash-tab-overflow", 4], "mouse/controller overflow drop emits the same source-only move intent", failures)
	var older_leader_moves: Array = []
	var older_leader_equips: Array = []
	screen.move_requested.connect(func(_item_id: String, _container_id: StringName, _slot: int) -> void: older_leader_moves.append(true), CONNECT_ONE_SHOT)
	screen.equip_requested.connect(func(_item_id: String, _slot_id: StringName, _class_id: StringName) -> void: older_leader_equips.append(true), CONNECT_ONE_SHOT)
	screen.request_drop(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0, item.instance_id, &"leader-loadout", 6)
	TestAssertions.equal(older_leader_moves, [], "older overflow cannot route directly to leader through storage movement", failures)
	TestAssertions.equal(older_leader_equips, [], "older overflow cannot expose a direct-equip intent", failures)
	TestAssertions.equal(screen.call("_locate", item.instance_id), {"container_id": String(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID), "slot": 0}, "Armoury locates overflow identity as the real source", failures)
	var protected_profile := profile.copy()
	protected_profile.terminal_resolution = _terminal_record(protected_profile.profile_id, item.instance_id)
	var protected_projection := ProfileStorageProjection.from_profile(protected_profile, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, null)
	TestAssertions.truthy(protected_projection.valid, "Armoury accepts a populated overflow with current-record protection", failures)
	if not protected_projection.valid:
		screen.close()
		return
	screen.open(protected_projection)
	var protected_grid := screen.get_node_or_null("Overlay/Frame/Layout/Body/RecoveryOverflow/Scroll/Grid") as GridContainer
	var protected_button := protected_grid.get_child(0) as StorageSlotButton if protected_grid != null and protected_grid.get_child_count() > 0 else null
	TestAssertions.truthy(protected_button != null and protected_button.focus_mode != Control.FOCUS_NONE, "protected overflow remains keyboard/controller focusable", failures)
	if protected_button == null:
		screen.close()
		return
	protected_button.inspection_started.emit(protected_button)
	TestAssertions.truthy(tooltip.visible, "protected overflow remains inspectable", failures)
	var protected_detail := protected_button.detail()
	TestAssertions.equal(String(protected_detail.get("move_locked_reason", "")), "Available after terminal resolution", "protected card exposes the exact readable lock reason", failures)
	TestAssertions.equal(protected_projection.comparison_lines_by_slot(item.instance_id), {}, "overflow item exposes no direct-equip comparison affordance", failures)
	var protected_moves: Array = []
	var protected_equips: Array = []
	screen.move_requested.connect(func(_item_id: String, _container_id: StringName, _slot: int) -> void: protected_moves.append(true), CONNECT_ONE_SHOT)
	screen.equip_requested.connect(func(_item_id: String, _slot_id: StringName, _class_id: StringName) -> void: protected_equips.append(true), CONNECT_ONE_SHOT)
	protected_button.pressed.emit()
	TestAssertions.equal(String(screen.get("_held_item_id")), "", "mouse activation cannot pick up a protected overflow item", failures)
	var pickup := InputEventAction.new()
	pickup.action = &"item_sandbox_pickup"
	pickup.pressed = true
	if screen.get_parent() == null:
		(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	if protected_button.is_inside_tree():
		protected_button.grab_focus()
	screen.call("_input", pickup)
	TestAssertions.equal(String(screen.get("_held_item_id")), "", "controller/keyboard pickup cannot pick up a protected overflow item", failures)
	screen.request_drop(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0, item.instance_id, &"stash-tab-overflow", 4)
	screen.request_drop(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, 0, item.instance_id, &"leader-loadout", 6)
	TestAssertions.equal(protected_moves, [], "protected overflow suppresses mouse/controller move intent", failures)
	TestAssertions.equal(protected_equips, [], "overflow suppresses every direct-equip intent", failures)
	if protected_button.is_inside_tree():
		protected_button.grab_focus()
	screen.refresh(protected_projection)
	var refreshed_grid := screen.get_node("Overlay/Frame/Layout/Body/RecoveryOverflow/Scroll/Grid") as GridContainer
	var refreshed_button := refreshed_grid.get_child(0) as StorageSlotButton
	if refreshed_button.is_inside_tree():
		var focus_owner := (Engine.get_main_loop() as SceneTree).root.gui_get_focus_owner()
		TestAssertions.equal(focus_owner, refreshed_button, "rejected move refresh restores focus by overflow container, slot, and item identity", failures)
	else:
		TestAssertions.equal(screen.call("_locate", item.instance_id), {"container_id": String(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID), "slot": 0}, "headless pre-tree refresh preserves the exact overflow focus descriptor identity", failures)
	TestAssertions.equal(refreshed_button.detail().get("instance_id", ""), item.instance_id, "focus restoration cannot jump to another item", failures)

	# A successful recovery move changes the canonical container/slot while retaining
	# item identity. Focus must follow the item, then degrade predictably if it is gone.
	screen.open(projection)
	var moving_button := (screen.get_node("Overlay/Frame/Layout/Body/RecoveryOverflow/Scroll/Grid") as GridContainer).get_child(0) as StorageSlotButton
	var moving_descriptor := {"container_id": String(moving_button.container_id), "slot": moving_button.slot, "item_id": moving_button.item_id}
	var moved_profile := profile.copy()
	moved_profile.terminal_recovery_overflow["slots"] = {}
	(moved_profile.stash_tabs[0]["slots"] as Dictionary)["4"] = item.instance_id
	var moved_projection := ProfileStorageProjection.from_profile(moved_profile, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, null)
	TestAssertions.truthy(moved_projection.valid, "moved-item focus fixture remains canonical", failures)
	screen.refresh(moved_projection)
	var moved_button := (screen.get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid") as GridContainer).get_child(4) as StorageSlotButton
	var moved_focus: Control = screen.call("_restore_storage_focus", moving_descriptor) as Control
	TestAssertions.equal(moved_focus, moved_button, "successful overflow move restores focus by item identity at its new stash location", failures)
	if moved_button.is_inside_tree():
		TestAssertions.equal((Engine.get_main_loop() as SceneTree).root.gui_get_focus_owner(), moved_button, "successful overflow move gives real GUI focus to the item at its new stash location", failures)

	var unavailable_profile := moved_profile.copy()
	unavailable_profile.item_records = ItemRegistry.new().to_dictionary()
	(unavailable_profile.stash_tabs[0]["slots"] as Dictionary).erase("4")
	var unavailable_projection := ProfileStorageProjection.from_profile(unavailable_profile, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, null)
	TestAssertions.truthy(unavailable_projection.valid, "unavailable-item focus fixture remains canonical", failures)
	var moved_descriptor := {"container_id": String(moved_button.container_id), "slot": moved_button.slot, "item_id": moved_button.item_id}
	screen.refresh(unavailable_projection)
	var stable_stash_button := (screen.get_node("Overlay/Frame/Layout/Body/Stash/Scroll/Grid") as GridContainer).get_child(4) as StorageSlotButton
	var stable_focus: Control = screen.call("_restore_storage_focus", moved_descriptor) as Control
	TestAssertions.equal(stable_focus, stable_stash_button, "missing item restores the nearest stable slot in its prior container", failures)
	if stable_stash_button.is_inside_tree():
		TestAssertions.equal((Engine.get_main_loop() as SceneTree).root.gui_get_focus_owner(), stable_stash_button, "missing item gives real GUI focus to its nearest stable prior-container slot", failures)

	var safe_focus: Control = screen.call("_restore_storage_focus", {"container_id": "missing-container", "slot": 99, "item_id": "missing-item"}) as Control
	TestAssertions.equal(safe_focus, screen.call("_first_focus"), "missing item and container restore deterministic first safe focus", failures)
	if safe_focus != null and safe_focus.is_inside_tree():
		TestAssertions.equal((Engine.get_main_loop() as SceneTree).root.gui_get_focus_owner(), safe_focus, "missing item and container give real GUI focus to the deterministic safe control", failures)
	screen.close()


func _terminal_record(profile_id: String, protected_id: String) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var run_player_id := &"armoury-overflow-player"
	var run_id := &"armoury-overflow-run"
	var state := ItemOwnershipState.create(String(run_player_id), ItemRegistry.new(), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(run_player_id), 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(run_player_id), EquipmentSlotIndex.capacity()),
		RunItemBootstrap.ground_items_container(String(run_player_id)),
	])
	var bootstrap := RunItemBootstrap.create(run_id, 9021, run_player_id, 1, state, &"fighter")
	var run_profile := ProfileState.new_profile(profile_id, "Armoury Terminal", 1000)
	run_profile.inventory_columns = 1
	run_profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	assert(context.configure(run_player_id, 0, run_profile, 9021, party, 100, bootstrap).is_empty())
	var snapshot := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 1.0, context).snapshot
	var selected: Array[String] = []
	var protected: Array[String] = [protected_id]
	var result: Variant = (load("res://scripts/run/run_terminal_recovery_record.gd") as Script).call(&"create", 1, snapshot, selected, "armoury-overflow-protection", protected, "automatic extraction needs displaced gear protection", null, "")
	party.free()
	return result.get("record").call(&"to_dictionary") if result != null and bool(result.call(&"ok")) else {}


func _comparison_storage() -> ProfileStorageProjection:
	var stash_ring := _item("stash-ring", &"windrunner_band", 0)
	stash_ring.base_damage_components = [ItemBaseDamageComponent.create(&"fire", 3.0, 7.0)]
	var left_ring := _item("left-ring", &"storm_ring", 1)
	var right_ring := _item("right-ring", &"pact_ring", 2)
	var profile := ProfileState.new_profile("armoury-comparison", "Armoury Comparison", 1000)
	profile.item_records = ItemRegistry.new([stash_ring, left_ring, right_ring]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(
		&"leader-loadout",
		ItemSlotContainer.PROFILE_LEADER_EQUIPMENT,
		profile.profile_id,
		11,
		{6: left_ring.instance_id, 7: right_ring.instance_id},
	).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	profile.stash_tabs = [ItemSlotContainer.create(
		&"stash-tab-compare",
		ItemSlotContainer.PROFILE_STASH_TAB,
		profile.profile_id,
		100,
		{99: stash_ring.instance_id},
	).to_dictionary()]
	return ProfileStorageProjection.from_profile(
		profile,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
		GameCatalog.load_defaults().class_by_id(&"fighter"),
	)


func _item(instance_id: String, base_id: StringName, sequence: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 31
	item.rarity_id = &"rare"
	item.origin = {"issuer_namespace": "profile:armoury-comparison", "seed": 44, "sequence": sequence, "source": "armoury_test"}
	return item
